import Cocoa
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
    }

    // Prevent “Cannot create document” alert on launch
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    // MARK: - Menu building
    private func buildMainMenu() {
        let mainMenu = NSMenu()

        // App
        let appItem = NSMenuItem(); mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        // File
        let fileItem = NSMenuItem(); mainMenu.addItem(fileItem)
        let file = NSMenu(title: "File")

        let newItem = NSMenuItem(title: "New", action: #selector(newDocument(_:)), keyEquivalent: "n")
        newItem.target = self; file.addItem(newItem)

        let openItem = NSMenuItem(title: "Open…", action: #selector(openDocument(_:)), keyEquivalent: "o")
        openItem.target = self; file.addItem(openItem)

        file.addItem(NSMenuItem.separator())
        file.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))

        let saveItem = NSMenuItem(title: "Save…", action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
        file.addItem(saveItem)
        let saveAs = NSMenuItem(title: "Save As…", action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        file.addItem(saveAs)

        let exportItem = NSMenuItem(title: "Export SDEF…", action: #selector(exportSDEF(_:)), keyEquivalent: "e")
        exportItem.keyEquivalentModifierMask = [.command, .shift]
        exportItem.target = self
        file.addItem(exportItem)

        fileItem.submenu = file

        // Window
        let windowItem = NSMenuItem(); mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
        windowItem.submenu = windowMenu

        // Help
        let helpItem = NSMenuItem(); mainMenu.addItem(helpItem)
        helpItem.submenu = NSMenu(title: "Help")

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu validation
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(newDocument(_:)), #selector(openDocument(_:)):
            return true
        case #selector(exportSDEF(_:)):
            return (NSDocumentController.shared.currentDocument as? SDEDocument) != nil
        default:
            return true
        }
    }

    // MARK: - Actions (AppKit on main)
    @MainActor @objc func newDocument(_ sender: Any?) {
        let doc = SDEDocument()
        NSDocumentController.shared.addDocument(doc)
        doc.makeWindowControllers()
        doc.showWindows()
    }

    @MainActor @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false

        if #available(macOS 12.0, *) {
            let sdef = UTType(filenameExtension: "sdef")
            panel.allowedContentTypes = [sdef, .xml].compactMap { $0 }
        } else {
            panel.allowedFileTypes = ["sdef", "xml"]
        }

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let typeName = (url.pathExtension.lowercased() == "xml") ? "public.xml" : "com.apple.scripting-definition"
                let doc = SDEDocument()
                try doc.read(from: data, ofType: typeName)
                NSDocumentController.shared.addDocument(doc)
                doc.makeWindowControllers()
                doc.windowControllers.first?.window?.title = url.lastPathComponent
                doc.showWindows()
            } catch {
                let a = NSAlert(); a.messageText = "Could not open file"
                a.informativeText = error.localizedDescription
                a.alertStyle = .warning; a.runModal()
            }
        }
    }

    @MainActor @objc func exportSDEF(_ sender: Any?) {
        guard let doc = NSDocumentController.shared.currentDocument as? SDEDocument else {
            let a = NSAlert(); a.messageText = "No document is active"
            a.informativeText = "Open a .sdef or create a new document first."
            a.alertStyle = .warning; a.runModal(); return
        }

        let save = NSSavePanel()
        save.canCreateDirectories = true
        if #available(macOS 12.0, *) {
            let sdef = UTType(filenameExtension: "sdef")
            save.allowedContentTypes = [sdef, .xml].compactMap { $0 }
        } else {
            save.allowedFileTypes = ["sdef", "xml"]
        }
        save.nameFieldStringValue = (doc.displayName ?? "Dictionary") + ".sdef"

        if let window = doc.windowControllers.first?.window {
            save.beginSheetModal(for: window) { response in
                guard response == .OK, let url = save.url else { return }
                do {
                    let data = SDEFWriter.makeXML(from: doc.parsedModelSnapshot(), title: doc.displayName ?? "Dictionary")
                    try data.write(to: url)
                } catch {
                    let a = NSAlert(); a.messageText = "Export failed"
                    a.informativeText = error.localizedDescription
                    a.alertStyle = .warning; a.runModal()
                }
            }
        } else {
            if save.runModal() == .OK, let url = save.url {
                do {
                    let data = SDEFWriter.makeXML(from: doc.parsedModelSnapshot(), title: doc.displayName ?? "Dictionary")
                    try data.write(to: url)
                } catch {
                    let a = NSAlert(); a.messageText = "Export failed"
                    a.informativeText = error.localizedDescription
                    a.alertStyle = .warning; a.runModal()
                }
            }
        }
    }
}
