import SwiftUI

@main
struct TesseractSwiftDemoApp: App {
    @StateObject private var viewModel = OCRViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .windowStyle(.titleBar)
    }
}
