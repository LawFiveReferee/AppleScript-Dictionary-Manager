import Foundation

enum PreviewTextBuilder {
    static func makeText(from model: SDEFDocumentModel) -> String {
        var out: [String] = []
        for s in model.suites {
            out.append("Suite: \(s.name)    Code: \(s.code)")
            if !s.classes.isEmpty {
                out.append("  Classes (\(s.classes.count)):")
                for c in s.classes {
                    out.append("    • \(c.name) [\(c.code)]")
                    for p in c.properties {
                        out.append("       - \(p.name) : \(p.type) [\(p.code)]")
                    }
                }
            } else {
                out.append("  Classes: 0")
            }

            if !s.commands.isEmpty {
                out.append("  Commands (\(s.commands.count)):")
                for cmd in s.commands {
                    out.append("    • \(cmd.name) [\(cmd.code)]")
                    for pr in cmd.parameters {
                        out.append("       - \(pr.name) : \(pr.type) [\(pr.code)] optional=\(pr.optional ? "yes" : "no")")
                    }
                }
            } else {
                out.append("  Commands: 0")
            }
            out.append("") // blank line between suites
        }
        if out.isEmpty { out.append("No suites in document.") }
        return out.joined(separator: "\n")
    }
}
