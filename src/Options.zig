const root = @import("root");
const config = @import("config");

const Options = @This();
pub const opts: *const Options = if (@hasDecl(root, "novacrash_options")) &root.novacrash_options else &(Options {});

fn ExtraOptions() type {
    return comptime if (config.custom_frontend) struct {
        userdata: usize = 0,
        // TODO: possibly add extra fields
    } else struct {
        const rl = @import("raylib");
        using_raylib: bool = false,

        window: struct {
            title: [:0]const u8 = "Novacrash Report",
            height: i32 = 850,
            width: i32 = 600,
        } = .{},

        theme: struct {
            background: rl.Color = .{ .r = 0x16, .g = 0x16, .b = 0x16, .a = 0xFF },
            foreground: rl.Color = .{ .r = 0xEB, .g = 0xEB, .b = 0xEB, .a = 0xFF },
            ambient: rl.Color = .{ .r = 0x17, .g = 0xA0, .b = 0x86, .a = 0xFF },
            font: ?[]const u8 = null,
            spacing: f32 = 2,
            font_size: f32 = 22,
            padding: f32 = 10,
        } = .{},

        header: struct {
            catch_phrases: []const [:0]const u8 = &[_][:0]const u8{"!!!"},
            crash_icon: ?[]const u8 = null,
            error_icon: ?[]const u8 = null,
            icon_size: rl.Vector2 = .{ .x = 128, .y = 128 },
            title_size: f32 = 48,
        } = .{},

        webhook_url: ?[]const u8 = null,
    };
}

app_name: []const u8 = "App",
error_message: []const u8 = "has encountered an",
panic_message: []const u8 = "has encountered a",
extra: ExtraOptions() = .{},
