#if canImport(SwiftUI)
import SwiftUI

public struct TempureRootView: View {
    @State private var container: AppContainer?
    @State private var startupError: String?

    public init() {}

    public var body: some View {
        Group {
            if let container {
                HomeView(viewModel: HomeViewModel(container: container))
            } else if let startupError {
                Text(startupError)
                    .font(TempureTypography.body)
                    .padding()
            } else {
                ProgressView()
                    .task {
                        do {
                            container = try AppContainer.bootstrap()
                        } catch {
                            startupError = "Database init failed: \(error.localizedDescription)"
                        }
                    }
            }
        }
    }
}

#if !SWIFT_PACKAGE
@main
struct TempureApp: App {
    var body: some Scene {
        WindowGroup {
            TempureRootView()
        }
    }
}
#endif
#endif
