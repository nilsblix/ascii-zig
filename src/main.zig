const std = @import("std");
const psystem = @import("ascii.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const stdev = 8.0;
    const num_particles = 3000;

    var state = try psystem.System.init(allocator, stdev, num_particles);
    defer state.deinit();

    while (true) {
        try state.update();
        std.debug.print("\x1B[2J\x1B[H", .{});

        try state.display();
        // seconds
        const T: f32 = 1 / psystem.ParticleParams.hz;
        std.Thread.sleep(T * 1e9);
    }
}
