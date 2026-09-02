import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct IconSpec {
    let filename: String
    let pixels: Int
}

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("MacCalendarWeekApp", isDirectory: true)
    .appendingPathComponent("Assets.xcassets", isDirectory: true)
    .appendingPathComponent("AppIcon.appiconset", isDirectory: true)

let specs = [
    IconSpec(filename: "icon_16x16.png", pixels: 16),
    IconSpec(filename: "icon_16x16@2x.png", pixels: 32),
    IconSpec(filename: "icon_32x32.png", pixels: 32),
    IconSpec(filename: "icon_32x32@2x.png", pixels: 64),
    IconSpec(filename: "icon_128x128.png", pixels: 128),
    IconSpec(filename: "icon_128x128@2x.png", pixels: 256),
    IconSpec(filename: "icon_256x256.png", pixels: 256),
    IconSpec(filename: "icon_256x256@2x.png", pixels: 512),
    IconSpec(filename: "icon_512x512.png", pixels: 512),
    IconSpec(filename: "icon_512x512@2x.png", pixels: 1024)
]

func drawRoundedRect(context: CGContext, rect: CGRect, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}

func drawIcon(size: Int) -> CGImage {
    let width = size
    let height = size
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    let scale = CGFloat(size) / 1024.0
    context.scaleBy(x: scale, y: scale)

    let canvas = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    context.clear(canvas)

    let shadow = CGColor(gray: 0.0, alpha: 0.22)
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 42, color: shadow)
    drawRoundedRect(
        context: context,
        rect: CGRect(x: 78, y: 78, width: 868, height: 868),
        radius: 204,
        color: CGColor(red: 0.965, green: 0.975, blue: 0.985, alpha: 1)
    )
    context.setShadow(offset: .zero, blur: 0, color: nil)

    let headerRect = CGRect(x: 112, y: 734, width: 800, height: 150)
    drawRoundedRect(
        context: context,
        rect: headerRect,
        radius: 74,
        color: CGColor(red: 1.0, green: 0.23, blue: 0.25, alpha: 1)
    )

    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
    let dotY: CGFloat = 810
    for x in stride(from: CGFloat(254), through: CGFloat(770), by: CGFloat(86)) {
        context.fillEllipse(in: CGRect(x: x - 18, y: dotY - 18, width: 36, height: 36))
    }

    let pageRect = CGRect(x: 128, y: 150, width: 768, height: 630)
    drawRoundedRect(
        context: context,
        rect: pageRect,
        radius: 64,
        color: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    )

    context.setStrokeColor(CGColor(red: 0.82, green: 0.84, blue: 0.87, alpha: 1))
    context.setLineWidth(9)
    for i in 1..<7 {
        let x = pageRect.minX + pageRect.width * CGFloat(i) / 7.0
        context.move(to: CGPoint(x: x, y: pageRect.minY + 40))
        context.addLine(to: CGPoint(x: x, y: pageRect.maxY - 34))
        context.strokePath()
    }

    for i in 1..<4 {
        let y = pageRect.minY + 92 + CGFloat(i) * 118
        context.move(to: CGPoint(x: pageRect.minX + 36, y: y))
        context.addLine(to: CGPoint(x: pageRect.maxX - 36, y: y))
        context.strokePath()
    }

    let todayRect = CGRect(x: 456, y: 554, width: 112, height: 112)
    context.setFillColor(CGColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 1))
    context.fillEllipse(in: todayRect)

    let eventColors = [
        CGColor(red: 0.47, green: 0.82, blue: 0.31, alpha: 1),
        CGColor(red: 0.58, green: 0.58, blue: 1.00, alpha: 1),
        CGColor(red: 0.93, green: 0.40, blue: 0.82, alpha: 1),
        CGColor(red: 0.11, green: 0.56, blue: 1.00, alpha: 1)
    ]

    drawRoundedRect(context: context, rect: CGRect(x: 152, y: 490, width: 612, height: 54), radius: 25, color: eventColors[0])
    drawRoundedRect(context: context, rect: CGRect(x: 594, y: 382, width: 206, height: 48), radius: 22, color: eventColors[1])
    drawRoundedRect(context: context, rect: CGRect(x: 594, y: 320, width: 252, height: 48), radius: 22, color: eventColors[2])

    context.setStrokeColor(eventColors[3])
    context.setLineWidth(14)
    context.addPath(CGPath(roundedRect: CGRect(x: 246, y: 242, width: 210, height: 74), cornerWidth: 28, cornerHeight: 28, transform: nil))
    context.strokePath()

    context.setStrokeColor(CGColor(red: 0.89, green: 0.91, blue: 0.94, alpha: 1))
    context.setLineWidth(10)
    context.addPath(CGPath(roundedRect: CGRect(x: 78, y: 78, width: 868, height: 868), cornerWidth: 204, cornerHeight: 204, transform: nil))
    context.strokePath()

    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }

    CGImageDestinationAddImage(destination, image, nil)
    if !CGImageDestinationFinalize(destination) {
        throw CocoaError(.fileWriteUnknown)
    }
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for spec in specs {
    let image = drawIcon(size: spec.pixels)
    try writePNG(image, to: outputDirectory.appendingPathComponent(spec.filename))
}

print("Generated \(specs.count) app icon images in \(outputDirectory.path)")
