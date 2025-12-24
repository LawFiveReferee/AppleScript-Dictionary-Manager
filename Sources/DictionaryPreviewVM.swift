import Foundation
import Combine

final class DictionaryPreviewVM: ObservableObject {
    @Published var title: String = "No selection"
    @Published var details: String = "Select an item on the left"

    func load(selection: Selection?) {
        guard let sel = selection else {
            title = "No selection"
            details = "Select an item on the left"
            return
        }
        switch sel {
        case .suite(let s):
            let clsList = s.classes.map { "• \($0.name) (\($0.code))" }.joined(separator: "\n")
            let cmdList = s.commands.map { "• \($0.name) (\($0.code))" }.joined(separator: "\n")
            title = s.name
            details = """
            Code: \(s.code)

            Classes (\(s.classes.count)):
            \(clsList.isEmpty ? "—" : clsList)

            Commands (\(s.commands.count)):
            \(cmdList.isEmpty ? "—" : cmdList)
            """

        case .classDef(let c):
            let props = c.properties.map { "• \($0.name): \($0.type) (\($0.code))" }.joined(separator: "\n")
            title = "Class \(c.name)"
            details = """
            Code: \(c.code)

            Properties (\(c.properties.count)):
            \(props.isEmpty ? "—" : props)
            """

        case .command(let c):
            let params = c.parameters.map { p in
                let opt = p.optional ? " (optional)" : ""
                return "• \(p.name): \(p.type)\(opt) (\(p.code))"
            }.joined(separator: "\n")
            title = "Command \(c.name)"
            details = """
            Code: \(c.code)

            Parameters (\(c.parameters.count)):
            \(params.isEmpty ? "—" : params)
            """
        }
    }
}
