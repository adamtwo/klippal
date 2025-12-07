#!/usr/bin/env swift
import AppKit
import Foundation

/// Generates an app icon with the KlipPal "Kᵖ" branding
/// Usage: swift generate-app-icon.swift [output-path]

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Sources/KlipPal/Resources/AppIcon.icns"

// Icon sizes required for macOS app icons
let iconSizes: [(size: Int, scale: Int, name: String)] = [
    (16, 1, "icon_16x16"),
    (16, 2, "icon_16x16@2x"),
    (32, 1, "icon_32x32"),
    (32, 2, "icon_32x32@2x"),
    (128, 1, "icon_128x128"),
    (128, 2, "icon_128x128@2x"),
    (256, 1, "icon_256x256"),
    (256, 2, "icon_256x256@2x"),
    (512, 1, "icon_512x512"),
    (512, 2, "icon_512x512@2x"),
]

/// Creates a single icon image at the specified size
func createIconImage(size: Int, scale: Int) -> NSImage {
    let pixelSize = size * scale
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))

    image.lockFocus()

    // Get graphics context
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)

    // Background: rounded rectangle with gradient
    let cornerRadius = CGFloat(pixelSize) * 0.22 // macOS standard icon corner radius
    let path = CGPath(roundedRect: rect.insetBy(dx: 1, dy: 1),
                      cornerWidth: cornerRadius,
                      cornerHeight: cornerRadius,
                      transform: nil)

    // Gradient background (blue accent color)
    let colors = [
        NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0).cgColor,  // System blue
        NSColor(red: 0.0, green: 0.35, blue: 0.85, alpha: 1.0).cgColor,  // Darker blue
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: colors as CFArray,
                               locations: [0.0, 1.0])!

    context.saveGState()
    context.addPath(path)
    context.clip()
    context.drawLinearGradient(gradient,
                                start: CGPoint(x: 0, y: CGFloat(pixelSize)),
                                end: CGPoint(x: 0, y: 0),
                                options: [])
    context.restoreGState()

    // Add subtle border
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.3).cgColor)
    context.setLineWidth(CGFloat(pixelSize) * 0.01)
    context.addPath(path)
    context.strokePath()

    // Draw "Kᵖ" text
    let fontSize = CGFloat(pixelSize) * 0.55

    // Create attributed string with proper font
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let roundedFont = NSFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor,
                              size: fontSize) ?? font

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center

    let attributes: [NSAttributedString.Key: Any] = [
        .font: roundedFont,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraphStyle
    ]

    let text = "Kᵖ"
    let textSize = text.size(withAttributes: attributes)

    // Center the text
    let textRect = CGRect(
        x: (CGFloat(pixelSize) - textSize.width) / 2,
        y: (CGFloat(pixelSize) - textSize.height) / 2 - CGFloat(pixelSize) * 0.02,
        width: textSize.width,
        height: textSize.height
    )

    text.draw(in: textRect, withAttributes: attributes)

    image.unlockFocus()

    return image
}

/// Creates an iconset folder with all required sizes
func createIconset() -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let iconsetPath = tempDir.appendingPathComponent("AppIcon.iconset")

    // Remove existing iconset if present
    try? FileManager.default.removeItem(at: iconsetPath)
    try! FileManager.default.createDirectory(at: iconsetPath, withIntermediateDirectories: true)

    for (size, scale, name) in iconSizes {
        let image = createIconImage(size: size, scale: scale)
        let pngPath = iconsetPath.appendingPathComponent("\(name).png")

        // Convert to PNG data
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to create PNG for \(name)")
            continue
        }

        try! pngData.write(to: pngPath)
        print("Created \(name).png (\(size * scale)x\(size * scale) pixels)")
    }

    return iconsetPath
}

/// Converts iconset to icns using iconutil
func createIcns(from iconsetPath: URL, to outputURL: URL) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconsetPath.path, "-o", outputURL.path]

    do {
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            print("\nSuccessfully created: \(outputURL.path)")
        } else {
            print("iconutil failed with status: \(process.terminationStatus)")
        }
    } catch {
        print("Failed to run iconutil: \(error)")
    }
}

// Main execution
print("Generating KlipPal app icon...")
print("")

let iconsetPath = createIconset()
let outputURL = URL(fileURLWithPath: outputPath)

// Ensure output directory exists
let outputDir = outputURL.deletingLastPathComponent()
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

createIcns(from: iconsetPath, to: outputURL)

// Cleanup
try? FileManager.default.removeItem(at: iconsetPath)
