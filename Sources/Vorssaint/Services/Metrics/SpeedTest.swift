// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

enum SpeedTestFailure: Error, Equatable {
    case network
    case badResponse
    /// The speed server refused more test traffic for now (HTTP 429).
    case rateLimited
}

/// One open measurement connection (a latency probe or a transfer stream).
protocol SpeedTestConnection: AnyObject {
    func cancel()
}

/// Where the measurement traffic goes. Every callback arrives asynchronously
/// on the queue passed in, never from inside the call that opened it.
protocol SpeedTestTransport: AnyObject {
    /// Shown as the test server, e.g. "Apple".
    var name: String { get }
    /// Looks up where to measure; called at the start of every run, before
    /// any other call. A failure moves the test on to the next transport.
    func prepare(on queue: DispatchQueue, completion: @escaping (SpeedTestFailure?) -> Void) -> SpeedTestConnection
    /// One round trip, in milliseconds.
    func probeLatency(on queue: DispatchQueue,
                      completion: @escaping (Result<Double, SpeedTestFailure>) -> Void) -> SpeedTestConnection
    /// A stream that downloads or uploads back to back until cancelled.
    /// `onBytes` reports payload bytes moved; `onEnd` reports the stream died.
    func openStream(_ direction: SpeedTestDirection, on queue: DispatchQueue,
                    onBytes: @escaping (Int) -> Void,
                    onEnd: @escaping (SpeedTestFailure?) -> Void) -> SpeedTestConnection
}

enum SpeedTestDirection: Equatable {
    case download, upload
}

/// A user-triggered internet speed test, measured one value after the other
/// the way broadband reference tests do: latency, then download, then upload.
/// Latency is the median TCP handshake time; throughput runs several parallel
/// connections so one TCP stream's window never caps a fast line. Each value
/// is published four times a second while it is measured, and a throughput
/// result is the mean of those readings once the connections have ramped up. No user data ever leaves the
/// machine (the upload body is zeros).
///
/// Transports are tried in order: when a run fails on one (unreachable, a
/// changed configuration, a server refusing traffic), it starts over on the
/// next, so Cloudflare stands in whenever Apple's servers do not answer.
///
/// All measurement state is confined to `queue`; published values go to the
/// main thread, tagged with the run that produced them so a cancelled run can
/// never overwrite a newer one.
final class SpeedTest: ObservableObject {
    static let shared = SpeedTest()

    typealias Clock = () -> TimeInterval
    /// Runs `action` on the measurement queue after a delay; returns a canceller.
    typealias Scheduler = (TimeInterval, @escaping () -> Void) -> () -> Void

    enum Phase: Equatable {
        case idle, latency, download, upload, done
        case failed(SpeedTestFailure)
    }

    struct Configuration {
        var tick: TimeInterval = 0.25
        var latencySamples = 20
        /// Back to back: a pause lets Wi-Fi doze and adds a millisecond or so.
        var latencySpacing: TimeInterval = 0
        var latencyMaxDuration: TimeInterval = 4
        var latencyMaxFailures = 3
        var streams = 8
        /// A transfer that has moved no byte by then has failed.
        var stallTimeout: TimeInterval = 2
        /// TCP slow start and TLS set-up: readings this early are shown but
        /// left out of the result.
        var rampUp: TimeInterval = 2.5
        /// Each of download and upload.
        var duration: TimeInterval = 10
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var latencyMs: Double?
    @Published private(set) var downloadMbps: Double?
    @Published private(set) var uploadMbps: Double?
    /// The transport that measured (or is measuring) the values shown.
    @Published private(set) var serverName: String?

    var isRunning: Bool {
        switch phase { case .latency, .download, .upload: return true; default: return false }
    }

    private let transports: [SpeedTestTransport]
    private let config: Configuration
    private let clock: Clock
    private let schedule: Scheduler
    let queue: DispatchQueue

    private var runID = 0                    // main thread only

    // Everything below is touched only on `queue`.
    private var activeRun = 0
    private var transportIndex = 0
    private var preparing: SpeedTestConnection?
    private var current: Phase = .idle
    private var phaseStart: TimeInterval = 0
    private var cancelTick: (() -> Void)?
    private var ticks = 0
    private var cancelProbeDelay: (() -> Void)?
    private var probe: SpeedTestConnection?
    private var probedOnce = false
    private var latencyFailures = 0
    private var latencySamples: [Double] = []
    private var streams: [Int: SpeedTestConnection] = [:]
    private var nextStreamID = 0
    private var bytes: Int64 = 0
    private var marks: [SpeedTestMath.Mark] = []
    private var readings: [SpeedTestMath.Reading] = []

