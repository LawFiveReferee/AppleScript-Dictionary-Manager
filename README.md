# AppleScriptDictionaryManager

macOS (AppKit + SwiftUI) SDEF dictionary editor.

- Two-pane UI (outline + preview)
- Opens `.sdef`/`.xml`, parses suites/classes/commands/properties/parameters
- Manual File ▸ Open… wired (while CFBundleDocumentTypes is being finalized)

## Build
Xcode 15+, macOS 14+/15+. Open `AppleScriptDictionaryManager.xcodeproj`, run.

## Roadmap
- CFBundleDocumentTypes + native NSDocumentController open/save
- Outline icons + auto-expand
- Editor panes, validation, export
