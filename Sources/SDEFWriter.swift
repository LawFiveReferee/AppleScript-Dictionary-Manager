import Foundation

enum SDEFWriter {
    static func makeXML(from model: SDEFDocumentModel, title: String) -> Data {
        var out = header()
        for suite in model.suites { out += suiteXML(suite) }
        out += footer()
        return out.data(using: .utf8) ?? Data()
    }
    
    // Context helpers
    static func xmlString(forSuite suite: Suite) -> String {
        header() + suiteXML(suite) + footer()
    }
    
    static func xmlString(forCommand command: Command, suiteName: String, suiteCode: String) -> String {
        var out = header()
        out += "  <suite name=\"\(x(suiteName))\" code=\"\(x(suiteCode))\">\n"
        out += commandXML(command, indent: "    ")
        out += "  </suite>\n"
        out += footer()
        return out
    }
    
    static func xmlString(forCommands commands: [Command], suiteName: String, suiteCode: String) -> String {
        var out = header()
        out += "  <suite name=\"\(x(suiteName))\" code=\"\(x(suiteCode))\">\n"
        for c in commands { out += commandXML(c, indent: "    ") }
        out += "  </suite>\n"
        out += footer()
        return out
    }
    
    static func xmlString(forClass cls: SDEFClass, suiteName: String, suiteCode: String) -> String {
        var out = header()
        out += "  <suite name=\"\(x(suiteName))\" code=\"\(x(suiteCode))\">\n"
        out += classXML(cls, indent: "    ")
        out += "  </suite>\n"
        out += footer()
        return out
    }
    
    static func xmlString(forClasses classes: [SDEFClass], suiteName: String, suiteCode: String) -> String {
        var out = header()
        out += "  <suite name=\"\(x(suiteName))\" code=\"\(x(suiteCode))\">\n"
        for c in classes { out += classXML(c, indent: "    ") }
        out += "  </suite>\n"
        out += footer()
        return out
    }
    
    // MARK: - Internals
    
    private static func header() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE dictionary SYSTEM "file://localhost/System/Library/DTDs/sdef.dtd">
        <dictionary>
        
        """
    }
    
    private static func footer() -> String {
        "</dictionary>\n"
    }
    
    private static func suiteXML(_ suite: Suite) -> String {
        var s = "  <suite name=\"\(x(suite.name))\" code=\"\(x(suite.code))\">\n"
        for c in suite.commands { s += commandXML(c, indent: "    ") }
        for cl in suite.classes { s += classXML(cl, indent: "    ") }
        s += "  </suite>\n"
        return s
    }
    
    private static func commandXML(_ cmd: Command, indent: String) -> String {
        var s = "\(indent)<command name=\"\(x(cmd.name))\" code=\"\(x(cmd.code))\">\n"
        for p in cmd.parameters {
            let opt = p.optional ? " optional=\"yes\"" : ""
            s += "\(indent)  <parameter name=\"\(x(p.name))\" code=\"\(x(p.code))\" type=\"\(x(p.type))\"\(opt)/>\n"
        }
        s += "\(indent)</command>\n"
        return s
    }
    
    private static func classXML(_ c: SDEFClass, indent: String) -> String {
        var s = "\(indent)<class name=\"\(x(c.name))\" code=\"\(x(c.code))\">\n"
        for pr in c.properties {
            s += "\(indent)  <property name=\"\(x(pr.name))\" code=\"\(x(pr.code))\" type=\"\(x(pr.type))\"/>\n"
        }
        s += "\(indent)</class>\n"
        return s
    }
    
    private static func x(_ s: String) -> String {
        var r = s
        r = r.replacingOccurrences(of: "&", with: "&amp;")
        r = r.replacingOccurrences(of: "\"", with: "&quot;")
        r = r.replacingOccurrences(of: "'", with: "&apos;")
        r = r.replacingOccurrences(of: "<", with: "&lt;")
        r = r.replacingOccurrences(of: ">", with: "&gt;")
        return r
    }
}