    init(transports: [SpeedTestTransport] = [HTTPSpeedTestTransport.apple(), HTTPSpeedTestTransport.cloudflare()],
         configuration: Configuration = Configuration(),
         queue: DispatchQueue = DispatchQueue(label: "Vorssaint.SpeedTest", qos: .userInitiated),
         clock: @escaping Clock = { ProcessInfo.processInfo.systemUptime },
         scheduler: Scheduler? = nil) {
        precondition(!transports.isEmpty, "a speed test needs a transport")
        self.transports = transports
        self.config = configuration
        self.queue = queue
        self.clock = clock
        self.schedule = scheduler ?? { delay, action in
            let work = DispatchWorkItem(block: action)
            queue.asyncAfter(deadline: .now() + delay, execute: work)
            return { work.cancel() }
        }
    }

    /// Call on the main thread.
    func start() {
        guard !isRunning else { return }
        runID += 1
        let run = runID
        latencyMs = nil; downloadMbps = nil; uploadMbps = nil; serverName = nil
        phase = .latency
        queue.async { [weak self] in
            guard let self else { return }
            self.teardown()
            self.activeRun = run
            self.transportIndex = 0
            self.beginRun()
        }
    }

    /// Call on the main thread. Stops a running test; finished values stay,
    /// the live reading of the value cut short goes.
    func cancel() {
        runID += 1
        switch phase {
        case .latency: latencyMs = nil
        case .download: downloadMbps = nil
        case .upload: uploadMbps = nil
        default: break
        }
        if isRunning { phase = .idle }
        queue.async { [weak self] in
            self?.teardown()
            self?.activeRun = 0
        }
    }

    // MARK: - Publishing

    private func publish(_ update: @escaping (SpeedTest) -> Void) {
        let run = activeRun
        DispatchQueue.main.async { [weak self] in
            guard let self, self.runID == run else { return }
            update(self)
        }
    }

    private func enter(_ phase: Phase) {
        current = phase
        phaseStart = clock()
        publish { $0.phase = phase }
    }

    /// Ticks land on whole multiples of `tick` after the phase start, so a
    /// late callback never pushes every later reading back; one that is
    /// more than half a tick behind skips ahead instead of bunching up.
    private func startTicking(restart: Bool = false) {
        cancelTick?()
        if restart { ticks = 0 }
        ticks += 1
        let now = clock()
        while phaseStart + Double(ticks) * config.tick < now - config.tick / 2 { ticks += 1 }
        let delay = max(0, phaseStart + Double(ticks) * config.tick - now)
        let run = activeRun
        cancelTick = schedule(delay) { [weak self] in
            guard let self, self.activeRun == run else { return }
            self.tick()
        }
    }

    private func tick() {
        let elapsed = clock() - phaseStart
        switch current {
        case .latency:
            if let median = SpeedTestMath.median(latencySamples) {
                publish { $0.latencyMs = median }
            }
            if elapsed >= config.latencyMaxDuration {
                latencySamples.isEmpty ? fail(.network) : finishLatency()
                return
            }
        case .download, .upload:
            marks.append(.init(time: elapsed, bytes: bytes))
            if let live = SpeedTestMath.recentMbps(marks, window: 1) {
                readings.append(.init(time: elapsed, mbps: live))
                publishRate(live)
            }
            // Half a tick of slack, so rounding never adds a tick past the end.
            if elapsed + config.tick / 2 >= config.duration {
                finishTransfer()
                return
            }
            if elapsed >= config.stallTimeout + config.tick, bytes == 0 {
                fail(.network)
                return
            }
        default:
            return
        }
        startTicking()
    }

    private func publishRate(_ mbps: Double?) {
        if current == .download {
            publish { $0.downloadMbps = mbps }
        } else {
            publish { $0.uploadMbps = mbps }
        }
    }

    private var transport: SpeedTestTransport { transports[transportIndex] }

    private func beginRun() {
        enter(.latency)
        let run = activeRun
        let name = transport.name
        preparing = transport.prepare(on: queue) { [weak self] failure in
            guard let self, self.activeRun == run, self.current == .latency else { return }
            self.preparing = nil
            if let failure {
                self.fail(failure)
                return
            }
            self.publish { $0.serverName = name }
            self.beginLatency()
        }
    }

    // MARK: - Latency

    private func beginLatency() {
        probedOnce = false
        latencyFailures = 0
        latencySamples = []
        phaseStart = clock()   // the configuration lookup is not latency time
        startTicking(restart: true)
        probeLatency()
    }

    private func probeLatency() {
        let run = activeRun
        let started = clock()
        probe = transport.probeLatency(on: queue) { [weak self] result in
            guard let self, self.activeRun == run, self.current == .latency else { return }
            self.probe = nil
            switch result {
            case .success(let ms):
                // The first handshake also pays for the DNS lookup.
                if self.probedOnce { self.latencySamples.append(ms) }
                self.probedOnce = true
                self.latencyFailures = 0
            case .failure(let failure):
                self.latencyFailures += 1
                if self.latencyFailures >= self.config.latencyMaxFailures {
                    self.fail(failure)
                    return
                }
            }
            if self.latencySamples.count >= self.config.latencySamples {
                self.finishLatency()
                return
            }
            let wait = max(0, self.config.latencySpacing - (self.clock() - started))
            self.cancelProbeDelay = self.schedule(wait) { [weak self] in
                guard let self, self.activeRun == run, self.current == .latency else { return }
                self.probeLatency()
            }
        }
    }

