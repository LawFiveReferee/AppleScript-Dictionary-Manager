import Cocoa

private enum OutlineItem {
    case suite(Int)                         // index into model.suites
    case groupClasses(Int)                  // group row under suite
    case groupCommands(Int)                 // group row under suite
    case classItem(suite: Int, idx: Int)
    case commandItem(suite: Int, idx: Int)
}

final class DictionaryOutlineViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate {

    var model: SDEFDocumentModel = .sample() { didSet { outlineView.reloadData() } }
    var onSelect: ((Selection?) -> Void)?

    private let outlineView = NSOutlineView()
    private let scroll = NSScrollView()

    override func loadView() {
        scroll.autohidesScrollers = true
        scroll.hasVerticalScroller = true

        let column = NSTableColumn(identifier: .init("name"))
        column.title = "Dictionary"
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.style = .sourceList
        outlineView.floatsGroupRows = false

        scroll.documentView = outlineView
        self.view = scroll
    }

    // MARK: - DataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let item = item as? OutlineItem else {
            return model.suites.count
        }
        switch item {
        case .suite(let sIdx):
            let s = model.suites[sIdx]
            var groups = 0
            if !s.classes.isEmpty { groups += 1 }
            if !s.commands.isEmpty { groups += 1 }
            return groups
        case .groupClasses(let sIdx):
            return model.suites[sIdx].classes.count
        case .groupCommands(let sIdx):
            return model.suites[sIdx].commands.count
        default:
            return 0
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let item = item as? OutlineItem else { return false }
        switch item {
        case .suite(let sIdx):
            let s = model.suites[sIdx]
            return (!s.classes.isEmpty || !s.commands.isEmpty)
        case .groupClasses(let sIdx):
            return !model.suites[sIdx].classes.isEmpty
        case .groupCommands(let sIdx):
            return !model.suites[sIdx].commands.isEmpty
        default:
            return false
        }
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let item = item as? OutlineItem else {
            return OutlineItem.suite(index)
        }
        switch item {
        case .suite(let sIdx):
            let s = model.suites[sIdx]
            let hasClasses = !s.classes.isEmpty
            let hasCommands = !s.commands.isEmpty
            if hasClasses && hasCommands {
                return index == 0 ? OutlineItem.groupClasses(sIdx) : OutlineItem.groupCommands(sIdx)
            } else if hasClasses {
                return OutlineItem.groupClasses(sIdx)
            } else {
                return OutlineItem.groupCommands(sIdx)
            }

        case .groupClasses(let sIdx):
            return OutlineItem.classItem(suite: sIdx, idx: index)

        case .groupCommands(let sIdx):
            return OutlineItem.commandItem(suite: sIdx, idx: index)

        default:
            return 0
        }
    }

    // MARK: - Group styling

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        guard let it = item as? OutlineItem else { return false }
        switch it {
        case .groupClasses, .groupCommands: return true
        default: return false
        }
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        guard let it = item as? OutlineItem else { return true }
        switch it {
        case .groupClasses, .groupCommands: return false
        default: return true
        }
    }

    // MARK: - Cells

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let cell = outlineView.makeView(withIdentifier: .init("cell"), owner: self) as? NSTableCellView ?? {
            let v = NSTableCellView()
            v.identifier = .init("cell")
            let tf = NSTextField(labelWithString: "")
            tf.translatesAutoresizingMaskIntoConstraints = false
            v.addSubview(tf)
            v.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 6),
                tf.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -6),
                tf.centerYAnchor.constraint(equalTo: v.centerYAnchor)
            ])
            return v
        }()

        if let it = item as? OutlineItem {
            switch it {
            case .suite(let sIdx):
                cell.textField?.stringValue = model.suites[sIdx].name
            case .groupClasses:
                cell.textField?.stringValue = "Classes"
            case .groupCommands:
                cell.textField?.stringValue = "Commands"
            case .classItem(let sIdx, let idx):
                cell.textField?.stringValue = model.suites[sIdx].classes[idx].name
            case .commandItem(let sIdx, let idx):
                cell.textField?.stringValue = model.suites[sIdx].commands[idx].name
            }
        } else {
            cell.textField?.stringValue = "?"
        }
        return cell
    }

    // MARK: - Selection → notify

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0, let it = outlineView.item(atRow: row) as? OutlineItem else {
            onSelect?(nil); return
        }
        switch it {
        case .suite(let sIdx):
            onSelect?(.suite(model.suites[sIdx]))
        case .classItem(let sIdx, let idx):
            onSelect?(.classDef(model.suites[sIdx].classes[idx]))
        case .commandItem(let sIdx, let idx):
            onSelect?(.command(model.suites[sIdx].commands[idx]))
        default:
            onSelect?(nil)
        }
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        outlineView.expandItem(nil, expandChildren: true)
    }
}


