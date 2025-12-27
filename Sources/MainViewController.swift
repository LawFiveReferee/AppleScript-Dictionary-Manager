import Cocoa

// MARK: - Outline items

private enum TreeItem {
    case suite(index: Int)
    case commandsHeader(suiteIndex: Int)
    case command(suiteIndex: Int, commandIndex: Int)
    case classesHeader(suiteIndex: Int)
    case sdefClass(suiteIndex: Int, classIndex: Int)
}

private final class Node {
    let item: TreeItem
    init(_ item: TreeItem) { self.item = item }
}

final class MainViewController: NSViewController,
                                NSSplitViewDelegate,
                                NSOutlineViewDataSource, NSOutlineViewDelegate {
    
    // Model
    private var currentModel = SDEFDocumentModel()
    
    // UI
    private let splitView = NSSplitView()
    private let outlineScroll = NSScrollView()
    private let outlineView = NSOutlineView()
    private let previewScroll = NSScrollView()
    private let previewTextView = NSTextView()
    
    private var positionedDividerOnce = false
    
    override func loadView() {
        self.view = NSView()
        
        // Split view: left | right
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.delegate = self
        view.addSubview(splitView)
        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // LEFT: Outline
        outlineView.headerView = nil
        outlineView.usesAlternatingRowBackgroundColors = true
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col"))
        col.title = "Items"
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col
        outlineView.dataSource = self
        outlineView.delegate = self
        
        outlineScroll.documentView = outlineView
        outlineScroll.hasVerticalScroller = true
        outlineScroll.translatesAutoresizingMaskIntoConstraints = false
        
        let left = NSView()
        left.translatesAutoresizingMaskIntoConstraints = false
        left.addSubview(outlineScroll)
        NSLayoutConstraint.activate([
            outlineScroll.leadingAnchor.constraint(equalTo: left.leadingAnchor),
            outlineScroll.trailingAnchor.constraint(equalTo: left.trailingAnchor),
            outlineScroll.topAnchor.constraint(equalTo: left.topAnchor),
            outlineScroll.bottomAnchor.constraint(equalTo: left.bottomAnchor)
        ])
        splitView.addArrangedSubview(left)
        left.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        
        // RIGHT: Preview
        previewTextView.frame = previewScroll.contentView.bounds
        previewTextView.autoresizingMask = [.width, .height]
        previewTextView.isEditable = false
        previewTextView.isSelectable = true
        previewTextView.isRichText = false
        previewTextView.usesFontPanel = false
        previewTextView.usesFindBar = true
        previewTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        previewTextView.textContainerInset = NSSize(width: 8, height: 8)
        previewTextView.isVerticallyResizable = true
        previewTextView.isHorizontallyResizable = true
        previewTextView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                              height: CGFloat.greatestFiniteMagnitude)
        previewTextView.textContainer?.widthTracksTextView = false
        
        previewScroll.documentView = previewTextView
        previewScroll.hasVerticalScroller = true
        previewScroll.translatesAutoresizingMaskIntoConstraints = false
        
        let right = NSView()
        right.translatesAutoresizingMaskIntoConstraints = false
        right.addSubview(previewScroll)
        NSLayoutConstraint.activate([
            previewScroll.leadingAnchor.constraint(equalTo: right.leadingAnchor),
            previewScroll.trailingAnchor.constraint(equalTo: right.trailingAnchor),
            previewScroll.topAnchor.constraint(equalTo: right.topAnchor),
            previewScroll.bottomAnchor.constraint(equalTo: right.bottomAnchor)
        ])
        splitView.addArrangedSubview(right)
        
        previewTextView.string = "🔧 Ready. Open an SDEF to preview."
        splitView.adjustSubviews()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        if !positionedDividerOnce, view.bounds.width > 0 {
            splitView.adjustSubviews()
            splitView.setPosition(max(280, view.bounds.width * 0.33), ofDividerAt: 0)
            positionedDividerOnce = true
        }
    }
    
    /// Called by SDEDocument after window is visible
    func forceInitialLayout() {
        view.layoutSubtreeIfNeeded()
        splitView.adjustSubviews()
        splitView.setPosition(max(280, view.bounds.width * 0.33), ofDividerAt: 0)
    }
    
    // MARK: - Public API from SDEDocument
    func load(model: SDEFDocumentModel) {
        self.currentModel = model
        outlineView.reloadData()
        
        // Expand all suites by default
        for i in 0..<currentModel.suites.count {
            outlineView.expandItem(Node(.suite(index: i)))
        }
        
        // Select first suite if available
        if currentModel.suites.count > 0 {
            outlineView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        updatePreview(for: selectedTreeItem())
    }
    
    // MARK: - Rendering
    private func updatePreview(for item: TreeItem?) {
        guard let item = item else {
            if currentModel.suites.isEmpty {
                previewTextView.string = "🔧 Ready. Open an SDEF to preview."
            } else {
                // whole document
                let data = SDEFWriter.makeXML(from: currentModel, title: "Dictionary")
                previewTextView.string = String(data: data, encoding: .utf8) ?? ""
            }
            return
        }
        
        switch item {
        case .suite(let s):
            let xml = SDEFWriter.xmlString(forSuite: currentModel.suites[s])
            previewTextView.string = xml
            
        case .commandsHeader(let s):
            let xml = SDEFWriter.xmlString(forCommands: currentModel.suites[s].commands,
                                           suiteName: currentModel.suites[s].name,
                                           suiteCode: currentModel.suites[s].code)
            previewTextView.string = xml
            
        case .command(let s, let c):
            let suite = currentModel.suites[s]
            let xml = SDEFWriter.xmlString(forCommand: suite.commands[c],
                                           suiteName: suite.name,
                                           suiteCode: suite.code)
            previewTextView.string = xml
            
        case .classesHeader(let s):
            let xml = SDEFWriter.xmlString(forClasses: currentModel.suites[s].classes,
                                           suiteName: currentModel.suites[s].name,
                                           suiteCode: currentModel.suites[s].code)
            previewTextView.string = xml
            
        case .sdefClass(let s, let k):
            let suite = currentModel.suites[s]
            let xml = SDEFWriter.xmlString(forClass: suite.classes[k],
                                           suiteName: suite.name,
                                           suiteCode: suite.code)
            previewTextView.string = xml
        }
    }
    
    // MARK: - NSSplitViewDelegate
    func splitView(_ splitView: NSSplitView,
                   constrainSplitPosition proposedPosition: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        max(240, proposedPosition)
    }
    
    // MARK: - Outline helpers
    private func item(at row: Int) -> TreeItem? {
        guard row >= 0 else { return nil }
        if let node = outlineView.item(atRow: row) as? Node { return node.item }
        return nil
    }
    private func selectedTreeItem() -> TreeItem? {
        item(at: outlineView.selectedRow)
    }
    
    // MARK: - NSOutlineViewDataSource
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let node = item as? Node else {
            return currentModel.suites.count
        }
        switch node.item {
        case .suite(let s):
            let suite = currentModel.suites[s]
            var count = 0
            if !suite.commands.isEmpty { count += 1 }
            if !suite.classes.isEmpty  { count += 1 }
            return count
        case .commandsHeader(let s):
            return currentModel.suites[s].commands.count
        case .classesHeader(let s):
            return currentModel.suites[s].classes.count
        case .command, .sdefClass:
            return 0
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? Node else { return false }
        switch node.item {
        case .suite(let s):
            let suite = currentModel.suites[s]
            return !suite.commands.isEmpty || !suite.classes.isEmpty
        case .commandsHeader, .classesHeader:
            return true
        case .command, .sdefClass:
            return false
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let node = item as? Node else {
            return Node(.suite(index: index))
        }
        switch node.item {
        case .suite(let s):
            let suite = currentModel.suites[s]
            var headers: [TreeItem] = []
            if !suite.commands.isEmpty { headers.append(.commandsHeader(suiteIndex: s)) }
            if !suite.classes.isEmpty  { headers.append(.classesHeader(suiteIndex: s)) }
            return Node(headers[index])
        case .commandsHeader(let s):
            return Node(.command(suiteIndex: s, commandIndex: index))
        case .classesHeader(let s):
            return Node(.sdefClass(suiteIndex: s, classIndex: index))
        case .command, .sdefClass:
            return Node(.suite(index: 0)) // unreachable
        }
    }
    
    // MARK: - NSOutlineViewDelegate
    func outlineView(_ outlineView: NSOutlineView,
                     viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell: NSTableCellView
        if let v = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            cell = v
        } else {
            cell = NSTableCellView()
            cell.identifier = id
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                tf.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -6),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        
        if let node = item as? Node {
            switch node.item {
            case .suite(let s):
                let suite = currentModel.suites[s]
                cell.textField?.stringValue = "\(suite.name) (\(suite.code))"
                cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            case .commandsHeader:
                cell.textField?.stringValue = "Commands"
                cell.textField?.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
            case .classesHeader:
                cell.textField?.stringValue = "Classes"
                cell.textField?.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
            case .command(let s, let c):
                let cmd = currentModel.suites[s].commands[c]
                cell.textField?.stringValue = "• \(cmd.name) (\(cmd.code))"
                cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
            case .sdefClass(let s, let k):
                let cls = currentModel.suites[s].classes[k]
                cell.textField?.stringValue = "• \(cls.name) (\(cls.code))"
                cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize)
            }
        } else {
            cell.textField?.stringValue = ""
        }
        return cell
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        updatePreview(for: selectedTreeItem())
    }
}
