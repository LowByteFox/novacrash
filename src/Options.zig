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
        font: ?rl.Font = null,
        spacing: f32 = @as(f32, @floatFromInt(rl.TEXT_SPACING)),
        bg_color: rl.Color = .{ .r = 0x16, .g = 0x16, .b = 0x16, .a = 0xFF },
        fg_color: rl.Color = rl.RAYWHITE,
        height: usize = 750,
        width: usize = 500,
        using_raylib: bool = false,
    };
}

catch_phrases: []const [:0]const u8 = &[_][:0]const u8{"Agh", "X_X", "Weh", "Guh"},
app_name: []const u8 = "App",
middle_message: []const u8 = "has encountered an",
crash_img: ?[]const u8 = null,
error_img: ?[]const u8 = null,
extra_options: ExtraOptions() = .{},
