// swift-tools-version:4.1
//
// Copyright 2018-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.

import PackageDescription

let package = Package(
    name: "SmokeAWSCredentials",
    products: [
        .library(
            name: "SmokeAWSCredentials",
            targets: ["SmokeAWSCredentials"]),
    ],
    dependencies: [
        .package(url: "https://github.com/t089/smoke-aws.git", .branch("async-http-client")),
        .package(url: "https://github.com/IBM-Swift/LoggerAPI.git", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SmokeAWSCredentials",
            dependencies: ["SecurityTokenClient", "NIO", "NIOHTTP1", "NIOFoundationCompat", "LoggerAPI"]),
        .testTarget(
            name: "SmokeAWSCredentialsTests",
            dependencies: ["SmokeAWSCredentials"]),
    ]
)
