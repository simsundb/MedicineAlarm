// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MedicineAlarm",
    platforms: [
        // SMAppService (开机自启) 需要 macOS 13+；本机为 macOS 26。
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MedicineAlarm",
            path: "Sources/MedicineAlarm",
            swiftSettings: [
                // AppKit 的 delegate / Timer 回调在 Swift 6 严格并发下会大量报错。
                // 用 Swift 5 语言模式，避免为并发标注消耗精力。
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
