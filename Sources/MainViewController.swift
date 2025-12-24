import Cocoa
import SwiftUI

final class MainViewController: NSViewController {
    private var hosting: NSHostingView<DictionaryPreview>!
    private let outlineContainer = NSView()
    private let previewContainer = NSView()
    private let split = NSSplitView()

    private let outlineVC = DictionaryOutlineViewController()
    private var model = SDEFDocumentModel.sample()
    private let previewVM = DictionaryPreviewVM()

    override func loadView() {
        self.view = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))

        // Split
        split.frame = self.view.bounds
        split.autoresizingMask = [.width, .height]
        split.isVertical = true
        split.dividerStyle = .thin
        self.view.addSubview(split)

        // Left / Right
        outlineContainer.frame = .init(x: 0, y: 0, width: 300, height: self.view.bounds.height)
        previewContainer.frame = .init(x: 300, y: 0, width: self.view.bounds.width - 300, height: self.view.bounds.height)
        split.addSubview(outlineContainer)
        split.addSubview(previewContainer)
        split.setPosition(300, ofDividerAt: 0)

        // Outline VC
        addChild(outlineVC)
        outlineVC.view.frame = outlineContainer.bounds
        outlineVC.view.autoresizingMask = [.width, .height]
        outlineContainer.addSubview(outlineVC.view)
        outlineVC.model = model

        // Selection → update VM
        outlineVC.onSelect = { [weak self] selection in
            self?.previewVM.load(selection: selection)
        }

        // SwiftUI Preview
        hosting = NSHostingView(rootView: DictionaryPreview(vm: previewVM))
        hosting.frame = previewContainer.bounds
        hosting.autoresizingMask = [.width, .height]
        previewContainer.addSubview(hosting)

        // Preselect first suite so preview shows something
        if let first = model.suites.first {
            previewVM.load(selection: .suite(first))
        }
    }

    // Called by SDEDocument after parsing a file
    func load(model: SDEFDocumentModel) {
        self.model = model
        outlineVC.model = model
        if let first = model.suites.first {
            previewVM.load(selection: .suite(first))
        } else {
            previewVM.load(selection: nil)
        }
    }
}
