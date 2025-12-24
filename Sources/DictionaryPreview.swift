import SwiftUI

struct DictionaryPreview: View {
    @ObservedObject var vm: DictionaryPreviewVM
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(vm.title).font(.title2)
            Text(vm.details).font(.system(.body, design: .monospaced))
            Spacer()
        }
        .padding()
    }
}
