const std = @import("std");
const rl = @import("raylib");
const novacrash = @import("novacrash");

pub var novacrash_options: novacrash.Options = .{
    .crash_img = @embedFile("./assets/Dead_border.png"),
    .error_img = @embedFile("./assets/Bonk_border.png"),
    .app_name = "Example\n-",
    .extra_options = .{},
};

pub fn novaMain() !void {
    novacrash_options.extra_options.font = @embedFile("./assets/Ubuntu-R.ttf");
    novacrash_options.extra_options.font_size = 24;

    return error.TheyLetMetError;
}

pub const main = novacrash.callMain;
pub const panic = novacrash.panic;
