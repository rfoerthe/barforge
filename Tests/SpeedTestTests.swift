// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

enum SpeedTestTests {
    static func run(_ suite: TestSuite) {
        mathChecks(suite)
        parserChecks(suite)
        configurationChecks(suite)
        successChecks(suite)
        latencyFailureChecks(suite)
        rateLimitChecks(suite)
        stallChecks(suite)
        cancelChecks(suite)
        fallbackChecks(suite)
    }

    // MARK: - Pure arithmetic

    private static func mathChecks(_ suite: TestSuite) {
        suite.expect(SpeedTestMath.median([]) == nil
                      && SpeedTestMath.median([9, 5, 7]) == 7
                      && SpeedTestMath.median([8, 4, 6, 5]) == 5.5,
                     "speed test latency is the median of its samples")

        // 1 MB/s for two seconds of warm-up, then 100 MB/s.
        var marks: [SpeedTestMath.Mark] = [.init(time: 0, bytes: 0)]
        for step in 1...16 {
            let time = Double(step) / 2
            let bytes = time <= 2 ? Int64(time * 1_000_000)
                                  : 2_000_000 + Int64((time - 2) * 100_000_000)
            marks.append(.init(time: time, bytes: bytes))
        }
        suite.expect(SpeedTestMath.mean([]) == nil && SpeedTestMath.mean([900, 1000, 1100, 1200]) == 1050,
                     "speed test throughput is the mean of its readings")
        let readings = (1...12).map { SpeedTestMath.Reading(time: Double($0) * 0.25, mbps: $0 <= 10 ? 100 : 1000) }
        suite.expect(SpeedTestMath.resultMbps(readings, rampUp: 2.5, tick: 0.25) == 1000
                      && SpeedTestMath.resultMbps([.init(time: 2.4999999, mbps: 5), .init(time: 2.75, mbps: 7)],
                                                  rampUp: 2.5, tick: 0.25) == 7,
                     "speed test leaves readings up to 2.5 s out of the result")
        suite.expect(SpeedTestMath.resultMbps(Array(readings.prefix(4)), rampUp: 2.5, tick: 0.25) == 100
                      && SpeedTestMath.resultMbps([], rampUp: 2.5, tick: 0.25) == nil,
                     "speed test falls back to every reading when cut short inside the ramp-up")
        suite.expect(SpeedTestMath.recentMbps(Array(marks.prefix(4)), window: 1) == 8,
                     "speed test live rate covers the last second")
        suite.expect(SpeedTestScale.fraction(0, upTo: 2500) == 0
                      && SpeedTestScale.fraction(1_000_000, upTo: 2500) == 1
                      && abs(SpeedTestScale.fraction(1000, upTo: 2500) - 0.883) < 0.01,
                     "speed test bars use a clamped logarithmic scale")
    }

    private static func parserChecks(_ suite: TestSuite) {
        var parser = SpeedTestHTTPResponseParser()
        let head = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\ncontent-length: 10\r\n\r\n"
        let split = head.index(head.startIndex, offsetBy: 20)
        var events = parser.consume(Data(head[..<split].utf8))
        events += parser.consume(Data((String(head[split...]) + "abcd").utf8))
        events += parser.consume(Data("efghij".utf8))
        suite.expect(events == [.head(status: 200), .body(4), .body(6), .complete],
                     "speed test response parser counts only body bytes across split reads")

        var limited = SpeedTestHTTPResponseParser()
        suite.expect(limited.consume(Data("HTTP/1.1 429 Too Many Requests\r\nContent-Length: 5\r\n\r\n".utf8))
                        == [.head(status: 429)],
                     "speed test response parser reports the status before any body")

        var unsized = SpeedTestHTTPResponseParser()
        suite.expect(unsized.consume(Data("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n".utf8))
                        == [.head(status: 200), .malformed],
                     "speed test response parser refuses a success without a length")

        var garbage = SpeedTestHTTPResponseParser()
        suite.expect(garbage.consume(Data("SSH-2.0-OpenSSH\r\n\r\n".utf8)) == [.malformed],
                     "speed test response parser rejects a non-HTTP reply")
        var endless = SpeedTestHTTPResponseParser()
        suite.expect(endless.consume(Data(repeating: 65, count: 20_000)) == [.malformed],
                     "speed test response parser bounds an endless header")
    }

