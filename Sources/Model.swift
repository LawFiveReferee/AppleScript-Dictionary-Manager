import Foundation

struct SDEFDocumentModel {
    var suites: [Suite] = []

    static func sample() -> SDEFDocumentModel {
        var m = SDEFDocumentModel()
        m.suites = [
            Suite(name: "Standard Suite", code: "Core"),
            Suite(name: "My Suite", code: "MYSt")
        ]
        return m
    }
}

struct Suite {
    var name: String
    var code: String
    var classes: [ClassDef] = []
    var commands: [Command] = []
    init(name: String, code: String) { self.name = name; self.code = code }
}

struct ClassDef {
    var name: String
    var code: String
    var properties: [Property] = []
}

struct Command {
    var name: String
    var code: String
    var parameters: [Parameter] = []
}

struct Property {
    var name: String
    var code: String
    var type: String
}

struct Parameter {
    var name: String
    var code: String
    var type: String
    var optional: Bool
}

/// What the user selected in the outline
enum Selection {
    case suite(Suite)
    case classDef(ClassDef)
    case command(Command)
}
