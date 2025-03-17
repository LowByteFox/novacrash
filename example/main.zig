const std = @import("std");
const rl = @import("raylib");
const novacrash = @import("novacrash");

pub var novacrash_options: novacrash.Options = .{
    .crash_img = @embedFile("./assets/Dead_border.png"),
    .error_img = @embedFile("./assets/Bonk_border.png"),
    .app_name = "Example",
    .middle_message = "got an",
    .extra_options = .{},
};

pub fn nova_main() !void {
    novacrash_options.extra_options.bg_color = rl.RAYWHITE;
    novacrash_options.extra_options.fg_color = rl.BLACK;

    return error.JustBecause;
}

pub const main = novacrash.callMain;
pub const panic = novacrash.panic;
