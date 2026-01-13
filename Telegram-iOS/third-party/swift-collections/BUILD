load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "InternalCollectionsUtilities",
    module_name = "InternalCollectionsUtilities",
    srcs = glob(["Sources/InternalCollectionsUtilities/**/*.swift"]),
    visibility = ["//visibility:public"],
)

swift_library(
    name = "DequeModule",
    module_name = "DequeModule",
    srcs = glob(["Sources/DequeModule/**/*.swift"]),
    deps = [":InternalCollectionsUtilities"],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "OrderedCollections",
    module_name = "OrderedCollections",
    srcs = glob(["Sources/OrderedCollections/**/*.swift"]),
    deps = [":InternalCollectionsUtilities"],
    visibility = ["//visibility:public"],
)
