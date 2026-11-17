import Foundation
import InigoCore

enum ProcessingCategory: String {
    case managed2B = "Managed 2B", managed4B = "Managed 4B", managed9B = "Managed 9B"
    case customLocal = "Custom local model", externalLocal = "External local server", cloud = "Cloud", layout = "Keyboard layout"

    static func local(_ configuration: LocalModelConfiguration) -> Self {
        switch configuration.kind {
        case .server: return .externalLocal
        case .file: return .customLocal
        case .managed: return ["2B": .managed2B, "4B": .managed4B, "9B": .managed9B][configuration.modelID] ?? .customLocal
        }
    }

    func generationMessage(for action: RewriteAction) -> String {
        switch self {
        case .cloud: return action == .refine ? "Refining with ChatGPT…" : "Translating with ChatGPT…"
        case .externalLocal: return action == .refine ? "Refining with your local server…" : "Translating with your local server…"
        case .managed2B, .managed4B, .managed9B, .customLocal:
            return action == .refine ? "Refining on your Mac…" : "Translating on your Mac…"
        case .layout: return "Working on your selection…"
        }
    }
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
