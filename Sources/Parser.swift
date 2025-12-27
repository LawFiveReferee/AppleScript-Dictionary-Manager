import Foundation

// Namespace-agnostic SDEF parser that extracts suites, commands(+parameters), and classes(+properties)
final class SDEFParser {
    
    static func parse(data: Data) throws -> SDEFDocumentModel {
        // OLD:
        // guard let s = String(data: data, encoding: .utf8) else { ... }
        
        // NEW:
        let s = try decodeXMLData(data)
        
        var suites: [Suite] = []
        suites.reserveCapacity(8)
        
        // Start/end tags (support optional namespace prefix)
        let suiteStart = try! NSRegularExpression(pattern: #"(?is)<\s*(?:[A-Za-z0-9_]+\s*:)?suite\b([^>]*)>"#)
        let suiteEnd   = "</suite>"
        
        let cmdStart   = try! NSRegularExpression(pattern: #"(?is)<\s*(?:[A-Za-z0-9_]+\s*:)?command\b([^>]*)>"#)
        let cmdEnd     = "</command>"
        
        let clsStart   = try! NSRegularExpression(pattern: #"(?is)<\s*(?:[A-Za-z0-9_]+\s*:)?class\b([^>]*)>"#)
        let clsEnd     = "</class>"
        
        // Self-closing items
        let paramStart = try! NSRegularExpression(pattern: #"(?is)<\s*(?:[A-Za-z0-9_]+\s*:)?parameter\b([^>]*)/?>"#)
        let propStart  = try! NSRegularExpression(pattern: #"(?is)<\s*(?:[A-Za-z0-9_]+\s*:)?property\b([^>]*)/?>"#)
        
        // Attributes (accept " or ')
        let attrName    = try! NSRegularExpression(pattern: #"(?is)\bname\s*=\s*["']([^"']*)["']"#)
        let attrTitle   = try! NSRegularExpression(pattern: #"(?is)\btitle\s*=\s*["']([^"']*)["']"#)
        let attrCode    = try! NSRegularExpression(pattern: #"(?is)\bcode\s*=\s*["']([^"']*)["']"#)
        let attrCode2   = try! NSRegularExpression(pattern: #"(?is)\bcode-id\s*=\s*["']([^"']*)["']"#)
        let attrType    = try! NSRegularExpression(pattern: #"(?is)\btype\s*=\s*["']([^"']*)["']"#)
        let attrOptional = try! NSRegularExpression(pattern: #"(?is)\boptional\s*=\s*["']([^"']*)["']"#)
        
        // Enumerate suites
        suiteStart.enumerateMatches(in: s, range: NSRange(s.startIndex..., in: s)) { m, _, _ in
            guard let m = m, m.numberOfRanges >= 2,
                  let startRange = Range(m.range(at: 0), in: s),
                  let attrsRange  = Range(m.range(at: 1), in: s) else { return }
            
            let attrs = String(s[attrsRange])
            
            let suiteName = first(attrs, attrName) ?? first(attrs, attrTitle) ?? ""
            let suiteCode = first(attrs, attrCode) ?? first(attrs, attrCode2) ?? "XXXX"
            
            // locate end of start tag '>' then the closing tag
            guard let gtIdx = s[startRange].firstIndex(of: ">") else { return }
            let contentStart = s.index(startRange.lowerBound, offsetBy: s.distance(from: s[startRange].startIndex, to: gtIdx) + 1)
            guard let endTagRange = s.range(of: suiteEnd, range: contentStart..<s.endIndex) else { return }
            let suiteContent = String(s[contentStart..<endTagRange.lowerBound])
            
            // Commands
            var commands: [Command] = []
            enumerateBlocks(in: suiteContent, startTagRegex: cmdStart, endTagLiteral: cmdEnd) { headerAttrs, inner in
                let cName = first(headerAttrs, attrName) ?? first(headerAttrs, attrTitle) ?? "Untitled Command"
                let cCode = (first(headerAttrs, attrCode) ?? first(headerAttrs, attrCode2) ?? "XXXX")
                var params: [Parameter] = []
                paramStart.enumerateMatches(in: inner, range: NSRange(inner.startIndex..., in: inner)) { pm, _, _ in
                    guard let pm = pm, pm.numberOfRanges >= 2,
                          let ar = Range(pm.range(at: 1), in: inner) else { return }
                    let pa = String(inner[ar])
                    let pName = first(pa, attrName) ?? first(pa, attrTitle) ?? "param"
                    let pType = first(pa, attrType) ?? "anything"
                    let pCode = first(pa, attrCode) ?? first(pa, attrCode2) ?? "pXXX"
                    let pOpt  = first(pa, attrOptional)?.lowercased()
                    let isOpt = (pOpt == "yes" || pOpt == "true" || pOpt == "1")
                    params.append(Parameter(name: pName, code: pCode, type: pType, optional: isOpt))
                }
                commands.append(Command(name: cName, code: cCode, parameters: params))
            }
            
            // Classes
            var classes: [SDEFClass] = []
            enumerateBlocks(in: suiteContent, startTagRegex: clsStart, endTagLiteral: clsEnd) { headerAttrs, inner in
                let clName = first(headerAttrs, attrName) ?? first(headerAttrs, attrTitle) ?? "Untitled Class"
                let clCode = (first(headerAttrs, attrCode) ?? first(headerAttrs, attrCode2) ?? "XXXX")
                var props: [SDEFProperty] = []
                propStart.enumerateMatches(in: inner, range: NSRange(inner.startIndex..., in: inner)) { pm, _, _ in
                    guard let pm = pm, pm.numberOfRanges >= 2,
                          let ar = Range(pm.range(at: 1), in: inner) else { return }
                    let pa = String(inner[ar])
                    let prName = first(pa, attrName) ?? first(pa, attrTitle) ?? "property"
                    let prType = first(pa, attrType) ?? "anything"
                    let prCode = first(pa, attrCode) ?? first(pa, attrCode2) ?? "pXXX"
                    props.append(SDEFProperty(name: prName, code: prCode, type: prType))
                }
                classes.append(SDEFClass(name: clName, code: clCode, properties: props))
            }
            
            let cleanName = suiteName.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanCode = suiteCode.trimmingCharacters(in: .whitespacesAndNewlines)
            suites.append(Suite(name: cleanName.isEmpty ? "Untitled Suite" : cleanName,
                                code: String((cleanCode.isEmpty ? "XXXX" : cleanCode).prefix(4)),
                                commands: commands,
                                classes: classes))
        }
        
        var model = SDEFDocumentModel()
        model.suites = suites
        return model
    }
    
    private static func first(_ text: String, _ regex: NSRegularExpression) -> String? {
        guard let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
    
    /// Enumerate blocks like <command ...>...</command> or <class ...>...</class>
    private static func enumerateBlocks(in container: String,
                                        startTagRegex: NSRegularExpression,
                                        endTagLiteral: String,
                                        _ body: (_ headerAttributes: String, _ innerXML: String) -> Void) {
        let nsRange = NSRange(container.startIndex..., in: container)
        startTagRegex.enumerateMatches(in: container, range: nsRange) { m, _, _ in
            guard let m = m, m.numberOfRanges >= 2,
                  let whole = Range(m.range(at: 0), in: container),
                  let attrs = Range(m.range(at: 1), in: container) else { return }
            
            guard let gtIdx = container[whole].firstIndex(of: ">") else { return }
            let contentStart = container.index(whole.lowerBound,
                                               offsetBy: container.distance(from: container[whole].startIndex, to: gtIdx) + 1)
            guard let end = container.range(of: endTagLiteral, range: contentStart..<container.endIndex) else { return }
            let inner = String(container[contentStart..<end.lowerBound])
            let attrText = String(container[attrs])
            body(attrText, inner)
        }
    }
}
