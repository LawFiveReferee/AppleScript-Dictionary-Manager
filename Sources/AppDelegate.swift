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

        let openBundle = NSMenuItem(title: "Open App Bundle…", action: #selector(openFromAppBundle(_:)), keyEquivalent: "")
        openBundle.target = self
        file.addItem(openBundle)

        let openOSAX = NSMenuItem(title: "Open Scripting Addition…", action: #selector(openFromScriptingAddition(_:)), keyEquivalent: "")
        openOSAX.target = self
        file.addItem(openOSAX)

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

        let exportPDF = NSMenuItem(title: "Export Preview as PDF…", action: #selector(exportPreviewPDF(_:)), keyEquivalent: "p")
        exportPDF.keyEquivalentModifierMask = [.command, .option]
        exportPDF.target = self
        file.addItem(exportPDF)

        let revealItem = NSMenuItem(title: "Reveal App Documents…", action: #selector(revealAppDocuments(_:)), keyEquivalent: "")
        revealItem.target = self
        file.addItem(revealItem)

        fileItem.submenu = file

        // Edit
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z")
        let redo = NSMenuItem(title: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(redo)
        edit.addItem(NSMenuItem.separator())
        let addSuite = NSMenuItem(title: "Add Suite", action: #selector(addSuite(_:)), keyEquivalent: "+")
        addSuite.target = self
        edit.addItem(addSuite)
        editItem.submenu = edit

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

    // MARK: - Validation
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(newDocument(_:)), #selector(openDocument(_:)), #selector(openFromAppBundle(_:)), #selector(openFromScriptingAddition(_:)), #selector(revealAppDocuments(_:)):
            return true
        case #selector(exportSDEF(_:)), #selector(exportPreviewPDF(_:)), #selector(addSuite(_:)):
            return (NSDocumentController.shared.currentDocument as? SDEDocument) != nil
        default:
            return true
        }
    }

    // MARK: - Actions
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
        
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        // Let NSDocumentController drive read + window creation
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { doc, wasOpen, err in
            if let err = err {
                let a = NSAlert(); a.messageText = "Could not open file"
                a.informativeText = err.localizedDescription
                a.alertStyle = .warning; a.runModal()
                return
            }
            guard let doc = doc as? SDEDocument else { return }
            // Make sure the window is visible and frontmost
            if let win = doc.windowControllers.first?.window {
                NSApp.activate(ignoringOtherApps: true)
                win.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    
    @objc func openFromAppBundle(_ sender: Any?) {
        if !Thread.isMainThread { return DispatchQueue.main.async { self.openFromAppBundle(sender) } }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [.applicationBundle]
        } else {
            panel.allowedFileTypes = ["app"]
        }
        guard panel.runModal() == .OK, let appURL = panel.url else { return }
        let sdefURL = findSDEF(in: appURL)
        if let sdef = sdefURL { openSDEF(at: sdef) } else {
            let a = NSAlert(); a.messageText = "No SDEF found"
            a.informativeText = "No *.sdef file was found in \(appURL.lastPathComponent)/Contents/Resources."
            a.alertStyle = .informational; a.runModal()
        }
    }

    @objc func openFromScriptingAddition(_ sender: Any?) {
        if !Thread.isMainThread { return DispatchQueue.main.async { self.openFromScriptingAddition(sender) } }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true
        if #available(macOS 12.0, *) {
            let osax = UTType(filenameExtension: "osax")
            panel.allowedContentTypes = [osax].compactMap { $0 }
        } else {
            panel.allowedFileTypes = ["osax"]
        }
        guard panel.runModal() == .OK, let osaxURL = panel.url else { return }
        let sdefURL = findSDEF(in: osaxURL)
        if let sdef = sdefURL { openSDEF(at: sdef) } else {
            let a = NSAlert(); a.messageText = "No SDEF found"
            a.informativeText = "No *.sdef file was found in \(osaxURL.lastPathComponent)/Contents/Resources."
            a.alertStyle = .informational; a.runModal()
        }
    }

    private func findSDEF(in bundleURL: URL) -> URL? {
        let resources = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let fm = FileManager.default
        guard let list = try? fm.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return nil }
        return list.first { $0.pathExtension.lowercased() == "sdef" }
    }

    private func openSDEF(at url: URL) {
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

    @objc func exportSDEF(_ sender: Any?) {
        if !Thread.isMainThread { return DispatchQueue.main.async { self.exportSDEF(sender) } }
        guard let doc = NSDocumentController.shared.currentDocument as? SDEDocument else { return }

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

        if let window = doc.windowControllers.first?.window {
            save.beginSheetModal(for: window) { resp in
                guard resp == .OK, let url = save.url else { return }
                do {
                    let data = SDEFWriter.makeXML(from: doc.parsedModelSnapshot(), title: doc.displayName ?? "Dictionary")
                    try data.write(to: url, options: .atomic)
                } catch { self.present(error) }
            }
        } else if save.runModal() == .OK, let url = save.url {
            do {
                let data = SDEFWriter.makeXML(from: doc.parsedModelSnapshot(), title: doc.displayName ?? "Dictionary")
                try data.write(to: url, options: .atomic)
            } catch { present(error) }
        }
    }

    @objc func exportPreviewPDF(_ sender: Any?) {
        if !Thread.isMainThread { return DispatchQueue.main.async { self.exportPreviewPDF(sender) } }
        guard let doc = NSDocumentController.shared.currentDocument as? SDEDocument else { return }

        let save = NSSavePanel()
        if #available(macOS 12.0, *) {
            save.allowedContentTypes = [.pdf]
        } else {
            save.allowedFileTypes = ["pdf"]
        }
        save.nameFieldStringValue = (doc.displayName ?? "Dictionary") + ".pdf"

        let writePDF: (URL) -> Void = { url in
            let text = PreviewTextBuilder.makeText(from: doc.parsedModelSnapshot())
            let page = NSRect(x: 0, y: 0, width: 612, height: 792)
            let tv = NSTextView(frame: page)
            tv.isEditable = false
            tv.string = text
            let data = tv.dataWithPDF(inside: tv.bounds)
            do { try data.write(to: url) } catch { self.present(error) }
        }

        if let win = NSApp.keyWindow {
            save.beginSheetModal(for: win) { resp in
                guard resp == .OK, let url = save.url else { return }
                writePDF(url)
            }
        } else if save.runModal() == .OK, let url = save.url {
            writePDF(url)
        }
    }

    @objc func addSuite(_ sender: Any?) {
        if !Thread.isMainThread { return DispatchQueue.main.async { self.addSuite(sender) } }
        (NSDocumentController.shared.currentDocument as? SDEDocument)?.addSuite()
    }

    @objc func revealAppDocuments(_ sender: Any?) {
        if !Thread.isMainThread { return DispatchQueue.main.async { self.revealAppDocuments(sender) } }
        do {
            let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            NSWorkspace.shared.activateFileViewerSelecting([docs])
        } catch { present(error) }
    }

    private func present(_ error: Error) {
        let a = NSAlert(); a.messageText = "Operation failed"
        a.informativeText = error.localizedDescription
        a.alertStyle = .warning; a.runModal()
    }
}
