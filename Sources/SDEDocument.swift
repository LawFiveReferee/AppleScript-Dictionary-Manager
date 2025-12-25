import Cocoa

// Notify views to refresh when the in-memory model changes
extension Notification.Name {
    static let SDEModelDidChange = Notification.Name("SDEModelDidChange")
}

final class SDEDocument: NSDocument {
    
    // UI model (mutate on main only)
    private var model = SDEFDocumentModel()
    
    // Buffer used by read()/save()
    private var parsedModelBuffer = SDEFDocumentModel()
    
    // MARK: - NSDocument type configuration (must be nonisolated)
    override class var autosavesInPlace: Bool { false }
    
    override class var readableTypes: [String] {
        ["com.apple.scripting-definition", "public.xml"]
    }
    
    override class func isNativeType(_ type: String) -> Bool {
        type == "com.apple.scripting-definition" || type == "public.xml"
    }
    
    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        ["com.apple.scripting-definition", "public.xml"]
    }
    
    override func fileNameExtension(forType typeName: String,
                                    saveOperation: NSDocument.SaveOperationType) -> String? {
        switch typeName {
        case "com.apple.scripting-definition": return "sdef"
        case "public.xml":                     return "xml"
        default:                               return nil
        }
    }
    
    // MARK: - Reading / Writing (no AppKit here; avoid main-actor props)
    override func read(from data: Data, ofType typeName: String) throws {
        parsedModelBuffer = try SDEFParser.parse(data: data)   // ensure SDEFParser is NOT @MainActor
    }
    
    override func data(ofType typeName: String) throws -> Data {
        // Don’t touch NSDocument.displayName here (may be main-actor)
        return SDEFWriter.makeXML(from: parsedModelBuffer, title: "Dictionary")
    }
    
    // MARK: - Window / UI (do AppKit work on main)
    override func makeWindowControllers() {
        let buildUI = {
            // publish buffer to UI model
            self.model = self.parsedModelBuffer
            
            let vc = MainViewController()
            vc.load(model: self.model)
            
            let rect = NSRect(x: 0, y: 0, width: 1000, height: 700)
            let win = NSWindow(contentRect: rect,
                               styleMask: [.titled, .closable, .resizable, .miniaturizable],
                               backing: .buffered,
                               defer: false)
            win.contentViewController = vc
            win.title = self.displayName ?? "Untitled"
            
            let wc = NSWindowController(window: win)
            self.addWindowController(wc)
            
            NSApp.activate(ignoringOtherApps: true)
            win.center()
            win.makeKeyAndOrderFront(nil)
            
            NotificationCenter.default.post(name: .SDEModelDidChange, object: self)
        }
        
        if Thread.isMainThread { buildUI() } else { DispatchQueue.main.sync(execute: buildUI) }
    }
    
    // Snapshot for preview/export
    func parsedModelSnapshot() -> SDEFDocumentModel { parsedModelBuffer }
    
    // MARK: - Simple editing helper
    func addSuite() {
        let edit = {
            self.model.suites.append(Suite(name: "New Suite", code: Self.randomFourChar()))
            self.parsedModelBuffer = self.model
            NotificationCenter.default.post(name: .SDEModelDidChange, object: self)
        }
        if Thread.isMainThread { edit() } else { DispatchQueue.main.async(execute: edit) }
    }
    
    private static func randomFourChar() -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<4).map { _ in chars.randomElement()! })
    }
}