    private static func configurationChecks(_ suite: TestSuite) {
        func config(download: String, upload: String) -> Data {
            Data("""
            { "version": 1, "test_endpoint": "defra1-edge-fx-023.aaplimg.com",
              "urls": { "large_https_download_url": "\(download)", "https_upload_url": "\(upload)",
                        "small_https_download_url": "https://mensura.cdn-apple.com/api/v1/gm/small" } }
            """.utf8)
        }
        let apple = SpeedTestEndpoints.appleConfiguration(config(
            download: "https://mensura.cdn-apple.com/api/v1/gm/large",
            upload: "https://mensura.cdn-apple.com/api/v1/gm/slurp"))
        suite.expect(apple?.download.absoluteString == "https://mensura.cdn-apple.com/api/v1/gm/large"
                      && apple?.upload.absoluteString == "https://mensura.cdn-apple.com/api/v1/gm/slurp",
                     "speed test reads Apple's networkQuality download and upload URLs")
        suite.expect(SpeedTestEndpoints.appleConfiguration(config(
                        download: "https://defra1-edge-fx-023.aaplimg.com/large",
                        upload: "https://mensura.cdn-apple.com/api/v1/gm/slurp")) != nil,
                     "speed test accepts an Apple edge host")
        suite.expect(SpeedTestEndpoints.appleConfiguration(config(
                        download: "https://example.com/large",
                        upload: "https://mensura.cdn-apple.com/api/v1/gm/slurp")) == nil
                      && SpeedTestEndpoints.appleConfiguration(config(
                        download: "https://mensura.cdn-apple.com/api/v1/gm/large",
                        upload: "http://mensura.cdn-apple.com/api/v1/gm/slurp")) == nil
                      && SpeedTestEndpoints.appleConfiguration(config(
                        download: "https://notapple.com/large",
                        upload: "https://mensura.cdn-apple.com/api/v1/gm/slurp")) == nil,
                     "speed test sends traffic only to HTTPS on Apple hosts")
        suite.expect(SpeedTestEndpoints.appleConfiguration(Data("{}".utf8)) == nil
                      && SpeedTestEndpoints.appleConfiguration(Data("<html>".utf8)) == nil,
                     "speed test refuses a malformed Apple configuration")
    }

    // MARK: - Engine runs

    private static func successChecks(_ suite: TestSuite) {
        let harness = Harness()
        // The first handshake pays for DNS and is ignored.
        harness.transport.latencies = [.success(48)] + [6, 7, 5, 6, 8, 6, 5, 7, 6, 6].map { .success($0) }
        harness.transport.rate = { direction, age in
            let steady = direction == .download ? 12_500_000.0 : 6_250_000.0   // per stream: 800 / 400 Mbps over 8
            return age < 1 ? steady / 4 : steady
        }
        var phases: [SpeedTest.Phase] = []
        var downloads: [Double] = []
        var uploads: [Double] = []
        var bag = Set<AnyCancellable>()
        harness.test.$phase.removeDuplicates().sink { phases.append($0) }.store(in: &bag)
        harness.test.$downloadMbps.compactMap { $0 }.sink { downloads.append($0) }.store(in: &bag)
        harness.test.$uploadMbps.compactMap { $0 }.sink { uploads.append($0) }.store(in: &bag)

        harness.test.start()
        harness.time.advance(by: 30)
        drainMainQueue()

        let test = harness.test
        suite.expect(test.phase == .done, "speed test finishes every phase")
        suite.expect(phases == [.idle, .latency, .download, .upload, .done],
                     "speed test measures latency, download and upload one after the other")
        suite.expect(test.latencyMs == 6, "speed test reports the median handshake without the DNS lookup")
        suite.expect(test.serverName == "A", "speed test names the server that measured")
        // One ramping second at a quarter of the rate, then steady: the
        // readings show 200 ×4, 350, 500, 650, then 800 (or half of each for
        // the upload); the ramp-up's first 2.5 s stay out of the result.
        suite.expect(abs((test.downloadMbps ?? 0) - 800) < 0.01 && abs((test.uploadMbps ?? 0) - 400) < 0.01,
                     "speed test reports the mean reading across all streams after the ramp-up")
        suite.expect(downloads.count == 41 && downloads.prefix(4).allSatisfy { $0 < 201 }
                      && abs(downloads.last! - downloads.dropLast().suffix(30).reduce(0, +) / 30) < 0.01,
                     "speed test shows every reading but averages only the 30 after the ramp-up")
        suite.expect(harness.transport.opened(.download) == 8 && harness.transport.opened(.upload) == 8,
                     "speed test runs parallel streams in each direction")
        suite.expect(harness.transport.allClosed, "speed test closes every connection when it ends")
        // Four times a second for ten seconds each, the first readings still ramping up.
        suite.expect(downloads.count >= 40 && uploads.count >= 40
                      && (downloads.first ?? 0) < 400 && (uploads.first ?? 0) < 200,
                     "speed test publishes live readings four times a second")
        suite.expect(harness.time.pending == 0, "speed test leaves no timer behind")
        let downloadSeconds = (harness.transport.downloadClosedAt ?? 0) - harness.transport.downloadOpenedAt
        let uploadSeconds = (harness.transport.uploadClosedAt ?? 0) - harness.transport.uploadOpenedAt
        suite.expect(downloadSeconds > 9.99 && downloadSeconds < 10.01
                      && uploadSeconds > 9.99 && uploadSeconds < 10.01,
                     "speed test measures download and upload for ten seconds each")
    }

