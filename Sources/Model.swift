import Foundation

public struct SDEFDocumentModel {
    public var suites: [Suite] = []
    public init(suites: [Suite] = []) { self.suites = suites }
}

public struct Suite {
    public var name: String
    public var code: String
    public var commands: [Command] = []
    public var classes: [SDEFClass] = []
    public init(name: String, code: String, commands: [Command] = [], classes: [SDEFClass] = []) {
        self.name = name
        self.code = code
        self.commands = commands
        self.classes = classes
    }
}

public struct Command {
    public var name: String
    public var code: String
    public var parameters: [Parameter] = []
    public init(name: String, code: String, parameters: [Parameter] = []) {
        self.name = name
        self.code = code
        self.parameters = parameters
    }
}

public struct Parameter {
    public var name: String
    public var code: String
    public var type: String
    public var optional: Bool
    public init(name: String, code: String, type: String, optional: Bool) {
        self.name = name
        self.code = code
        self.type = type
        self.optional = optional
    }
}

public struct SDEFClass {
    public var name: String
    public var code: String
    public var properties: [SDEFProperty] = []
    public init(name: String, code: String, properties: [SDEFProperty] = []) {
        self.name = name
        self.code = code
        self.properties = properties
    }
}

public struct SDEFProperty {
    public var name: String
    public var code: String
    public var type: String
    public init(name: String, code: String, type: String) {
        self.name = name
        self.code = code
        self.type = type
    }
    // Selection model used by legacy preview code
    public enum SDESelection {
        case none
        case suite(index: Int)
        case command(suiteIndex: Int, commandIndex: Int)
        case sdefClass(suiteIndex: Int, classIndex: Int)
    }
    
    // Back-compat with files that reference `Selection`
    public typealias Selection = SDESelection
}
