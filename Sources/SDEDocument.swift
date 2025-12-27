import Cocoa

extension Notification.Name { static let SDEModelDidChange = Notification.Name("SDEModelDidChange") }

final class SDEDocument: NSDocument {
    
    private var model = SDEFDocumentModel()             // UI model (touch on main)
    private var parsedModelBuffer = SDEFDocumentModel() // IO buffer
    
    // MARK: Types
    nonisolated override class var autosavesInPlace: Bool { false }
    nonisolated override class var readableTypes: [String] { ["com.apple.scripting-definition", "public.xml"] }
    nonisolated override class func isNativeType(_ t: String) -> Bool { t == "com.apple.scripting-definition" || t == "public.xml" }
    nonisolated override func writableTypes(for _: NSDocument.SaveOperationType) -> [String] { ["com.apple.scripting-definition","public.xml"] }
    nonisolated override func fileNameExtension(forType t: String, saveOperation _: NSDocument.SaveOperationType) -> String? {
        switch t { case "com.apple.scripting-definition": return "sdef"
        case "public.xml":                     return "xml"
            default:                                return nil }
    }
    
    // MARK: IO (no AppKit)
    nonisolated override func read(from data: Data, ofType _: String) throws {
        parsedModelBuffer = try SDEFParser.parse(data: data)  // SDEFParser is not @MainActor
    }
    
    nonisolated override func data(ofType _: String) throws -> Data {
        SDEFWriter.makeXML(from: parsedModelBuffer, title: "Dictionary") // SDEFWriter is not @MainActor
    }
    
    // MARK: Window/UI

    nonisolated override func makeWindowControllers() {
        Task { @MainActor in
            // Publish the IO buffer to the UI model
            self.model = self.parsedModelBuffer
            
            // VC
            let vc = MainViewController()
            vc.load(model: self.model)
            
            // Compute a visible, non-tiny frame
            let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 1280, height: 800)
            let targetW = max(900, min(screen.width * 0.9, 1200))
            let targetH = max(600, min(screen.height * 0.9, 900))
            let rect = NSRect(
                x: screen.midX - targetW/2,
                y: screen.midY - targetH/2,
                width: targetW,
                height: targetH
            )
            
            // Window
            let win = NSWindow(contentRect: rect,
                               styleMask: [.titled, .closable, .resizable, .miniaturizable],
                               backing: .buffered,
                               defer: false)
            win.contentViewController = vc
            win.title = self.displayName ?? "Untitled"
            win.isReleasedWhenClosed = false
            win.minSize = NSSize(width: 600, height: 400)
            if win.responds(to: #selector(getter: NSWindow.tabbingMode)) {
                win.tabbingMode = .disallowed
            }
            // Avoid restoring some previously tiny frame
            win.isRestorable = false
            
            // Force the size BEFORE showing to avoid “title-bar only”
            win.setFrame(rect, display: true)
            
            // Show
            let wc = NSWindowController(window: win)
            self.addWindowController(wc)
            NSRunningApplication.current.activate(options: [.activateAllWindows])
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
            
            // Ensure split view gets a real width and positions its divider
            vc.forceInitialLayout()
        }
    }
    // For preview/export
    nonisolated func parsedModelSnapshot() -> SDEFDocumentModel { parsedModelBuffer }
    
    // Simple editing helper
    nonisolated func addSuite() {
        Task { @MainActor in
            var m = self.parsedModelBuffer
            m.suites.append(Suite(name: "New Suite", code: Self.randomFourChar()))
            self.parsedModelBuffer = m
            self.model = m
            NotificationCenter.default.post(name: .SDEModelDidChange, object: self)
        }
    }
    
    private static func randomFourChar() -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<4).map { _ in chars.randomElement()! })
    }
}