    private static func latencyFailureChecks(_ suite: TestSuite) {
        let harness = Harness()
        harness.transport.latencies = [.failure(.network)]
        harness.test.start()
        harness.time.advance(by: 10)
        drainMainQueue()
        suite.expect(harness.test.phase == .failed(.network) && harness.test.latencyMs == nil,
                     "speed test fails when no handshake succeeds")
        suite.expect(harness.transport.probes == 3 && harness.transport.opened(.download) == 0,
                     "speed test gives up after three failed handshakes, before any transfer")
        suite.expect(harness.time.pending == 0, "speed test leaves no timer behind after a failure")
    }

    private static func rateLimitChecks(_ suite: TestSuite) {
        let harness = Harness()
        harness.transport.latencies = [.success(6)]
        harness.transport.rate = { _, _ in 1_000_000 }
        harness.test.start()
        harness.time.advance(by: 3)
        harness.transport.endFirstStream(.rateLimited)
        harness.time.advance(by: 15)
        drainMainQueue()
        let test = harness.test
        suite.expect(test.phase == .failed(.rateLimited), "speed test reports a refusing server as rate limited")
        suite.expect(test.latencyMs == 6 && test.downloadMbps == nil && test.uploadMbps == nil,
                     "speed test keeps the finished latency but drops the cut-short download")
        suite.expect(harness.transport.allClosed && harness.transport.opened(.upload) == 0,
                     "speed test closes every stream and never starts the upload after a refusal")
        suite.expect(harness.time.pending == 0, "speed test leaves no timer behind after a refusal")
    }

    private static func stallChecks(_ suite: TestSuite) {
        let harness = Harness()
        harness.transport.latencies = [.success(6)]
        harness.transport.rate = { _, _ in 0 }
        harness.test.start()
        harness.time.advance(by: 15)
        drainMainQueue()
        suite.expect(harness.test.phase == .failed(.network) && harness.test.downloadMbps == nil,
                     "speed test fails a download that never moves a byte")
        suite.expect(harness.transport.allClosed, "speed test closes the stalled streams")
    }

    private static func cancelChecks(_ suite: TestSuite) {
        let harness = Harness()
        harness.transport.latencies = [.success(6)]
        harness.transport.rate = { _, _ in 1_000_000 }
        harness.test.start()
        harness.time.advance(by: 4)
        drainMainQueue()
        suite.expect(harness.test.phase == .download && harness.test.downloadMbps != nil,
                     "speed test shows the download while it runs")
        harness.test.cancel()
        harness.time.advance(by: 0)
        harness.time.advance(by: 20)
        drainMainQueue()
        let test = harness.test
        suite.expect(test.phase == .idle && test.latencyMs == 6 && test.downloadMbps == nil && test.uploadMbps == nil,
                     "speed test cancel keeps finished values and drops the live one")
        suite.expect(harness.transport.allClosed && harness.transport.opened(.upload) == 0
                      && harness.time.pending == 0,
                     "speed test cancel closes every connection and timer")
    }

