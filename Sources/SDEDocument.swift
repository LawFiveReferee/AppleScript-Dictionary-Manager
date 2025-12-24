import Cocoa

final class SDEDocument: NSDocument {
    // Main-actor model the UI uses
    private(set) var model = SDEFDocumentModel()

    // Nonisolated buffer used by read/save (AppKit calls that are nonisolated)
    nonisolated(unsafe) private var parsedModelBuffer = SDEFDocumentModel()

    // AppKit overrides
    nonisolated override class var autosavesInPlace: Bool { true }
    override var windowNibName: NSNib.Name? { nil }

    nonisolated override class var readableTypes: [String] {
        ["com.apple.scripting-definition", "public.xml"]
    }
    nonisolated override class func isNativeType(_ type: String) -> Bool {
        type == "com.apple.scripting-definition" || type == "public.xml"
    }

    // Parse into the nonisolated buffer (do NOT touch `model` here)
    nonisolated override func read(from data: Data, ofType typeName: String) throws {
        do {
            parsedModelBuffer = try SDEFParser.parse(data: data)
        } catch {
            throw NSError(domain: "SDEDocument", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to parse SDEF: \(error.localizedDescription)"])
        }
    }

    // Build window on main; apply buffer to the UI model
    nonisolated override func makeWindowControllers() {
        Task { @MainActor in
            self.model = self.parsedModelBuffer

            let vc = MainViewController()
            vc.load(model: self.model)

            let win = NSWindow(contentViewController: vc)
            win.setContentSize(NSSize(width: 1000, height: 700))
            win.title = self.displayName ?? "Untitled"

            let wc = NSWindowController(window: win)
            self.addWindowController(wc)
            wc.showWindow(nil)
        }
    }

    // Save from the nonisolated buffer
    nonisolated override func data(ofType typeName: String) throws -> Data {
        SDEFWriter.makeXML(from: parsedModelBuffer, title: "Dictionary")
    }

    // Safe snapshot for export
    nonisolated func parsedModelSnapshot() -> SDEFDocumentModel { parsedModelBuffer }
}
