const root = @import("root");
const config = @import("config");

const Options = @This();
pub const opts: *const Options = if (@hasDecl(root, "novacrash_options")) &root.novacrash_options else &(Options {});

fn ExtraOptions() type {
    return if (config.custom_frontend) struct {
        userdata: usize = 0,
        // TODO: possibly add extra fields
    } else struct {
        const rl = @import("raylib");
        font: ?[]const u8 = null,
        spacing: f32 = @as(f32, @floatFromInt(2)),
        font_size: u32 = 22,
        bg_color: rl.Color = .{ .r = 0x16, .g = 0x16, .b = 0x16, .a = 0xFF },
        active_color: rl.Color = .{ .r = 0x17, .g = 0xA0, .b = 0x86, .a = 0xFF },
        fg_color: rl.Color = .{ .r = 0xEB, .g = 0xEB, .b = 0xEB, .a = 0xFF },
        height: usize = 750,
        width: usize = 500,
        using_raylib: bool = false,
    };
}

catch_phrases: []const [:0]const u8 = &[_][:0]const u8{"Bleh", "X_X", "Weh", "Guh"},
app_name: []const u8 = "App",
error_message: []const u8 = "has encountered an",
panic_message: []const u8 = "has encountered a",
crash_img: ?[]const u8 = null,
error_img: ?[]const u8 = null,
extra_options: ExtraOptions() = .{},
