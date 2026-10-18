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
/// connections so one TCP stream's window never caps a fast line, and the
/// result leaves out the slow-start warm-up. Each value is published twice a
/// second while it is measured. No user data ever leaves the machine (the
/// upload body is zeros).
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
        var tick: TimeInterval = 0.5
        var latencySamples = 20
        /// Back to back: a pause lets Wi-Fi doze and adds a millisecond or so.
        var latencySpacing: TimeInterval = 0
        var latencyMaxDuration: TimeInterval = 4
        var latencyMaxFailures = 3
        var streams = 8
        /// TCP slow start and TLS set-up, left out of the result.
        var warmUp: TimeInterval = 2
        var minDuration: TimeInterval = 5
        var maxDuration: TimeInterval = 10
        /// Steady once each of the last `stableSeconds` one-second rates is
        /// within this fraction of the steady average.
        var stableTolerance = 0.05
        var stableSeconds = 3
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
    private var cancelProbeDelay: (() -> Void)?
    private var probe: SpeedTestConnection?
    private var probedOnce = false
    private var latencyFailures = 0
    private var latencySamples: [Double] = []
    private var streams: [Int: SpeedTestConnection] = [:]
    private var nextStreamID = 0
    private var bytes: Int64 = 0
    private var marks: [SpeedTestMath.Mark] = []

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

    private func startTicking() {
        cancelTick?()
        let run = activeRun
        cancelTick = schedule(config.tick) { [weak self] in
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
                publishRate(live)
            }
            if elapsed >= config.maxDuration
                || (elapsed >= config.minDuration
                    && SpeedTestMath.isStable(marks, warmUp: config.warmUp,
                                              seconds: config.stableSeconds,
                                              tolerance: config.stableTolerance)) {
                finishTransfer()
                return
            }
            if elapsed >= config.warmUp + config.tick, bytes == 0 {
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
        startTicking()
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
        startTicking()
    }

    private func streamEnded(_ id: Int, failure: SpeedTestFailure?) {
        streams[id]?.cancel()
        streams[id] = nil
        if failure == .rateLimited {
            fail(.rateLimited)
            return
        }
        guard streams.isEmpty else { return }
        // Every stream is gone: keep the result if the steady window has data.
        let elapsed = clock() - phaseStart
        if elapsed > config.warmUp, bytes > 0 {
            marks.append(.init(time: elapsed, bytes: bytes))
            finishTransfer()
        } else {
            fail(failure ?? .network)
        }
    }

    private func finishTransfer() {
        let finished = current
        cancelTick?(); cancelTick = nil
        closeStreams()
        let mbps = SpeedTestMath.steadyMbps(marks, warmUp: config.warmUp)
        publishRate(mbps)
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

    /// The result: everything moved after the warm-up, over the time it took.
    /// A run too short to have a steady window falls back to its whole span.
    static func steadyMbps(_ marks: [Mark], warmUp: TimeInterval) -> Double? {
        guard let last = marks.last, let first = marks.first, last.time > first.time else { return nil }
        var from = marks.first { $0.time >= warmUp } ?? first
        if last.time - from.time < 1 { from = first }
        return mbps(bytes: last.bytes - from.bytes, seconds: last.time - from.time)
    }

    /// True when each of the last `seconds` one-second rates sits within
    /// `tolerance` of the steady average, so measuring longer would not move
    /// the result (and would only spend the server's patience).
    static func isStable(_ marks: [Mark], warmUp: TimeInterval, seconds: Int, tolerance: Double) -> Bool {
        guard let last = marks.last, last.time - warmUp >= Double(seconds),
              let steady = steadyMbps(marks, warmUp: warmUp), steady > 0 else { return false }
        for second in 0..<seconds {
            let end = last.time - Double(second)
            guard let to = marks.last(where: { $0.time <= end + 0.001 }),
                  let from = marks.last(where: { $0.time <= end - 1 + 0.001 }),
                  to.time > from.time else { return false }
            let rate = mbps(bytes: to.bytes - from.bytes, seconds: to.time - from.time)
            if abs(rate - steady) > steady * tolerance { return false }
        }
        return true
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
