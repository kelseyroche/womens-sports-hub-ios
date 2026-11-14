import SwiftUI

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

enum Theme {
    static let ink = Color(hex: "0C3B2E")
    static let chalk = Color(hex: "F8F3E9")
    static let lemon = Color(hex: "F5E50A")
    static let soft = Color(hex: "3F5A4F")
    static let rule = Color(hex: "DDD5C2")

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.compressed)
    }
}
