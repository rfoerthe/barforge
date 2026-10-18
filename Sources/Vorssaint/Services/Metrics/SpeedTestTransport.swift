// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import Network

/// Where one speed test run sends its traffic. The download URL is fetched
/// again and again until the time is up; the upload URL takes repeated POSTs.
struct SpeedTestEndpoints: Equatable {
    let download: URL
    let upload: URL

    /// Cloudflare's public speed endpoints (the backend speed.cloudflare.com
    /// uses). __down answers only below 100 MB, so each request asks for 50 MB.
    static let cloudflare = SpeedTestEndpoints(
        download: URL(string: "https://speed.cloudflare.com/__down?bytes=50000000")!,
        upload: URL(string: "https://speed.cloudflare.com/__up")!)

    /// The configuration macOS's own `networkQuality` reads; it names the
    /// nearest Apple edge's download and upload URLs.
    static let appleConfigURL = URL(string: "https://mensura.cdn-apple.com/api/v1/gm/config")!

    /// The endpoints in an Apple networkQuality configuration, or nil when it
    /// is malformed or points anywhere but HTTPS on an Apple host.
    static func appleConfiguration(_ data: Data) -> SpeedTestEndpoints? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urls = object["urls"] as? [String: Any],
              let download = (urls["large_https_download_url"] as? String).flatMap(URL.init(string:)),
              let upload = (urls["https_upload_url"] as? String).flatMap(URL.init(string:)),
              isAppleHTTPS(download), isAppleHTTPS(upload) else { return nil }
        return SpeedTestEndpoints(download: download, upload: upload)
    }

    private static func isAppleHTTPS(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        return ["apple.com", "cdn-apple.com", "aaplimg.com"].contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

/// Speed test traffic spoken as plain HTTP/1.1 over one TLS socket per stream.
/// URLSession would multiplex every stream onto one HTTP/2 or QUIC connection
/// and hide per-request gaps; own sockets keep each stream a separate TCP
/// connection, the way reference broadband tests measure.
final class HTTPSpeedTestTransport: SpeedTestTransport {
    typealias Resolver = (DispatchQueue, @escaping (SpeedTestEndpoints?) -> Void) -> SpeedTestConnection

    let name: String
    private let resolve: Resolver
    private let connectTimeout: TimeInterval
    private var endpoints: SpeedTestEndpoints?   // set by `prepare`, on the engine's queue

    init(name: String, connectTimeout: TimeInterval = 3, resolve: @escaping Resolver) {
        self.name = name
        self.connectTimeout = connectTimeout
        self.resolve = resolve
    }

    /// Apple's networkQuality servers: fast, near, and without the volume
    /// limit that locks Cloudflare's endpoints for an hour after a few runs.
    static func apple() -> HTTPSpeedTestTransport {
        HTTPSpeedTestTransport(name: "Apple") { queue, completion in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 5
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            let session = URLSession(configuration: configuration)
            let task = session.dataTask(with: SpeedTestEndpoints.appleConfigURL) { data, response, _ in
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let endpoints = (200...299).contains(status) ? data.flatMap(SpeedTestEndpoints.appleConfiguration) : nil
                queue.async { completion(endpoints) }
            }
            task.resume()
            session.finishTasksAndInvalidate()
            return SpeedTestTaskConnection(task: task)
        }
    }

    static func cloudflare() -> HTTPSpeedTestTransport {
        HTTPSpeedTestTransport(name: "Cloudflare") { queue, completion in
            let connection = SpeedTestTaskConnection(task: nil)
            queue.async { if !connection.isCancelled { completion(.cloudflare) } }
            return connection
        }
    }

    func prepare(on queue: DispatchQueue, completion: @escaping (SpeedTestFailure?) -> Void) -> SpeedTestConnection {
        endpoints = nil
        return resolve(queue) { [weak self] endpoints in
            self?.endpoints = endpoints
            completion(endpoints == nil ? .badResponse : nil)
        }
    }

    /// The TCP handshake time: one round trip with no server-side work in it.
    /// (Cloudflare spends ~50 ms building even an empty HTTP response, so an
    /// HTTP round trip would mostly measure the server.)
    func probeLatency(on queue: DispatchQueue,
                      completion: @escaping (Result<Double, SpeedTestFailure>) -> Void) -> SpeedTestConnection {
        guard let url = endpoints?.download, let host = url.host else { return failed(on: queue, completion) }
        return TCPHandshakeProbe(host: host, port: url.port ?? 443, timeout: connectTimeout,
                                 queue: queue, completion: completion)
    }

    func openStream(_ direction: SpeedTestDirection, on queue: DispatchQueue,
                    onBytes: @escaping (Int) -> Void,
                    onEnd: @escaping (SpeedTestFailure?) -> Void) -> SpeedTestConnection {
        guard let endpoints else {
            return failed(on: queue) { _ in onEnd(.network) }
        }
        return HTTPTransferStream(direction: direction,
                                  url: direction == .download ? endpoints.download : endpoints.upload,
                                  timeout: connectTimeout, queue: queue, onBytes: onBytes, onEnd: onEnd)
    }

    private func failed(on queue: DispatchQueue,
                        _ completion: @escaping (Result<Double, SpeedTestFailure>) -> Void) -> SpeedTestConnection {
        let connection = SpeedTestTaskConnection(task: nil)
        queue.async { if !connection.isCancelled { completion(.failure(.network)) } }
        return connection
    }
}

/// A cancellable handle for a URLSession task, or for a callback already queued.
private final class SpeedTestTaskConnection: SpeedTestConnection {
    private let task: URLSessionTask?
    private let lock = NSLock()
    private var cancelled = false

    init(task: URLSessionTask?) {
        self.task = task
    }

    var isCancelled: Bool { lock.withLock { cancelled } }

    func cancel() {
        lock.withLock { cancelled = true }
        task?.cancel()
    }
}

private final class TCPHandshakeProbe: SpeedTestConnection {
    private let connection: NWConnection
    private var completion: ((Result<Double, SpeedTestFailure>) -> Void)?
    private var timeout: DispatchWorkItem?

    init(host: String, port: Int, timeout: TimeInterval, queue: DispatchQueue,
         completion: @escaping (Result<Double, SpeedTestFailure>) -> Void) {
        connection = NWConnection(host: NWEndpoint.Host(host),
                                  port: NWEndpoint.Port(rawValue: UInt16(clamping: port)) ?? .https, using: .tcp)
        self.completion = completion
        let started = DispatchTime.now().uptimeNanoseconds
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
                self?.finish(.success(elapsed))
            case .failed, .waiting:
                self?.finish(.failure(.network))
            default:
                break
            }
        }
        let work = DispatchWorkItem { [weak self] in self?.finish(.failure(.network)) }
        self.timeout = work
        queue.asyncAfter(deadline: .now() + timeout, execute: work)
        connection.start(queue: queue)
    }

    private func finish(_ result: Result<Double, SpeedTestFailure>) {
        guard let completion else { return }
        self.completion = nil
        cancel()
        completion(result)
    }

    func cancel() {
        completion = nil
        timeout?.cancel(); timeout = nil
        connection.stateUpdateHandler = nil
        connection.cancel()
    }
}

