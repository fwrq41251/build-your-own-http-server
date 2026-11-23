const std = @import("std");

// Learn more about this file here: https://ziglang.org/learn/build-system
pub fn build(b: *std.Build) void {
    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = b.graph.host,
    });

    const exe = b.addExecutable(.{
        .name = "main",
        .root_module = exe_module,
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // ZLS detects this step and runs `zig build check` on save, so compile
    // errors show up in the editor without running the program. The executable
    // is deliberately not installed: Zig then skips code generation and only
    // analyzes the code.
    const check_exe = b.addExecutable(.{
        .name = "main",
        .root_module = exe_module,
    });
    const check_step = b.step("check", "Check if the project compiles");
    check_step.dependOn(&check_exe.step);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    run_cmd.addPassthruArgs();
}
