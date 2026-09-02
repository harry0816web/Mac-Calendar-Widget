import Foundation
import SwiftUI

extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }

        var integer: UInt64 = 0
        Scanner(string: value).scanHexInt64(&integer)

        let red: Double
        let green: Double
        let blue: Double

        switch value.count {
        case 6:
            red = Double((integer >> 16) & 0xff) / 255
            green = Double((integer >> 8) & 0xff) / 255
            blue = Double(integer & 0xff) / 255
        default:
            red = 0.2
            green = 0.48
            blue = 0.95
        }

        self.init(red: red, green: green, blue: blue)
    }
}

extension String {
    static func hexString(red: CGFloat, green: CGFloat, blue: CGFloat) -> String {
        let red = Swift.max(0, Swift.min(255, Int(red * 255)))
        let green = Swift.max(0, Swift.min(255, Int(green * 255)))
        let blue = Swift.max(0, Swift.min(255, Int(blue * 255)))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
