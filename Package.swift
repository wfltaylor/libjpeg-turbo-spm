// swift-tools-version: 5.9

import PackageDescription

let releaseURL = ""
let releaseChecksum = ""

let package = Package(
    name: "CLibJPEGTurbo",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "CLibJPEGTurbo", targets: ["CLibJPEGTurbo"]),
    ],
    targets: [
        .binaryTarget(name: "CLibJPEGTurbo", url: releaseURL, checksum: releaseChecksum),
        .testTarget(name: "CLibJPEGTurboTests", dependencies: ["CLibJPEGTurbo"]),
    ]
)
