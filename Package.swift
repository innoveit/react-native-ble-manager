// swift-tools-version: 6.0

import Foundation
import PackageDescription

let reactHeaders: [Target.Dependency] = [
    .product(name: "ReactHeaders", package: "ReactNative"),
    .product(name: "ReactNativeHeaders", package: "ReactNative"),
    .product(name: "ReactNativeDependenciesHeaders", package: "ReactNative"),
    .product(name: "ReactAppHeaders", package: "React-GeneratedCode"),
]

let usedRootEntries: Set<String> = ["ios", "spm-headers", "spm-support", "Package.swift"]
let unusedRootEntries = try! FileManager.default.contentsOfDirectory(atPath: Context.packageDirectory)
    .filter { !usedRootEntries.contains($0) }
    .sorted()
let iosDirectory = URL(fileURLWithPath: Context.packageDirectory).appendingPathComponent("ios")
let iosEntries = try! FileManager.default.subpathsOfDirectory(atPath: iosDirectory.path)
    .filter { !$0.contains(".xcodeproj/") }
func unusedIosEntries(sourceExtensions: Set<String>) -> [String] {
    iosEntries.filter { entry in
        let url = iosDirectory.appendingPathComponent(entry)
        if url.pathExtension == "xcodeproj" { return true }
        return try! url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true
            && !sourceExtensions.contains(url.pathExtension)
    }
    .map { "ios/" + $0 }
    .sorted()
}

let package = Package(
    name: "RNBleManager",
    platforms: [.iOS("15.1")],
    products: [
        .library(name: "RNBleManager", targets: ["RNBleManager", "RNBleManagerObjC"]),
    ],
    dependencies: [
        // React Native evaluates this package through its generated libs/ symlink.
        .package(name: "ReactNative", path: "../../../../xcframeworks"),
        .package(name: "React-GeneratedCode", path: "../../../ios"),
    ],
    targets: [
        .target(
            name: "RNBleManager",
            dependencies: [.target(name: "RNBleManagerObjC")] + reactHeaders,
            path: ".",
            exclude: unusedRootEntries + ["spm-headers"] + unusedIosEntries(sourceExtensions: ["swift"]),
            sources: ["ios", "spm-support"],
            linkerSettings: [.linkedFramework("CoreBluetooth")]
        ),
        .target(
            name: "RNBleManagerObjC",
            dependencies: reactHeaders,
            path: ".",
            exclude: unusedRootEntries + ["spm-support"] + unusedIosEntries(sourceExtensions: ["h", "mm"]),
            sources: ["ios/BleManager.mm"],
            publicHeadersPath: "spm-headers/public",
            cSettings: [
                .define("RCT_NEW_ARCH_ENABLED", to: "1"),
                .headerSearchPath("ios"),
                .headerSearchPath("spm-headers"),
            ],
            cxxSettings: [
                .define("RCT_NEW_ARCH_ENABLED", to: "1"),
                .define("DEBUG", .when(configuration: .debug)),
                .define("NDEBUG", .when(configuration: .release)),
                .headerSearchPath("ios"),
                .headerSearchPath("spm-headers"),
            ],
            linkerSettings: [.linkedFramework("CoreBluetooth")]
        ),
    ],
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx20
)
