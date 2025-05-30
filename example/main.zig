const std = @import("std");
const rl = @import("raylib");
const novacrash = @import("novacrash");

pub var novacrash_options: novacrash.Options = .{
    .app_name = "Example",
    .extra = .{
        .header = .{
            .icon_size = .{ .x = 128, .y = 128 },
            .title_size = 32,
            .error_icon = @embedFile("./assets/Bonk_border.png"),
            .crash_icon = @embedFile("./assets/Dead_border.png"),
        },
        .theme = .{
            .font = @embedFile("./assets/Ubuntu-R.ttf"),
            .font_size = 22,
        }
    }
};

pub fn novaMain() !void {
    @panic("Sample panic message!");
    // return error.SampleError;
}

pub const main = novacrash.callMain;
pub const panic = novacrash.panic;
