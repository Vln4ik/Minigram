load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_dynamic_xcframework_import",
    "apple_static_xcframework_import",
)
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

objc_library(
    name = "LKObjCHelpers",
    enable_modules = True,
    module_name = "LKObjCHelpers",
    srcs = glob([
        "Sources/LKObjCHelpers/**/*.m",
        "Sources/LKObjCHelpers/**/*.h",
    ]),
    hdrs = glob(["Sources/LKObjCHelpers/include/**/*.h"]),
    includes = [
        "Sources/LKObjCHelpers/include",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = ["//visibility:public"],
)

apple_dynamic_xcframework_import(
    name = "LiveKitWebRTC",
    xcframework_imports = glob(["LiveKitWebRTC.xcframework/**"]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "RustLiveKitUniFFI",
    xcframework_imports = glob(["RustLiveKitUniFFI.xcframework/**"]),
    visibility = ["//visibility:public"],
)

swift_library(
    name = "LiveKitUniFFI",
    module_name = "LiveKitUniFFI",
    srcs = glob(["Sources/LiveKitUniFFI/**/*.swift"]),
    deps = [":RustLiveKitUniFFI"],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "LiveKit",
    module_name = "LiveKit",
    srcs = glob(["Sources/LiveKit/**/*.swift"]),
    copts = [
        "-enable-experimental-feature",
        "AccessLevelOnImport",
    ],
    deps = [
        ":LKObjCHelpers",
        ":LiveKitWebRTC",
        ":LiveKitUniFFI",
        "//third-party/swift-collections:DequeModule",
        "//third-party/swift-collections:OrderedCollections",
        "//third-party/swift-protobuf:SwiftProtobuf",
    ],
    visibility = ["//visibility:public"],
)
