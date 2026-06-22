// swift-tools-version: 5.7
import PackageDescription

// Frontend-only shell: all backend SDK dependencies (Firebase, Google Sign-In)
// were removed during the frontend-only reset.
// TODO: BACKEND INTEGRATION — re-add backend package dependencies here.
let package = Package(
    name: "MoomoAI",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "MoomoAI", targets: ["MoomoAI"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MoomoAI",
            dependencies: [],
            path: "MoomoAI"
        )
    ]
)
