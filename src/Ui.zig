const std = @import("std");
const rl = @import("raylib");
const Options = @import("Options.zig");
const StackTrace = @import("StackTrace.zig");

const Ui = @This();

msg: []const u8,
trace: *StackTrace,
has_panicked: bool = false,

pub fn init(msg: []const u8, trace: *StackTrace) Ui {
    if (Options.opts.extra_options.using_raylib) {
        rl.CloseWindow();
    }

    rl.SetTraceLogLevel(rl.LOG_ERROR);

    const w_height = Options.opts.extra_options.height;
    const w_width = Options.opts.extra_options.width;

    rl.InitWindow(@intCast(w_width), @intCast(w_height), "Novacrash report!");
    rl.SetTargetFPS(60);

    return .{
        .msg = msg,
        .trace = trace
    };
}

pub fn deinit(_: *Ui) void {
}

fn drawTitle(self: *Ui, y: *c_int) !void {
    rl.DrawText(@ptrCast(Options.opts.catch_phrases[0]), 30 + 128, y.*, 64, Options.opts.extra_options.fg_color);
    y.* += 64;

    const str = try std.fmt.allocPrintZ(std.heap.page_allocator, "{s} {s} {s}", .{Options.opts.app_name, Options.opts.middle_message, if (self.has_panicked) "panic" else "error" });
    defer std.heap.page_allocator.free(str);

    rl.DrawText(@ptrCast(str), 30 + 128, y.*, 22, Options.opts.extra_options.fg_color);
}

pub fn draw(self: *Ui) !void {
    const texture: ?rl.Texture = brk: {
        if (self.has_panicked) {
            if (Options.opts.crash_img) |img| {
                var image = rl.LoadImageFromMemory(".png", @ptrCast(img), @intCast(img.len));
                rl.ImageResize(&image, 128, 128);

                const texture = rl.LoadTextureFromImage(image);
                rl.UnloadImage(image);
                break :brk texture;
            } else {
                break :brk null;
            }
        } else {
            if (Options.opts.error_img) |img| {
                var image = rl.LoadImageFromMemory(".png", @ptrCast(img), @intCast(img.len));
                rl.ImageResize(&image, 128, 128);

                const texture = rl.LoadTextureFromImage(image);
                rl.UnloadImage(image);
                break :brk texture;
            } else {
                break :brk null;
            }
        }
    };

    var panelRec: rl.Rectangle = .{ .x = 10, .y = 128 + 50 + 10 + 32, .width = @as(f32, @floatFromInt(rl.GetScreenWidth())) - 20, .height = 0 };
    panelRec.height = @as(f32, @floatFromInt(rl.GetScreenHeight())) - panelRec.y - 10;

    var panelContentRec: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 };
    var panelView: rl.Rectangle  = .{ .x = 0, .y = 0, .width = 0, .height = 0 };
    var panelScroll: rl.Vector2 = .{ .x = 0, .y = 0, };

    var bg_color: u32 = 0;
    bg_color += @as(u32, @intCast(Options.opts.extra_options.bg_color.r)) << 24;
    bg_color += @as(u32, @intCast(Options.opts.extra_options.bg_color.g)) << 16;
    bg_color += @as(u32, @intCast(Options.opts.extra_options.bg_color.b)) << 8;
    bg_color += Options.opts.extra_options.bg_color.a;

    rl.GuiSetStyle(rl.DEFAULT, rl.BACKGROUND_COLOR, @bitCast(bg_color));
    rl.GuiSetStyle(rl.DEFAULT, rl.BORDER_WIDTH, 0);

    while (!rl.WindowShouldClose()) {
        var y: c_int = 20;

        rl.BeginDrawing();
        rl.ClearBackground(Options.opts.extra_options.bg_color);

        if (texture) |tex| {
            rl.DrawTexture(tex, 10, y, rl.WHITE);
        }
        try self.drawTitle(&y);
        y = 128 + 30;

        // BUG: C and NUL missing
        rl.DrawText(@ptrCast(self.msg), 10, y, 24, Options.opts.extra_options.fg_color);
        y += 32;
        rl.DrawText("Stack trace:", 10, y, 24, Options.opts.extra_options.fg_color);

        _ = rl.GuiScrollPanel(panelRec, null, panelContentRec, &panelScroll, &panelView);

        rl.BeginScissorMode(@as(c_int, @intFromFloat(panelView.x)),
            @as(c_int, @intFromFloat(panelView.y)),
            @as(c_int, @intFromFloat(panelView.width)),
            @as(c_int, @intFromFloat(panelView.height)));

        var contentHeight: u32 = @as(u32, @intFromFloat(panelView.y));
        var contentWidth: u32 = 0;

        var iter = self.trace.trace.first;

        while (iter) |i| : (iter = i.next) {
            if (std.mem.eql(u8, i.data.file_name, "???")) {
                continue;
            }

            const str = try std.fmt.allocPrint(std.heap.page_allocator, "{s} at {}:{}", .{ std.fs.path.basename(i.data.file_name), i.data.line, i.data.column});
            defer std.heap.page_allocator.free(str);
            rl.DrawText(@ptrCast(str), 10 + @as(c_int, @intFromFloat(panelScroll.x)), @intCast(contentHeight), 20, Options.opts.extra_options.fg_color);
            
            const w = rl.MeasureText(@ptrCast(str), 20);

            if (w > contentWidth) {
                contentWidth = @intCast(w);
            }

            contentHeight += 30;
        }
        contentHeight -= 30;

        panelContentRec.height = @as(f32, @floatFromInt(contentHeight));
        panelContentRec.width = @as(f32, @floatFromInt(contentWidth));

        rl.EndScissorMode();

        rl.EndDrawing();
    }

    rl.CloseWindow();
}