/// One keep-alive connection that repeats a download (GET) or upload (POST)
/// request back to back until cancelled.
private final class HTTPTransferStream: SpeedTestConnection {
    // Cloudflare caps request bodies at 100 MB, so uploads stay well under
    // that and simply repeat.
    private static let uploadBytes = 40_000_000
    private static let piece = Data(count: 1 << 20)
    private static let piecesInFlight = 2

    private let direction: SpeedTestDirection
    private let hostHeader: String
    private let target: String
    private let connection: NWConnection
    private let onBytes: (Int) -> Void
    private var onEnd: ((SpeedTestFailure?) -> Void)?
    private var connectTimeout: DispatchWorkItem?
    private var parser = SpeedTestHTTPResponseParser()
    private var ended = false
    // Upload request state.
    private var bodyQueued = 0
    private var bodySent = 0
    private var piecesSending = 0
    private var responseDone = false

    init(direction: SpeedTestDirection, url: URL, timeout: TimeInterval, queue: DispatchQueue,
         onBytes: @escaping (Int) -> Void, onEnd: @escaping (SpeedTestFailure?) -> Void) {
        self.direction = direction
        let host = url.host ?? ""
        let port = url.port ?? 443
        hostHeader = port == 443 ? host : "\(host):\(port)"
        let path = url.path.isEmpty ? "/" : url.path
        target = url.query.map { "\(path)?\($0)" } ?? path
        self.onBytes = onBytes
        self.onEnd = onEnd
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.connectionTimeout = Int(timeout.rounded(.up))
        connection = NWConnection(host: NWEndpoint.Host(host),
                                  port: NWEndpoint.Port(rawValue: UInt16(clamping: port)) ?? .https,
                                  using: NWParameters(tls: NWProtocolTLS.Options(), tcp: tcp))
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.connectTimeout?.cancel(); self.connectTimeout = nil
                self.sendRequest()
                self.receive()
            case .failed, .waiting:
                self.end(.network)
            default:
                break
            }
        }
        // TLS on top of TCP: give the whole set-up one extra timeout's grace.
        let work = DispatchWorkItem { [weak self] in self?.end(.network) }
        connectTimeout = work
        queue.asyncAfter(deadline: .now() + timeout * 2, execute: work)
        connection.start(queue: queue)
    }

    func cancel() {
        ended = true
        onEnd = nil
        connectTimeout?.cancel(); connectTimeout = nil
        connection.stateUpdateHandler = nil
        connection.cancel()
    }

    private func end(_ failure: SpeedTestFailure?) {
        guard !ended else { return }
        let onEnd = self.onEnd
        cancel()
        onEnd?(failure)
    }

    private func sendRequest() {
        guard !ended else { return }
        parser = SpeedTestHTTPResponseParser()
        let head: String
        switch direction {
        case .download:
            head = "GET \(target) HTTP/1.1\r\n"
                + "Host: \(hostHeader)\r\nAccept: */*\r\nConnection: keep-alive\r\n\r\n"
        case .upload:
            bodyQueued = 0
            bodySent = 0
            responseDone = false
            head = "POST \(target) HTTP/1.1\r\nHost: \(hostHeader)\r\nAccept: */*\r\nConnection: keep-alive\r\n"
                + "Content-Type: application/octet-stream\r\nContent-Length: \(Self.uploadBytes)\r\n\r\n"
        }
        connection.send(content: Data(head.utf8), completion: .contentProcessed { [weak self] error in
            if error != nil { self?.end(.network) }
        })
        if direction == .upload { pumpBody() }
    }

    /// Keeps a couple of zero-filled pieces queued so the socket never idles.
    private func pumpBody() {
        while !ended, piecesSending < Self.piecesInFlight, bodyQueued < Self.uploadBytes {
            let size = min(Self.piece.count, Self.uploadBytes - bodyQueued)
            bodyQueued += size
            piecesSending += 1
            let content = size == Self.piece.count ? Self.piece : Self.piece.prefix(size)
            connection.send(content: content, completion: .contentProcessed { [weak self] error in
                guard let self, !self.ended else { return }
                self.piecesSending -= 1
                if error != nil { self.end(.network); return }
                self.bodySent += size
                self.onBytes(size)
                self.pumpBody()
                self.nextUploadIfDone()
            })
        }
    }

    private func nextUploadIfDone() {
        if responseDone, bodySent >= Self.uploadBytes { sendRequest() }
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, error in
            guard let self, !self.ended else { return }
            if let data, !data.isEmpty, !self.handle(data) { return }
            if error != nil { self.end(.network); return }
            if isComplete { self.end(nil); return }
            self.receive()
        }
    }

    /// Feeds response bytes through the parser; false once the stream ended.
    private func handle(_ data: Data) -> Bool {
        for event in parser.consume(data) {
            switch event {
            case .head(let status):
                if status == 429 { end(.rateLimited); return false }
                if !(200...299).contains(status) { end(.badResponse); return false }
            case .body(let count):
                if direction == .download { onBytes(count) }
            case .complete:
                if direction == .download {
                    sendRequest()
                } else if bodySent >= Self.uploadBytes || bodyQueued >= Self.uploadBytes {
                    responseDone = true
                    nextUploadIfDone()
                } else {
                    // The server answered before the body was in: it refused it.
                    end(.badResponse); return false
                }
                return !ended
            case .malformed:
                end(.badResponse); return false
            }
        }
        return !ended
    }
}