    private func finishLatency() {
        cancelTick?(); cancelTick = nil
        cancelProbeDelay?(); cancelProbeDelay = nil
        probe?.cancel(); probe = nil
        let median = SpeedTestMath.median(latencySamples)
        publish { $0.latencyMs = median }
        beginTransfer(.download)
    }

    // MARK: - Download / upload

    private func beginTransfer(_ direction: SpeedTestDirection) {
        bytes = 0
        marks = [.init(time: 0, bytes: 0)]
        readings = []
        enter(direction == .download ? .download : .upload)
        let run = activeRun
        let phase = current
        for _ in 0..<config.streams {
            nextStreamID += 1
            let id = nextStreamID
            streams[id] = transport.openStream(direction, on: queue, onBytes: { [weak self] count in
                guard let self, self.activeRun == run, self.current == phase else { return }
                self.bytes += Int64(count)
            }, onEnd: { [weak self] failure in
                guard let self, self.activeRun == run, self.current == phase else { return }
                self.streamEnded(id, failure: failure)
            })
        }
        startTicking(restart: true)
    }

    private func streamEnded(_ id: Int, failure: SpeedTestFailure?) {
        streams[id]?.cancel()
        streams[id] = nil
        if failure == .rateLimited {
            fail(.rateLimited)
            return
        }
        guard streams.isEmpty else { return }
        // Every stream is gone: keep the readings taken so far, if any.
        if !readings.isEmpty, bytes > 0 {
            finishTransfer()
        } else {
            fail(failure ?? .network)
        }
    }

    private func finishTransfer() {
        let finished = current
        cancelTick?(); cancelTick = nil
        closeStreams()
        publishRate(SpeedTestMath.resultMbps(readings, rampUp: config.rampUp, tick: config.tick))
        if finished == .download {
            beginTransfer(.upload)
        } else {
            enter(.done)
        }
    }

    private func closeStreams() {
        for stream in streams.values { stream.cancel() }
        streams.removeAll()
    }

    // MARK: - Ending

    private func fail(_ failure: SpeedTestFailure) {
        let failed = current
        teardown()
        if transportIndex + 1 < transports.count {
            // Start over on the next server; nothing measured so far counts.
            transportIndex += 1
            publish { $0.latencyMs = nil; $0.downloadMbps = nil; $0.uploadMbps = nil; $0.serverName = nil }
            beginRun()
            return
        }
        // A value cut short is not a measurement: drop the live reading.
        switch failed {
        case .latency: publish { $0.latencyMs = nil }
        case .download: publish { $0.downloadMbps = nil }
        case .upload: publish { $0.uploadMbps = nil }
        default: break
        }
        current = .failed(failure)
        publish { $0.phase = .failed(failure) }
    }

    private func teardown() {
        preparing?.cancel(); preparing = nil
        cancelTick?(); cancelTick = nil
        cancelProbeDelay?(); cancelProbeDelay = nil
        probe?.cancel(); probe = nil
        closeStreams()
        current = .idle
    }
}

/// The arithmetic behind the published values, kept pure for the tests.
enum SpeedTestMath {
    struct Mark: Equatable {
        let time: TimeInterval
        let bytes: Int64
    }

    static func mbps(bytes: Int64, seconds: TimeInterval) -> Double {
        seconds > 0 ? max(0, Double(bytes) * 8 / seconds / 1_000_000) : 0
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    /// The rate over roughly the last `window` seconds, for the live reading.
    static func recentMbps(_ marks: [Mark], window: TimeInterval) -> Double? {
        guard let last = marks.last, marks.count >= 2 else { return nil }
        let from = marks.last { $0.time <= last.time - window + 0.001 } ?? marks[0]
        return mbps(bytes: last.bytes - from.bytes, seconds: last.time - from.time)
    }

    struct Reading: Equatable {
        let time: TimeInterval
        let mbps: Double
    }

    static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// The throughput result: the mean of the readings taken after the
    /// ramp-up. Half a tick of slack keeps the reading due exactly at the end
    /// of the ramp-up out despite rounding. A transfer cut short inside the
    /// ramp-up falls back to every reading it has.
    static func resultMbps(_ readings: [Reading], rampUp: TimeInterval, tick: TimeInterval) -> Double? {
        let settled = readings.filter { $0.time > rampUp + tick / 2 }.map(\.mbps)
        return mean(settled.isEmpty ? readings.map(\.mbps) : settled)
    }
}

/// Logarithmic, like the reference gauges: 6 ms and 1000 Mbps both read well.
enum SpeedTestScale {
    static let rateTicks = [10.0, 100, 1000].map { fraction($0, upTo: 2500) }

    static func fraction(_ value: Double, upTo ceiling: Double) -> Double {
        guard value > 0 else { return 0 }
        return min(1, max(0, log10(1 + value) / log10(1 + ceiling)))
    }
}
