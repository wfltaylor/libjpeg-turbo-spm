// swift-tools-version: 5.9

import PackageDescription

let releaseURL = "https://github.com/wfltaylor/libjpeg-turbo-spm/releases/download/3.1.1/CLibJPEGTurbo.xcframework.zip"
let releaseChecksum = "d1fc22da5d5e01a84381e966d4479c9e6bcc73fbf4d15c66793a0fa3b0c9bac0"

let package = Package(
    name: "CLibJPEGTurbo",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "CLibJPEGTurbo", targets: ["CLibJPEGTurbo"]),
    ],
    targets: [
        .binaryTarget(name: "CLibJPEGTurbo", url: releaseURL, checksum: releaseChecksum),
    ]
)