    private static func fallbackChecks(_ suite: TestSuite) {
        let unreachable = Harness(names: ["A", "B"])
        unreachable.transports[0].latencies = [.failure(.network)]
        unreachable.transports[1].rate = { _, _ in 2_000_000 }
        unreachable.test.start()
        unreachable.time.advance(by: 30)
        drainMainQueue()
        suite.expect(unreachable.test.phase == .done && unreachable.test.serverName == "B"
                      && unreachable.test.latencyMs == 6 && unreachable.test.downloadMbps.map { abs($0 - 128) < 0.01 } == true,
                     "speed test falls back to the next server when the first is unreachable")
        suite.expect(unreachable.transports[0].probes == 3 && unreachable.transports[0].opened(.download) == 0
                      && unreachable.transports[1].opened(.download) == 8 && unreachable.transports[1].opened(.upload) == 8,
                     "speed test moves every measurement to the fallback server")

        let refused = Harness(names: ["A", "B"])
        refused.transports[0].prepareFailure = .badResponse
        refused.transports[1].rate = { _, _ in 1_000_000 }
        refused.test.start()
        refused.time.advance(by: 30)
        drainMainQueue()
        suite.expect(refused.test.phase == .done && refused.test.serverName == "B"
                      && refused.transports[0].probes == 0,
                     "speed test falls back when the first server's configuration fails")

        let limited = Harness(names: ["A", "B"])
        limited.transports[0].rate = { _, _ in 1_000_000 }
        limited.transports[1].rate = { _, _ in 1_000_000 }
        limited.test.start()
        limited.time.advance(by: 3)
        limited.transports[0].endFirstStream(.rateLimited)
        limited.time.advance(by: 30)
        drainMainQueue()
        suite.expect(limited.test.phase == .done && limited.test.serverName == "B"
                      && limited.transports[0].allClosed && limited.transports[0].opened(.upload) == 0,
                     "speed test starts over on the next server when one refuses traffic")
        suite.expect(limited.time.pending == 0, "speed test leaves no timer behind after a fallback")

        let both = Harness(names: ["A", "B"])
        both.transports[0].latencies = [.failure(.network)]
        both.transports[1].prepareFailure = .network
        both.test.start()
        both.time.advance(by: 30)
        drainMainQueue()
        suite.expect(both.test.phase == .failed(.network) && both.test.serverName == nil,
                     "speed test fails once every server has failed")
    }

    private static func drainMainQueue() {
        var drained = false
        DispatchQueue.main.async { drained = true }
        while !drained {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }
}

private final class Harness {
    let queue = DispatchQueue(label: "SpeedTestTests")
    let time: VirtualTime
    let transports: [FakeSpeedTransport]
    let test: SpeedTest

    var transport: FakeSpeedTransport { transports[0] }

    init(names: [String] = ["A"]) {
        time = VirtualTime(queue: queue)
        let time = self.time
        let queue = self.queue
        let transports = names.map { FakeSpeedTransport(name: $0, queue: queue, time: time) }
        self.transports = transports
        time.beforeStep = { seconds in transports.forEach { $0.deliver(for: seconds) } }
        test = SpeedTest(transports: transports, queue: queue, clock: time.now, scheduler: time.schedule)
    }
}

/// A virtual clock and scheduler: `advance` runs every due action in order on
/// the measurement queue, letting the fake streams move bytes in between.
private final class VirtualTime {
    private struct Entry {
        let id: Int
        let due: TimeInterval
        let action: () -> Void
    }

    private let lock = NSLock()
    private let queue: DispatchQueue
    private var current: TimeInterval = 100
    private var entries: [Entry] = []
    private var nextID = 0
    var beforeStep: (TimeInterval) -> Void = { _ in }

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func now() -> TimeInterval { lock.withLock { current } }

    var pending: Int { lock.withLock { entries.count } }

    func schedule(_ delay: TimeInterval, _ action: @escaping () -> Void) -> () -> Void {
        let id: Int = lock.withLock {
            nextID += 1
            entries.append(Entry(id: nextID, due: current + delay, action: action))
            return nextID
        }
        return { [weak self] in
            guard let self else { return }
            self.lock.withLock { self.entries.removeAll { $0.id == id } }
        }
    }

    func advance(by seconds: TimeInterval) {
        let target = now() + seconds
        while true {
            settle()
            let next: Entry? = lock.withLock {
                guard let index = entries.indices.min(by: {
                    (entries[$0].due, entries[$0].id) < (entries[$1].due, entries[$1].id)
                }), entries[index].due <= target + 1e-9 else { return nil }
                return entries.remove(at: index)
            }
            guard let next else { break }
            let step = next.due - now()
            if step > 0 {
                beforeStep(step)
                lock.withLock { current = next.due }
            }
            queue.sync { next.action() }
        }
        let rest = target - now()
        if rest > 0 {
            beforeStep(rest)
            lock.withLock { current = target }
        }
        settle()
    }

