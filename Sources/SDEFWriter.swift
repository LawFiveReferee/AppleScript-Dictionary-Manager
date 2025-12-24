import Foundation

// NOTE: No @MainActor here.
struct SDEFWriter {
    static func makeXML(from model: SDEFDocumentModel, title: String = "Dictionary") -> Data {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE dictionary SYSTEM "file:///System/Library/DTDs/sdef.dtd">
        <dictionary title="\(esc(title))">
        """
        for s in model.suites {
            xml += "\n  <suite name=\"\(esc(s.name))\" code=\"\(esc(s.code))\">"
            for c in s.classes {
                xml += "\n    <class name=\"\(esc(c.name))\" code=\"\(esc(c.code))\">"
                for p in c.properties {
                    xml += "\n      <property name=\"\(esc(p.name))\" code=\"\(esc(p.code))\" type=\"\(esc(p.type))\"/>"
                }
                xml += "\n    </class>"
            }
            for cmd in s.commands {
                xml += "\n    <command name=\"\(esc(cmd.name))\" code=\"\(esc(cmd.code))\">"
                for pr in cmd.parameters {
                    let opt = pr.optional ? "yes" : "no"
                    xml += "\n      <parameter name=\"\(esc(pr.name))\" code=\"\(esc(pr.code))\" type=\"\(esc(pr.type))\" optional=\"\(opt)\"/>"
                }
                xml += "\n    </command>"
            }
            xml += "\n  </suite>"
        }
        xml += "\n</dictionary>\n"
        return Data(xml.utf8)
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
