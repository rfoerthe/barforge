// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation
import IOKit.hid

/// The IOKit half of HID++: finds Logitech receivers and Bluetooth mice,
/// sends requests and hands back replies and events. Everything runs on one
/// worker thread with its own run loop, so a request can simply wait for its
/// reply without ever holding up the main thread.
///
/// While a request waits, the run loop runs in a private mode that only the
/// HID sources belong to. Work scheduled with `perform` stays in the default
/// mode, so a second request can never start inside the first one's wait.
final class HIDPPTransport {
    /// One opened HID++ interface: a receiver or a directly paired mouse.
    final class Device {
        let hid: IOHIDDevice
        let productID: Int
        let interface: HIDPP.Interface
        let product: String
        fileprivate let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        fileprivate(set) var isRemoved = false
        fileprivate weak var transport: HIDPPTransport?

        fileprivate init(hid: IOHIDDevice) {
            self.hid = hid
            productID = IOHIDDeviceGetProperty(hid, kIOHIDProductIDKey as CFString) as? Int ?? 0
            product = IOHIDDeviceGetProperty(hid, kIOHIDProductKey as CFString) as? String ?? ""
            let pairs = (IOHIDDeviceGetProperty(hid, kIOHIDDeviceUsagePairsKey as CFString) as? [[String: Any]] ?? [])
                .compactMap { pair -> (page: Int, usage: Int)? in
                    guard let page = pair[kIOHIDDeviceUsagePageKey] as? Int,
                          let usage = pair[kIOHIDDeviceUsageKey] as? Int else { return nil }
                    return (page, usage)
                }
            // Matching already required one of the two collections.
            interface = HIDPP.interface(usagePairs: pairs) ?? .direct
        }

        deinit { buffer.deallocate() }

        /// A receiver numbers its mice 1…6; a Bluetooth mouse is index 0xFF.
        var isReceiver: Bool { interface == .receiver }

        var candidateIndices: [UInt8] {
            isReceiver ? HIDPP.receiverDeviceIndices : [HIDPP.directDeviceIndex]
        }
    }

    enum RequestError: Error, Equatable {
        case sendFailed
        case timedOut
        case unreachable
        case removed
        case device(code: UInt8)
    }

    /// Called on the worker thread, never inside a request's wait.
    var onDeviceAdded: ((Device) -> Void)?
    var onDeviceRemoved: ((Device) -> Void)?
    var onMessage: ((Device, HIDPP.Message) -> Void)?

    private let waitMode = CFRunLoopMode("com.vorssaint.hidpp.wait" as CFString)
    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private var manager: IOHIDManager?
    private var devices: [Device] = []

    private struct PendingRequest {
        let device: ObjectIdentifier
        let deviceIndex: UInt8
        let featureIndex: UInt8
        let function: UInt8
        var result: Result<[UInt8], RequestError>?
    }

    private var pending: PendingRequest?
    private var pendingRegister: (device: ObjectIdentifier, subID: UInt8, register: UInt8, reply: [UInt8]?)?

    var isRunning: Bool { thread != nil }

    // MARK: - Lifecycle

