import Foundation
import InigoCore

struct Sample: Decodable {
    let id: String
    let language: String
    let draft: String
    let context: String?
    let action: String
    let target: String?
}
guard CommandLine.arguments.count == 3, CommandLine.arguments[1] == "export" else {
    fatalError("Usage: InigoBench export benchmarks/cases.json")
}
let samples = try JSONDecoder().decode([Sample].self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[2])))
var result: [[String:Any]] = []
for sample in samples {
    let protected = try ProtectedDraft(sample.draft)
    let action: RewriteAction = sample.action == "translate" ? .translate(SupportedLanguage(rawValue:sample.target!)!) : .refine
    let request = RewriteRequest(draft:protected.masked,context:sample.context ?? "",action:action)
    // Keep synthetic marker mappings so the standalone runner can verify exact protection.
    let pattern = try NSRegularExpression(pattern:"⟦INIGO_[^⟧]*⟧")
    let tokens = pattern.matches(in:protected.masked,range:NSRange(location:0,length:protected.masked.utf16.count)).map { (protected.masked as NSString).substring(with:$0.range) }
    result.append(["id":sample.id,"messages":[["role":"system","content":request.instructions],["role":"user","content":request.input]],"tokens":tokens])
}
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]))
