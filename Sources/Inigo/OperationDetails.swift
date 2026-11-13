import Foundation
import InigoCore

enum ProcessingCategory: String {
    case managed2B = "Managed 2B", managed4B = "Managed 4B", managed9B = "Managed 9B"
    case customLocal = "Custom local model", externalLocal = "External local server", cloud = "Cloud", layout = "Keyboard layout"
}

struct OperationDetails {
    let timing: OperationTiming
    let processing: ProcessingCategory
    func summary(version: String, os: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion,
                 memory: UInt64 = ProcessInfo.processInfo.physicalMemory, processors: Int = ProcessInfo.processInfo.processorCount) -> String {
        let version = version.range(of: #"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$"#, options: .regularExpression) == nil ? "development" : version
        var lines = ["Inigo: \(version)", "macOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
                     "Memory: \(memory / 1_073_741_824) GiB; processors: \(processors)", "Processing: \(processing.rawValue)",
                     "Outcome: \(timing.outcome?.rawValue ?? "pending")"]
        for stage in OperationStage.allCases { lines.append(String(format: "%@: %.0f ms", stage.rawValue, timing.milliseconds[stage, default: 0])) }
        lines.append(String(format: "total: %.0f ms", timing.totalMilliseconds))
        return lines.joined(separator: "\n")
    }
}
