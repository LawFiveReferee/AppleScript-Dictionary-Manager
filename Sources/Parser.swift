import Foundation

// Parses suites, classes, commands, properties, parameters from SDEF/XML.
// NOTE: No @MainActor here.
final class SDEFParser: NSObject, XMLParserDelegate {
    private var model = SDEFDocumentModel()
    private var currentSuite: Suite?
    private var currentClass: ClassDef?
    private var currentCommand: Command?

    static func parse(data: Data) throws -> SDEFDocumentModel {
        let delegate = SDEFParser()
        let xml = XMLParser(data: data)
        xml.delegate = delegate
        xml.shouldProcessNamespaces = false
        xml.shouldReportNamespacePrefixes = false
        xml.shouldResolveExternalEntities = false
        guard xml.parse() else {
            throw xml.parserError ?? NSError(
                domain: "SDEFParser", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unknown XML parse error"]
            )
        }
        return delegate.model
    }

    // MARK: XMLParserDelegate
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String : String] = [:]) {
        switch name {
        case "suite":
            currentSuite = Suite(name: attributes["name"] ?? "Suite",
                                 code: attributes["code"] ?? "????")
        case "class":
            currentClass = ClassDef(name: attributes["name"] ?? "class",
                                    code: attributes["code"] ?? "Clss")
        case "property":
            if var cls = currentClass {
                cls.properties.append(Property(name: attributes["name"] ?? "property",
                                               code: attributes["code"] ?? "prop",
                                               type: attributes["type"] ?? "any"))
                currentClass = cls
            }
        case "command":
            currentCommand = Command(name: attributes["name"] ?? "command",
                                     code: attributes["code"] ?? "cmnd")
        case "parameter":
            if var cmd = currentCommand {
                let opt = (attributes["optional"]?.lowercased() == "yes")
                cmd.parameters.append(Parameter(name: attributes["name"] ?? "parameter",
                                                code: attributes["code"] ?? "parm",
                                                type: attributes["type"] ?? "any",
                                                optional: opt))
                currentCommand = cmd
            }
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch name {
        case "class":
            if let cls = currentClass, var suite = currentSuite {
                suite.classes.append(cls); currentSuite = suite; currentClass = nil
            }
        case "command":
            if let cmd = currentCommand, var suite = currentSuite {
                suite.commands.append(cmd); currentSuite = suite; currentCommand = nil
            }
        case "suite":
            if let suite = currentSuite { model.suites.append(suite); currentSuite = nil }
        default: break
        }
    }
}
