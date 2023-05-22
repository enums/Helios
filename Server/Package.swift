// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "Helios",
    platforms: [
       .macOS(.v12)
    ],
    products: [
        .executable(name: "Admin", targets: ["Admin"]),

        .executable(name: "Home", targets: ["Home"]),
        .executable(name: "Postman", targets: ["Postman"]),
        .executable(name: "Logger", targets: ["Logger"]),

        .library(name: "Helios", targets: ["Helios"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/redis.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.0.0"),
        .package(url: "https://github.com/enums/SwiftyScript" , from: "1.3.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "3.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Admin",
            dependencies: ["Helios", "Selene", "SwiftyScript"],
            swiftSettings: [.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))]
        ),

        .executableTarget(
            name: "Home",
            dependencies: ["Helios", "Selene"],
            swiftSettings: [.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))]
        ),
        .executableTarget(
            name: "Postman",
            dependencies: ["Helios", "Selene"],
            swiftSettings: [.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))]
        ),
        .executableTarget(
            name: "Logger",
            dependencies: ["Helios", "Selene"],
            swiftSettings: [.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))]
        ),

        .target(name: "Selene", dependencies: ["Helios"]),

        .target(name: "Helios", dependencies: [
            .product(name: "Vapor", package: "vapor"),
            .product(name: "Leaf", package: "leaf"),
            .product(name: "Fluent", package: "fluent"),
            .product(name: "FluentMySQLDriver", package: "fluent-mysql-driver"),
            .product(name: "Redis", package: "redis"),
            .product(name: "QueuesRedisDriver", package: "queues-redis-driver"),
        ]),
    ]
)
