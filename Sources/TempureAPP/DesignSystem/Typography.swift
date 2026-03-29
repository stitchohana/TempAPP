#if canImport(SwiftUI)
import SwiftUI

public enum TempureTypography {
    public static let header = Font.system(size: 22, weight: .semibold, design: .rounded)
    public static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    public static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
    public static let monoNumber = Font.system(size: 34, weight: .medium, design: .monospaced)
}
#endif
