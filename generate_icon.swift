#!/usr/bin/env swift
// ParkArmor App Icon Generator
// Generates a 1024×1024 PNG and writes it to:
//   ParkArmor/Assets.xcassets/AppIcon.appiconset/AppIcon.png
// Run from the repo root: swift generate_icon.swift

import CoreGraphics
import ImageIO
import Foundation
import AppKit

let size: CGFloat = 1024.0
let half = size / 2.0

// Colors
let navy = NSColor(calibratedRed: 0.039, green: 0.055, blue: 0.102, alpha: 1.0)
let cyan  = NSColor(calibratedRed: 0.0,   green: 0.941, blue: 1.0,   alpha: 1.0)
let white = NSColor.white
let darkNavy = NSColor(calibratedRed: 0.02, green: 0.03, blue: 0.07, alpha: 1.0)

// Create image
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
guard let ctx = NSGraphicsContext.current?.cgContext else {
    print("Failed to get graphics context"); exit(1)
}

// --- Background ---
ctx.setFillColor(navy.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Rounded-rect background (iOS-style icon corners)
let bgPath = NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size), xRadius: 230, yRadius: 230)
ctx.addPath(bgPath.cgPath)
ctx.setFillColor(navy.cgColor)
ctx.fillPath()

// --- Shield path ---
func shieldPath(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let r = w * 0.11
    let top    = cy + h * 0.44
    let bottom = cy - h * 0.52
    let left   = cx - w * 0.42
    let right  = cx + w * 0.42

    // Top-left → top-right
    path.move(to: NSPoint(x: left + r, y: top))
    path.line(to: NSPoint(x: right - r, y: top))
    // Top-right arc
    path.appendArc(withCenter: NSPoint(x: right - r, y: top - r), radius: r, startAngle: 90, endAngle: 0, clockwise: true)
    // Right side down to curve
    path.line(to: NSPoint(x: right, y: cy - h * 0.08))
    // Right to bottom tip (quadratic approximated as arc+line)
    path.curve(to: NSPoint(x: cx, y: bottom),
               controlPoint1: NSPoint(x: right, y: cy - h * 0.40),
               controlPoint2: NSPoint(x: cx + w * 0.15, y: bottom + h * 0.06))
    // Bottom tip to left
    path.curve(to: NSPoint(x: left, y: cy - h * 0.08),
               controlPoint1: NSPoint(x: cx - w * 0.15, y: bottom + h * 0.06),
               controlPoint2: NSPoint(x: left, y: cy - h * 0.40))
    path.line(to: NSPoint(x: left, y: top - r))
    // Top-left arc
    path.appendArc(withCenter: NSPoint(x: left + r, y: top - r), radius: r, startAngle: 180, endAngle: 90, clockwise: true)
    path.close()
    return path
}

// Glow behind shield
let glowColors = [cyan.withAlphaComponent(0.12).cgColor, cyan.withAlphaComponent(0.0).cgColor] as CFArray
let glowLocations: [CGFloat] = [0.0, 1.0]
if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: glowLocations) {
    ctx.drawRadialGradient(gradient,
        startCenter: CGPoint(x: half, y: half), startRadius: 0,
        endCenter: CGPoint(x: half, y: half), endRadius: 380,
        options: [])
}

// Shield fill
let shield = shieldPath(cx: half, cy: half + 10, w: size * 0.60, h: size * 0.66)
ctx.addPath(shield.cgPath)
ctx.setFillColor(cyan.cgColor)
ctx.fillPath()

// Shield inner highlight (lighter stripe top-left)
ctx.saveGState()
ctx.addPath(shield.cgPath)
ctx.clip()
let highlightColors = [white.withAlphaComponent(0.18).cgColor, white.withAlphaComponent(0.0).cgColor] as CFArray
if let highlight = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: highlightColors, locations: glowLocations) {
    ctx.drawLinearGradient(highlight,
        start: CGPoint(x: half - 200, y: half + 300),
        end: CGPoint(x: half + 100, y: half - 100),
        options: [])
}
ctx.restoreGState()

// --- Map pin (location marker) over shield ---
let pinCX = half
let pinCY = half + 30.0
let headR: CGFloat = 90.0

// Shadow
let shadowPath = NSBezierPath()
shadowPath.appendOval(in: NSRect(x: pinCX - headR + 8, y: pinCY - headR + 8, width: headR * 2, height: headR * 2))
ctx.addPath(shadowPath.cgPath)
ctx.setFillColor(NSColor.black.withAlphaComponent(0.3).cgColor)
ctx.fillPath()

// Pin teardrop body
let pinPath = NSBezierPath()
let tailLen: CGFloat = 120.0
let tailW: CGFloat   = headR * 0.55
let tipY = pinCY - headR - tailLen

pinPath.move(to: NSPoint(x: pinCX - tailW, y: pinCY - headR * 0.4))
pinPath.curve(to: NSPoint(x: pinCX, y: tipY),
              controlPoint1: NSPoint(x: pinCX - tailW * 1.1, y: tipY + 24),
              controlPoint2: NSPoint(x: pinCX - 10, y: tipY + 2))
pinPath.curve(to: NSPoint(x: pinCX + tailW, y: pinCY - headR * 0.4),
              controlPoint1: NSPoint(x: pinCX + 10, y: tipY + 2),
              controlPoint2: NSPoint(x: pinCX + tailW * 1.1, y: tipY + 24))
pinPath.close()
ctx.addPath(pinPath.cgPath)
ctx.setFillColor(white.cgColor)
ctx.fillPath()

// Pin head circle (white)
let headPath = NSBezierPath()
headPath.appendOval(in: NSRect(x: pinCX - headR, y: pinCY - headR, width: headR * 2, height: headR * 2))
ctx.addPath(headPath.cgPath)
ctx.setFillColor(white.cgColor)
ctx.fillPath()

// Inner circle (navy) — creates ring effect
let innerR: CGFloat = headR * 0.52
let innerPath = NSBezierPath()
innerPath.appendOval(in: NSRect(x: pinCX - innerR, y: pinCY - innerR, width: innerR * 2, height: innerR * 2))
ctx.addPath(innerPath.cgPath)
ctx.setFillColor(navy.cgColor)
ctx.fillPath()

// "P" letter inside the pin using NSAttributedString
let pAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 82),
    .foregroundColor: white
]
let pString = NSAttributedString(string: "P", attributes: pAttrs)
let pSize = pString.size()
pString.draw(at: NSPoint(x: pinCX - pSize.width / 2, y: pinCY - pSize.height / 2))

// --- Output ---
let outputPath = "ParkArmor/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let outputURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG data"); exit(1)
}
do {
    try pngData.write(to: outputURL)
    print("✓ App icon written to \(outputPath)")
} catch {
    print("Failed to write PNG: \(error)"); exit(1)
}