    func start() {
        guard thread == nil else { return }
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            guard let self else { ready.signal(); return }
            self.runLoop = CFRunLoopGetCurrent()
            CFRunLoopAddCommonMode(CFRunLoopGetCurrent(), self.waitMode)
            self.openManager()
            ready.signal()
            // A timer far in the future keeps the run loop alive between
            // devices; stop() ends it explicitly.
            let keepAlive = CFRunLoopTimerCreateWithHandler(nil, .greatestFiniteMagnitude, 0, 0, 0) { _ in }
            CFRunLoopAddTimer(CFRunLoopGetCurrent(), keepAlive, .defaultMode)
            CFRunLoopRun()
            CFRunLoopTimerInvalidate(keepAlive)
        }
        thread.name = "com.vorssaint.logitech-mx"
        thread.qualityOfService = .userInteractive
        self.thread = thread
        thread.start()
        ready.wait()
    }

    /// Runs `cleanup` on the worker (devices still open), then closes
    /// everything and ends the thread.
    func stop(cleanup: (() -> Void)? = nil) {
        guard thread != nil else { return }
        let finished = DispatchSemaphore(value: 0)
        perform { [weak self] in
            cleanup?()
            self?.closeManager()
            CFRunLoopStop(CFRunLoopGetCurrent())
            finished.signal()
        }
        // Bounded: a wedged device must not hang quitting the app.
        _ = finished.wait(timeout: .now() + 3)
        thread = nil
        runLoop = nil
    }

    /// Schedules work on the worker thread, outside any request's wait.
    func perform(after delay: TimeInterval = 0, _ block: @escaping () -> Void) {
        guard let runLoop else { return }
        if delay > 0 {
            let timer = CFRunLoopTimerCreateWithHandler(nil, CFAbsoluteTimeGetCurrent() + delay, 0, 0, 0) { _ in
                block()
            }
            CFRunLoopAddTimer(runLoop, timer, .defaultMode)
        } else {
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue, block)
        }
        CFRunLoopWakeUp(runLoop)
    }

    // MARK: - Requests (worker thread only)

    func request(_ device: Device, deviceIndex: UInt8, featureIndex: UInt8, function: UInt8,
                 parameters: [UInt8] = [], timeout: TimeInterval = 1.0) -> Result<[UInt8], RequestError> {
        guard !device.isRemoved else { return .failure(.removed) }
        let packet = HIDPP.request(deviceIndex: deviceIndex, featureIndex: featureIndex,
                                   function: function, parameters: parameters)
        pending = PendingRequest(device: ObjectIdentifier(device), deviceIndex: deviceIndex,
                                 featureIndex: featureIndex, function: function)
        defer { pending = nil }
        let sent = packet.withUnsafeBufferPointer { pointer in
            IOHIDDeviceSetReport(device.hid, kIOHIDReportTypeOutput, CFIndex(packet[0]),
                                 pointer.baseAddress!, pointer.count)
        }
        guard sent == kIOReturnSuccess else { return .failure(.sendFailed) }
        let deadline = CFAbsoluteTimeGetCurrent() + timeout
        while pending?.result == nil, !device.isRemoved, CFAbsoluteTimeGetCurrent() < deadline {
            CFRunLoopRunInMode(waitMode, 0.05, true)
        }
        if device.isRemoved { return .failure(.removed) }
        return pending?.result ?? .failure(.timedOut)
    }

    /// HID++ 1.0 register access on a receiver (short report, index 0xFF).
    /// Used only to switch on the receiver's connection notifications.
    func receiverRegister(_ device: Device, write: Bool, register: UInt8,
                          parameters: [UInt8] = [0, 0, 0]) -> [UInt8]? {
        guard !device.isRemoved, device.isReceiver else { return nil }
        let subID: UInt8 = write ? 0x80 : 0x81
        var packet: [UInt8] = [HIDPP.shortReportID, HIDPP.directDeviceIndex, subID, register]
        packet += parameters.prefix(3)
        packet += Array(repeating: 0, count: 7 - packet.count)
        pendingRegister = (ObjectIdentifier(device), subID, register, nil)
        defer { pendingRegister = nil }
        let sent = packet.withUnsafeBufferPointer { pointer in
            IOHIDDeviceSetReport(device.hid, kIOHIDReportTypeOutput, CFIndex(packet[0]),
                                 pointer.baseAddress!, pointer.count)
        }
        guard sent == kIOReturnSuccess else { return nil }
        let deadline = CFAbsoluteTimeGetCurrent() + 0.5
        while pendingRegister?.reply == nil, !device.isRemoved, CFAbsoluteTimeGetCurrent() < deadline {
            CFRunLoopRunInMode(waitMode, 0.05, true)
        }
        return pendingRegister?.reply
    }

    // MARK: - IOKit

    private func openManager() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        // Matched on any usage pair, not the primary usage: a Bluetooth MX
        // Master is one device whose primary usage is its keyboard collection.
        let matching: [[String: Any]] = [
            (HIDPP.receiverUsagePage, HIDPP.receiverUsage),
            (HIDPP.bluetoothUsagePage, HIDPP.bluetoothUsage),
        ].map {
            [kIOHIDVendorIDKey: HIDPP.logitechVendorID, kIOHIDDeviceUsagePageKey: $0.0, kIOHIDDeviceUsageKey: $0.1]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, hid in
            guard let context else { return }
            Unmanaged<HIDPPTransport>.fromOpaque(context).takeUnretainedValue().deviceMatched(hid)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, hid in
            guard let context else { return }
            Unmanaged<HIDPPTransport>.fromOpaque(context).takeUnretainedValue().deviceRemoved(hid)
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
    }

    private func closeManager() {
        guard let manager else { return }
        for device in devices {
            device.isRemoved = true
            IOHIDDeviceRegisterInputReportCallback(device.hid, device.buffer, 64, nil, nil)
            IOHIDDeviceClose(device.hid, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        devices.removeAll()
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
    }

    private func deviceMatched(_ hid: IOHIDDevice) {
        guard !devices.contains(where: { $0.hid == hid }) else { return }
        // Opened outright: the manager's own open did not reach a mouse
        // paired over Bluetooth, and every output report to it then failed.
        guard IOHIDDeviceOpen(hid, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { return }
        let device = Device(hid: hid)
        device.transport = self
        devices.append(device)
        let context = Unmanaged.passUnretained(device).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(hid, device.buffer, 64, { context, _, _, _, _, report, length in
            guard let context else { return }
            let device = Unmanaged<Device>.fromOpaque(context).takeUnretainedValue()
            let bytes = Array(UnsafeBufferPointer(start: report, count: length))
            device.transport?.received(bytes, from: device)
        }, context)
        // Matching can fire inside a request's wait; probing waits on replies
        // of its own, so it starts from the default mode instead.
        perform { [weak self, weak device] in
            guard let self, let device, !device.isRemoved else { return }
            self.onDeviceAdded?(device)
        }
    }

    private func deviceRemoved(_ hid: IOHIDDevice) {
        guard let position = devices.firstIndex(where: { $0.hid == hid }) else { return }
        let device = devices.remove(at: position)
        device.isRemoved = true
        perform { [weak self] in self?.onDeviceRemoved?(device) }
    }

    private func received(_ report: [UInt8], from device: Device) {
        // Receiver register replies have no software ID to match on.
        if let register = pendingRegister, register.device == ObjectIdentifier(device),
           report.count >= 4, report[0] == HIDPP.shortReportID, report[1] == HIDPP.directDeviceIndex,
           report[2] == register.subID, report[3] == register.register {
            pendingRegister?.reply = Array(report.dropFirst(4))
            return
        }
        let message = HIDPP.classify(report)
        if var request = pending, request.device == ObjectIdentifier(device) {
            switch message {
            case let .reply(index, feature, function, payload)
                where index == request.deviceIndex && feature == request.featureIndex
                    && function == request.function:
                request.result = .success(payload)
                pending = request
                return
            case let .error(index, feature, function, code)
                where index == request.deviceIndex && feature == request.featureIndex
                    && function == request.function:
                request.result = .failure(.device(code: code))
                pending = request
                return
            case let .unreachable(index) where index == request.deviceIndex:
                request.result = .failure(.unreachable)
                pending = request
                return
            default:
                break
            }
        }
        switch message {
        case .event, .connection:
            perform { [weak self, weak device] in
                guard let self, let device, !device.isRemoved else { return }
                self.onMessage?(device, message)
            }
        default:
            break
        }
    }
}
