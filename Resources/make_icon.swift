#!/usr/bin/env swift
//
// 生成应用图标（.iconset）——不依赖任何外部图片素材，
// 直接用 Core Graphics 画一个药丸图标。
//
// 用法: swift Resources/make_icon.swift <输出目录>
//
import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    FileHandle.standardError.write("用法: swift make_icon.swift <输出目录>\n".data(using: .utf8)!)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

/// 画一张指定像素尺寸的图标，返回 PNG 数据。
func renderIcon(pixelSize: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    let s = CGFloat(pixelSize)
    let inset = s * 0.06
    let bounds = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cornerRadius = bounds.width * 0.225

    // 背景：圆角矩形 + 对角渐变
    let background = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.29, green: 0.56, blue: 0.92, alpha: 1),  // 蓝
        NSColor(srgbRed: 0.16, green: 0.75, blue: 0.68, alpha: 1),  // 青
    ])
    gradient?.draw(in: background, angle: -60)

    // 药丸：白色胶囊，斜 45°
    context.cgContext.saveGState()
    context.cgContext.translateBy(x: s / 2, y: s / 2)
    context.cgContext.rotate(by: -.pi / 4)

    let pillWidth = s * 0.60
    let pillHeight = s * 0.285
    let pillRect = NSRect(
        x: -pillWidth / 2, y: -pillHeight / 2,
        width: pillWidth, height: pillHeight
    )
    let pill = NSBezierPath(roundedRect: pillRect, xRadius: pillHeight / 2, yRadius: pillHeight / 2)

    NSColor.white.setFill()
    pill.fill()

    // 左半边填成深蓝，做出「两半胶囊」的样子
    context.cgContext.saveGState()
    pill.addClip()
    let half = NSRect(
        x: -pillWidth / 2, y: -pillHeight / 2,
        width: pillWidth / 2, height: pillHeight
    )
    NSColor(srgbRed: 0.20, green: 0.42, blue: 0.80, alpha: 1).setFill()
    half.fill()
    context.cgContext.restoreGState()

    // 胶囊外壳描边，避免白色和背景糊在一起
    NSColor.white.withAlphaComponent(0.9).setStroke()
    pill.lineWidth = max(1, s * 0.012)
    pill.stroke()

    context.cgContext.restoreGState()

    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

// iconutil 要求的文件名 → 像素尺寸
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for variant in variants {
    guard let data = renderIcon(pixelSize: variant.pixels) else {
        FileHandle.standardError.write("渲染 \(variant.name) 失败\n".data(using: .utf8)!)
        exit(1)
    }
    try data.write(to: outputDirectory.appendingPathComponent(variant.name))
}

print("已生成 \(variants.count) 张图标 → \(outputDirectory.path)")