/// Just enough HTTP/1.1 response parsing to count body bytes and see where a
/// response ends: status line, Content-Length, body.
struct SpeedTestHTTPResponseParser {
    enum Event: Equatable {
        case head(status: Int)
        case body(Int)
        case complete
        case malformed
    }

    private static let headLimit = 16 * 1024
    private static let terminator = Data("\r\n\r\n".utf8)
    private var head = Data()
    private var remaining: Int?

    mutating func consume(_ data: Data) -> [Event] {
        guard let remaining else { return consumeHead(data) }
        guard remaining > 0 else { return [] }
        let count = min(data.count, remaining)
        self.remaining = remaining - count
        return count < remaining ? [.body(count)] : [.body(count), .complete]
    }

    private mutating func consumeHead(_ data: Data) -> [Event] {
        head.append(data)
        guard let end = head.range(of: Self.terminator) else {
            return head.count > Self.headLimit ? [.malformed] : []
        }
        let text = String(decoding: head[head.startIndex..<end.lowerBound], as: UTF8.self)
        let lines = text.components(separatedBy: "\r\n")
        let statusParts = lines.first?.split(separator: " ") ?? []
        guard statusParts.count >= 2, statusParts[0].hasPrefix("HTTP/1."),
              let status = Int(statusParts[1]) else { return [.malformed] }
        var length: Int?
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                length = Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
        }
        // A success must say how long it is; an error ends the stream anyway.
        guard let length, length >= 0 else {
            return (200...299).contains(status) ? [.head(status: status), .malformed] : [.head(status: status)]
        }
        let leftover = head.count - (end.upperBound - head.startIndex)
        head = Data()
        remaining = length
        var events: [Event] = [.head(status: status)]
        let count = min(leftover, length)
        if count > 0 { events.append(.body(count)) }
        remaining = length - count
        if length - count == 0 { events.append(.complete) }
        return events
    }
}