    /// Lets chains of asynchronous callbacks (a lookup answering, then a
    /// probe answering) land and schedule before time moves on.
    private func settle() {
        for _ in 0..<8 { queue.sync {} }
    }
}

private final class FakeSpeedTransport: SpeedTestTransport {
    final class Connection: SpeedTestConnection {
        let direction: SpeedTestDirection?
        let openedAt: TimeInterval
        let onBytes: (Int) -> Void
        let onEnd: (SpeedTestFailure?) -> Void
        var closedAt: TimeInterval?
        private let time: VirtualTime

        init(direction: SpeedTestDirection?, time: VirtualTime,
             onBytes: @escaping (Int) -> Void = { _ in }, onEnd: @escaping (SpeedTestFailure?) -> Void = { _ in }) {
            self.direction = direction
            self.time = time
            self.openedAt = time.now()
            self.onBytes = onBytes
            self.onEnd = onEnd
        }

        func cancel() {
            if closedAt == nil { closedAt = time.now() }
        }
    }

    let name: String
    private let queue: DispatchQueue
    private let time: VirtualTime
    var prepareFailure: SpeedTestFailure?
    // Touched only on `queue` (the engine calls in there; the test hops onto it).
    private var streams: [Connection] = []
    private var probeConnections: [Connection] = []
    var latencies: [Result<Double, SpeedTestFailure>] = [.success(6)]
    var rate: (SpeedTestDirection, TimeInterval) -> Double = { _, _ in 0 }

    init(name: String, queue: DispatchQueue, time: VirtualTime) {
        self.name = name
        self.queue = queue
        self.time = time
    }

    var probes: Int { queue.sync { probeConnections.count } }

    func opened(_ direction: SpeedTestDirection) -> Int {
        queue.sync { streams.filter { $0.direction == direction }.count }
    }

    var allClosed: Bool {
        queue.sync { (streams + probeConnections).allSatisfy { $0.closedAt != nil || $0.direction == nil } }
    }

    var downloadOpenedAt: TimeInterval {
        queue.sync { streams.first { $0.direction == .download }?.openedAt ?? 0 }
    }

    var downloadClosedAt: TimeInterval? {
        queue.sync { streams.first { $0.direction == .download }?.closedAt }
    }

    var uploadOpenedAt: TimeInterval {
        queue.sync { streams.first { $0.direction == .upload }?.openedAt ?? 0 }
    }

    var uploadClosedAt: TimeInterval? {
        queue.sync { streams.first { $0.direction == .upload }?.closedAt }
    }

    func prepare(on queue: DispatchQueue, completion: @escaping (SpeedTestFailure?) -> Void) -> SpeedTestConnection {
        let lookup = Connection(direction: nil, time: time)
        let failure = prepareFailure
        queue.async {
            if lookup.closedAt == nil { completion(failure) }
        }
        return lookup
    }

    func probeLatency(on queue: DispatchQueue,
                      completion: @escaping (Result<Double, SpeedTestFailure>) -> Void) -> SpeedTestConnection {
        let result = latencies.count > 1 ? latencies.removeFirst() : latencies[0]
        let probe = Connection(direction: nil, time: time)
        probeConnections.append(probe)
        queue.async {
            if probe.closedAt == nil { completion(result) }
        }
        return probe
    }

    func openStream(_ direction: SpeedTestDirection, on queue: DispatchQueue,
                    onBytes: @escaping (Int) -> Void,
                    onEnd: @escaping (SpeedTestFailure?) -> Void) -> SpeedTestConnection {
        let stream = Connection(direction: direction, time: time, onBytes: onBytes, onEnd: onEnd)
        streams.append(stream)
        return stream
    }

    /// Moves each open stream's bytes for the next `seconds` of virtual time.
    func deliver(for seconds: TimeInterval) {
        let now = time.now()
        queue.sync {
            for stream in streams where stream.closedAt == nil {
                guard let direction = stream.direction else { continue }
                let count = Int(rate(direction, now - stream.openedAt) * seconds)
                if count > 0 { stream.onBytes(count) }
            }
        }
    }

    func endFirstStream(_ failure: SpeedTestFailure?) {
        queue.sync {
            guard let stream = streams.first(where: { $0.closedAt == nil && $0.direction != nil }) else { return }
            stream.onEnd(failure)
        }
    }
}
