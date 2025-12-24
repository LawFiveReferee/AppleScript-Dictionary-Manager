import Cocoa
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    // MARK: - Menu
    private func buildMainMenu() {
        let main = NSMenu()

        // App
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        // File
        let fileItem = NSMenuItem(); main.addItem(fileItem)
        let file = NSMenu(title: "File")

        let newItem  = NSMenuItem(title: "New",   action: #selector(newDocument(_:)),  keyEquivalent: "n"); newItem.target = self
        let openItem = NSMenuItem(title: "Open…", action: #selector(openDocument(_:)), keyEquivalent: "o"); openItem.target = self
        file.addItem(newItem)
        file.addItem(openItem)
        file.addItem(NSMenuItem.separator())
        file.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        file.addItem(NSMenuItem(title: "Save…", action: #selector(NSDocument.save(_:)), keyEquivalent: "s"))
        let saveAs = NSMenuItem(title: "Save As…", action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        file.addItem(saveAs)

        let exportItem = NSMenuItem(title: "Export SDEF…", action: #selector(exportSDEF(_:)), keyEquivalent: "e")
        exportItem.keyEquivalentModifierMask = [.command, .shift]
        exportItem.target = self
        file.addItem(exportItem)

        // Optional helper: reveal the app's sandbox Documents (where debug exports go)
        let revealItem = NSMenuItem(title: "Reveal App Documents…", action: #selector(revealAppDocuments(_:)), keyEquivalent: "")
        revealItem.target = self
        file.addItem(revealItem)

        fileItem.submenu = file

        // Window
        let windowItem = NSMenuItem(); main.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
        windowItem.submenu = windowMenu

        // Help
        let helpItem = NSMenuItem(); main.addItem(helpItem)
        helpItem.submenu = NSMenu(title: "Help")

        NSApp.mainMenu = main
    }

    // MARK: - Menu validation
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(newDocument(_:)), #selector(openDocument(_:)), #selector(revealAppDocuments(_:)):
            return true
        case #selector(exportSDEF(_:)):
            return (NSDocumentController.shared.currentDocument as? SDEDocument) != nil
        default:
            return true
        }
    }

    // MARK: - Actions (force main thread for AppKit)
    @objc func newDocument(_ sender: Any?) {
        if !Thread.isMainThread { return DispatchQueue.main.async { self.newDocument(sender) } }
        let doc = SDEDocument()
        NSDocumentController.shared.addDocument(doc)
        doc.makeWindowControllers()
        doc.showWindows()
    }

    @objc func openDocument(_ sender: Any?) {
        if !Thread.isMainThread { return DispatchQueue.main.async { self.openDocument(sender) } }

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

    @objc func exportSDEF(_ sender: Any?) {
        if !Thread.isMainThread { return DispatchQueue.main.async { self.exportSDEF(sender) } }

        guard let doc = NSDocumentController.shared.currentDocument as? SDEDocument else {
            let a = NSAlert(); a.messageText = "No document is active"
            a.informativeText = "Open a .sdef or create a new document first."
            a.alertStyle = .warning; a.runModal(); return
        }

        let save = NSSavePanel()
        save.canCreateDirectories = true
        if let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            save.directoryURL = desktop
        }
        save.nameFieldStringValue = (doc.displayName ?? "Dictionary") + ".sdef"
        if #available(macOS 12.0, *) {
            let sdef = UTType(filenameExtension: "sdef")
            save.allowedContentTypes = [sdef, .xml].compactMap { $0 }
        } else {
            save.allowedFileTypes = ["sdef", "xml"]
        }

        func write(to url: URL) {
            do {
                let data = SDEFWriter.makeXML(from: doc.parsedModelSnapshot(), title: doc.displayName ?? "Dictionary")
                try data.write(to: url, options: .atomic)
            } catch {
                let a = NSAlert(); a.messageText = "Export failed"
                a.informativeText = error.localizedDescription
                a.alertStyle = .warning; a.runModal()
            }
        }

        if let window = doc.windowControllers.first?.window {
            save.beginSheetModal(for: window) { resp in
                guard resp == .OK, let url = save.url else { return }
                write(to: url)
            }
        } else if save.runModal() == .OK, let url = save.url {
            write(to: url)
        }
    }

    @objc func revealAppDocuments(_ sender: Any?) {
        if !Thread.isMainThread { return DispatchQueue.main.async { self.revealAppDocuments(sender) } }
        do {
            let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            NSWorkspace.shared.activateFileViewerSelecting([docs])
        } catch {
            let a = NSAlert(); a.messageText = "Could not reveal folder"
            a.informativeText = error.localizedDescription
            a.alertStyle = .warning; a.runModal()
        }
    }
}
