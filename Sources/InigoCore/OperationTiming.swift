import Foundation

public enum OperationStage: String, CaseIterable, Sendable { case capture, load, generate, validate, insert }
public enum OperationOutcome: String, Sendable { case replaced, unchanged, copyOnly, failed, cancelled }

/// Only fixed categories and monotonic durations; never accepts writing or exceptions.
public struct OperationTiming: Sendable {
    private let started: UInt64
    private var changed: UInt64
    private var stage: OperationStage
    public private(set) var milliseconds: [OperationStage: Double] = [:]
    public private(set) var outcome: OperationOutcome?
    public private(set) var totalMilliseconds: Double = 0
    public init(now: UInt64 = DispatchTime.now().uptimeNanoseconds) {
        started = now; changed = now; stage = .capture
    }
    public mutating func transition(_ next: OperationStage, now: UInt64 = DispatchTime.now().uptimeNanoseconds) {
        guard outcome == nil else { return }
        milliseconds[stage, default: 0] += Double(now >= changed ? now - changed : 0) / 1_000_000
        stage = next; changed = now
    }
    public mutating func finish(_ result: OperationOutcome, now: UInt64 = DispatchTime.now().uptimeNanoseconds) {
        guard outcome == nil else { return }
        transition(stage, now: now); outcome = result
        totalMilliseconds = Double(now >= started ? now - started : 0) / 1_000_000
    }
}
