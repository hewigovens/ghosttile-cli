#!/usr/bin/env swift
// Generates a modern flat app icon for GhostTile
// Usage: swift generate-icon.swift <output-dir>

import AppKit
import Foundation

guard CommandLine.arguments.count >= 2 else {
    print("Usage: generate-icon.swift <output-dir>")
    exit(1)
}

let outputDir = CommandLine.arguments[1]

/// Draw a flat ghost shape. Coordinates: origin at top-left, Y goes down.
/// Call inside a flipped CG context.
func drawGhost(in ctx: CGContext, rect: CGRect) {
    let w = rect.width
    let h = rect.height
    let x = rect.origin.x
    let y = rect.origin.y
    let centerX = x + w * 0.5

    let bodyLeft = x + w * 0.1
    let bodyRight = x + w * 0.9
    let bodyWidth = bodyRight - bodyLeft
    let domeRadius = bodyWidth / 2
    let domeTop = y + h * 0.05
    let domeCenterY = domeTop + domeRadius

    let path = CGMutablePath()

    // Start at bottom-left, go up the left side
    let bottomY = y + h * 0.92
    path.move(to: CGPoint(x: bodyLeft, y: bottomY))

    // Left side up to dome
    path.addLine(to: CGPoint(x: bodyLeft, y: domeCenterY))

    // Dome (semicircle at top) — in flipped coords, clockwise goes over the top
    path.addArc(
        center: CGPoint(x: centerX, y: domeCenterY),
        radius: domeRadius,
        startAngle: .pi, endAngle: 0, clockwise: false
    )

    // Right side down
    path.addLine(to: CGPoint(x: bodyRight, y: bottomY))

    // Wavy bottom: 5 waves going right to left
    let waveCount = 5
    let waveWidth = bodyWidth / CGFloat(waveCount)
    let waveDepth = h * 0.07

    for i in 0..<waveCount {
        let startX = bodyRight - waveWidth * CGFloat(i)
        let endX = startX - waveWidth
        let goesDown = (i % 2 == 0)
        let controlY = goesDown ? bottomY + waveDepth : bottomY - waveDepth
        path.addQuadCurve(
            to: CGPoint(x: endX, y: bottomY),
            control: CGPoint(x: (startX + endX) / 2, y: controlY)
        )
    }

    path.closeSubpath()

    // Fill ghost white
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.addPath(path)
    ctx.fillPath()

    // Eyes — larger, placed higher in the dome
    let eyeRadius = w * 0.085
    let eyeY = domeCenterY + domeRadius * 0.05
    let eyeSpacing = w * 0.14

    ctx.setFillColor(CGColor(red: 0.20, green: 0.55, blue: 0.90, alpha: 1.0))
    // Left eye
    ctx.fillEllipse(in: CGRect(
        x: centerX - eyeSpacing - eyeRadius,
        y: eyeY - eyeRadius,
        width: eyeRadius * 2, height: eyeRadius * 2
    ))
    // Right eye
    ctx.fillEllipse(in: CGRect(
        x: centerX + eyeSpacing - eyeRadius,
        y: eyeY - eyeRadius,
        width: eyeRadius * 2, height: eyeRadius * 2
    ))
}

let iconsetDir = outputDir + "/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for entry in sizes {
    let s = CGFloat(entry.size)

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: entry.size, pixelsHigh: entry.size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: s, height: s)

    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    // Flip to top-left origin
    cg.translateBy(x: 0, y: s)
    cg.scaleBy(x: 1, y: -1)

    // Background gradient
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.30, green: 0.82, blue: 0.88, alpha: 1.0),
        CGColor(red: 0.25, green: 0.52, blue: 0.95, alpha: 1.0),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0, 1])!

    // Rounded rect clip
    let cornerRadius = s * 0.22
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    cg.addPath(bgPath)
    cg.clip()

    // Gradient: top-left to bottom-right
    cg.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: s, y: s),
        options: []
    )

    // Ghost
    let ghostSize = s * 0.74
    let ghostRect = CGRect(
        x: (s - ghostSize) / 2,
        y: (s - ghostSize) / 2 - s * 0.02,
        width: ghostSize, height: ghostSize
    )
    drawGhost(in: cg, rect: ghostRect)

    NSGraphicsContext.current = nil

    guard let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to render \(entry.name)")
        continue
    }

    let path = iconsetDir + "/\(entry.name).png"
    try png.write(to: URL(fileURLWithPath: path))
    print("Generated \(entry.name) (\(entry.size)px)")
}

let icnsPath = outputDir + "/appIcon.icns"
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", icnsPath, iconsetDir]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Created \(icnsPath)")
    try FileManager.default.removeItem(atPath: iconsetDir)
} else {
    print("iconutil failed")
    exit(1)
}
