import SwiftUI

@main
struct FinePrintApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ImportView()
                .environment(model)
                .tint(Theme.accent)
                .task { await model.checkEngines() }
        }
    }
}
