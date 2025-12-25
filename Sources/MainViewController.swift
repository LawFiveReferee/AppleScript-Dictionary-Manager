import Cocoa

// Adjust protocol conformance if you already have custom delegates
final class MainViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {

    // MARK: - State
    private var model = SDEFDocumentModel()

    // MARK: - Views
    private let splitView = NSSplitView()
    private let leftScroll = NSScrollView()
    private let rightScroll = NSScrollView()
    private let outlineView = NSOutlineView()
    private let outlineColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    private let previewTextView = NSTextView()

    // MARK: - Lifecycle
    override func loadView() {
        self.view = NSView()
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(modelDidChange(_:)),
                                               name: .SDEModelDidChange,
                                               object: nil)
    }

    // Called by SDEDocument.makeWindowControllers()
    func load(model: SDEFDocumentModel) {
        self.model = model
        outlineView.reloadData()
        refreshPreview()
    }

    @objc private func modelDidChange(_ note: Notification) {
        if let doc = NSDocumentController.shared.currentDocument as? SDEDocument {
            self.model = doc.parsedModelSnapshot()
        }
        outlineView.reloadData()
        refreshPreview()
    }

    // MARK: - UI setup
    private func setupUI() {
        splitView.dividerStyle = .thin
        splitView.isVertical = true
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)
        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // LEFT: outline
        outlineColumn.title = "Dictionary"
        outlineView.addTableColumn(outlineColumn)
        outlineView.outlineTableColumn = outlineColumn
        outlineView.headerView = nil
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.rowSizeStyle = .default
        leftScroll.documentView = outlineView
        leftScroll.hasVerticalScroller = true
        leftScroll.translatesAutoresizingMaskIntoConstraints = false

        // RIGHT: preview
        previewTextView.isEditable = false
        previewTextView.isRichText = false
        previewTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        previewTextView.textContainer?.lineFragmentPadding = 8
        rightScroll.documentView = previewTextView
        rightScroll.hasVerticalScroller = true
        rightScroll.translatesAutoresizingMaskIntoConstraints = false

        // Containers for split subviews
        let leftContainer = NSView()
        let rightContainer = NSView()
        leftContainer.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.translatesAutoresizingMaskIntoConstraints = false

        leftContainer.addSubview(leftScroll)
        rightContainer.addSubview(rightScroll)

        leftScroll.frame = leftContainer.bounds
        leftScroll.autoresizingMask = [.width, .height]
        rightScroll.frame = rightContainer.bounds
        rightScroll.autoresizingMask = [.width, .height]

        splitView.addArrangedSubview(leftContainer)
        splitView.addArrangedSubview(rightContainer)
        splitView.setPosition(300, ofDividerAt: 0)
    }

    private func refreshPreview() {
        previewTextView.string = PreviewTextBuilder.makeText(from: model)
    }

    // MARK: - Outline data source
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return model.suites.count }
        if let suite = item as? Suite {
            return suite.classes.count + suite.commands.count
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let suite = item as? Suite {
            return (suite.classes.count + suite.commands.count) > 0
        }
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let suite = item as? Suite {
            let clsCount = suite.classes.count
            if index < clsCount { return suite.classes[index] }
            return suite.commands[index - clsCount]
        }
        return model.suites[index]
    }

    func outlineView(_ outlineView: NSOutlineView,
                     viewFor tableColumn: NSTableColumn?,
                     item: Any) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView ?? {
            let v = NSTableCellView()
            v.identifier = id
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            v.addSubview(tf)
            v.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            ])
            return v
        }()

        if let suite = item as? Suite {
            cell.textField?.stringValue = "Suite: \(suite.name) [\(suite.code)]"
        } else if let cls = item as? ClassDef {
            cell.textField?.stringValue = "Class: \(cls.name) [\(cls.code)]"
        } else if let cmd = item as? Command {
            cell.textField?.stringValue = "Command: \(cmd.name) [\(cmd.code)]"
        } else {
            cell.textField?.stringValue = "\(item)"
        }
        return cell
    }
   
}
