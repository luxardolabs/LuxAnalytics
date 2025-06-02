// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LuxAnalytics",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "LuxAnalytics", targets: ["LuxAnalytics"])
    ],
    targets: [
        .target(name: "LuxAnalytics", dependencies: []),
        .testTarget(name: "LuxAnalyticsTests", dependencies: ["LuxAnalytics"])
    ]
)
