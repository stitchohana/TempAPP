import Foundation

#if canImport(UIKit)
import UIKit
#endif

public protocol HapticsService: Sendable {
    @MainActor
    func light()
    @MainActor
    func selection()
    @MainActor
    func success()
}

public struct SystemHapticsService: HapticsService {
    public init() {}

    @MainActor
    public func light() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    @MainActor
    public func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    @MainActor
    public func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
