// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "Helios",
    platforms: [
       .macOS(.v12)
    ],
    products: [
        .library(name: "Helios", targets: ["Helios"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/redis.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.0.0"),
    ],
    targets: [
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
