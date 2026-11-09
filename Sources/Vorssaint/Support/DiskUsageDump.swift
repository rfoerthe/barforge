// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Prints what the disk usage scanner counts for a folder, without opening a
/// window: `Barforge --disk-usage PATH`. A volume's mount point also lists
/// its hidden, purgeable and free space. Output is for people and scripts,
/// so numbers stay locale-independent.
enum DiskUsageDump {
    static let argument = "--disk-usage"

    static func runIfRequestedAndExit(_ arguments: [String] = CommandLine.arguments) {
        guard let index = arguments.firstIndex(of: argument) else { return }
        guard index + 1 < arguments.count else {
            FileHandle.standardError.write(Data("usage: \(arguments[0]) \(argument) PATH\n".utf8))
            exit(2)
        }
        let path = arguments[index + 1]
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            FileHandle.standardError.write(Data("not a folder: \(path)\n".utf8))
            exit(1)
        }
        let isVolume = (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.isVolumeKey]))?.isVolume == true
        let progress = DiskUsageScanProgress()
        let started = ProcessInfo.processInfo.systemUptime
        let tree = DiskUsageScanner.scan(path, volume: isVolume ? DiskUsageVolumeSpace.read(forVolumeAt: path) : nil,
                                         progress: progress)
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        for child in tree.nodes[tree.root].children {
            let node = tree.nodes[child]
            print(line(node.size, label(for: node)))
        }
        print(line(tree.rootSize, tree.rootPath))
        let summary = String(format: "%llu files in %.2f s", locale: Locale(identifier: "en_US_POSIX"),
                             progress.files.load(ordering: .relaxed), elapsed)
        FileHandle.standardError.write(Data((summary + "\n").utf8))
        exit(0)
    }

    private static func label(for node: DiskUsageNode) -> String {
        switch node.kind {
        case .directory: return node.name + "/"
        case .file: return node.name
        case .hidden: return "[hidden space]"
        case .purgeable: return "[purgeable space]"
        case .free: return "[free space]"
        }
    }

    private static func line(_ bytes: UInt64, _ label: String) -> String {
        let locale = MetricFormat.locale
        MetricFormat.locale = Locale(identifier: "en_US_POSIX")
        defer { MetricFormat.locale = locale }
        let size = MetricFormat.diskBytesPrecise(bytes)
        let padding = String(repeating: " ", count: max(0, 10 - size.count))
        return padding + size + String(format: "  %15llu  ", locale: Locale(identifier: "en_US_POSIX"), bytes) + label
    }
}
