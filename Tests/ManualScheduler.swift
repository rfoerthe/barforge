// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import Foundation

/// A main queue with a hand-driven clock, for production bodies that schedule
/// work with `DispatchQueue.main`. Nothing runs until the test advances time.
enum ManualScheduler {
    struct Deadline {
        let seconds: Double
        static func now() -> Self { Self(seconds: DispatchQueue.main.now) }
        static func + (left: Self, right: Double) -> Self { Self(seconds: left.seconds + right) }
    }
    final class Scheduler {
        var now: Double = 0
        var jobs: [(Deadline, DispatchWorkItem)] = []
        var pending: Int { jobs.filter { !$0.1.isCancelled }.count }
        func async(execute work: DispatchWorkItem) { jobs.append((.now(), work)) }
        func async(execute work: @escaping () -> Void) {
            asyncAfter(deadline: .init(seconds: now), execute: DispatchWorkItem(block: work))
        }
        func asyncAfter(deadline: Deadline, execute work: DispatchWorkItem) { jobs.append((deadline, work)) }
        func advance(_ seconds: Double) {
            now += seconds
            while let index = jobs.firstIndex(where: { $0.0.seconds <= now }) {
                let work = jobs.remove(at: index).1
                if !work.isCancelled { work.perform() }
            }
        }
    }
    enum DispatchQueue { static var main = Scheduler() }
}
