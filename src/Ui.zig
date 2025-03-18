const std = @import("std");
const rl = @import("raylib");
const Options = @import("Options.zig");
const StackTrace = @import("StackTrace.zig");

const Ui = @This();

msg: []const u8,
trace: *StackTrace,
has_panicked: bool = false,
phrase_index: usize,
font: rl.Font,
active_color: rl.Color,
bg_color: rl.Color,
fg_color: rl.Color,
font_size: u32,
spacing: f32,
toggle_full_path: bool,

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
        .trace = trace,
        .phrase_index = 0,
        .font = brk: {
            if (Options.opts.extra_options.font) |font| {
                const f = rl.LoadFontFromMemory(".ttf", font.ptr, @intCast(font.len), 64, null, 0);
                rl.SetTextureFilter(f.texture, rl.TEXTURE_FILTER_TRILINEAR);

                break :brk f;
            }
            break :brk rl.GetFontDefault();
        },
        .active_color = Options.opts.extra_options.active_color,
        .bg_color = Options.opts.extra_options.bg_color,
        .fg_color = Options.opts.extra_options.fg_color,
        .font_size = Options.opts.extra_options.font_size,
        .spacing = Options.opts.extra_options.spacing,
        .toggle_full_path = false,
    };
}

pub fn deinit(_: *Ui) void {
}

fn drawTitle(self: *Ui, y: *c_int) !void {
    rl.DrawTextEx(self.font, Options.opts.catch_phrases[self.phrase_index], .{
        .x = 30 + 128,
        .y = @floatFromInt(y.*),
    }, 64, self.spacing, self.fg_color);
    y.* += 64;

    const str = try std.fmt.allocPrintZ(std.heap.page_allocator, "{s} {s} {s}", .{
        Options.opts.app_name,
        if (self.has_panicked) Options.opts.panic_message else Options.opts.error_message,
        if (self.has_panicked) "panic" else "error"
    });

    defer std.heap.page_allocator.free(str);

    rl.DrawTextEx(self.font, @ptrCast(str), .{
        .x = 30 + 128,
        .y = @floatFromInt(y.*),
    }, @floatFromInt(self.font_size), self.spacing, self.fg_color);
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

    var rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    const rn = rng.random();
    const index: usize = rn.intRangeAtMost(usize, 0, Options.opts.catch_phrases.len - 1);
    self.phrase_index = index;

    var panelRec: rl.Rectangle = .{ .x = 10, .y = 0, .width = @as(f32, @floatFromInt(rl.GetScreenWidth())) - 20, .height = 0 };

    var panelContentRec: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 };
    var panelView: rl.Rectangle  = .{ .x = 0, .y = 0, .width = 0, .height = 0 };
    var panelScroll: rl.Vector2 = .{ .x = 0, .y = 0, };

    var bg_color: u32 = 0;
    bg_color += @as(u32, @intCast(self.bg_color.r)) << 24;
    bg_color += @as(u32, @intCast(self.bg_color.g)) << 16;
    bg_color += @as(u32, @intCast(self.bg_color.b)) << 8;
    bg_color += self.bg_color.a;

    var fg_color: u32 = 0;
    fg_color += @as(u32, @intCast(self.fg_color.r)) << 24;
    fg_color += @as(u32, @intCast(self.fg_color.g)) << 16;
    fg_color += @as(u32, @intCast(self.fg_color.b)) << 8;
    fg_color += self.fg_color.a;

    var active_color: u32 = 0;
    active_color += @as(u32, @intCast(self.active_color.r)) << 24;
    active_color += @as(u32, @intCast(self.active_color.g)) << 16;
    active_color += @as(u32, @intCast(self.active_color.b)) << 8;
    active_color += self.active_color.a;

    rl.GuiSetStyle(rl.DEFAULT, rl.BACKGROUND_COLOR, @bitCast(bg_color));
    rl.GuiSetStyle(rl.DEFAULT, rl.TEXT_COLOR_NORMAL, @bitCast(fg_color));
    rl.GuiSetStyle(rl.DEFAULT, rl.TEXT_COLOR_FOCUSED, @bitCast(active_color));
    rl.GuiSetStyle(rl.DEFAULT, rl.TEXT_COLOR_PRESSED, @bitCast(active_color));

    rl.GuiSetStyle(rl.SLIDER, rl.BORDER + rl.STATE_FOCUSED * 3, @bitCast(active_color));
    rl.GuiSetStyle(rl.SLIDER, rl.BORDER + rl.STATE_PRESSED * 3, @bitCast(active_color));

    rl.GuiSetStyle(rl.DEFAULT, rl.BORDER_WIDTH, 0);
    rl.GuiSetStyle(rl.DEFAULT, rl.TEXT_SIZE, @intCast(self.font_size));
    rl.GuiSetFont(self.font);

    while (!rl.WindowShouldClose()) {
        var y: c_int = 20;

        rl.BeginDrawing();
        rl.ClearBackground(self.bg_color);

        if (texture) |tex| {
            rl.DrawTexture(tex, 10, y, rl.WHITE);
        }
        try self.drawTitle(&y);
        y = 128 + 32;

        // BUG: C and NUL missing
        rl.DrawTextEx(self.font, @ptrCast(self.msg), .{
            .x = 10,
            .y = @floatFromInt(y),
        }, @as(f32, @floatFromInt(self.font_size)) + 2, self.spacing, rl.RED);
        y += 32;
        rl.DrawTextEx(self.font, "Stack trace:", .{
            .x = 10,
            .y = @floatFromInt(y),
        }, @as(f32, @floatFromInt(self.font_size)) + 2, self.spacing, self.fg_color);
        y += 32;

        _ = rl.GuiCheckBox(.{
            .x = 10,
            .y = @floatFromInt(y),
            .width = 32,
            .height = 32,
        }, "Toggle Full Paths", &self.toggle_full_path);

        y += 36;
        panelRec.y = @floatFromInt(y);
        panelRec.height = @as(f32, @floatFromInt(rl.GetScreenHeight())) - panelRec.y - 10;

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

            const path_res = if (self.toggle_full_path) i.data.file_name else std.fs.path.basename(i.data.file_name);

            const str = try std.fmt.allocPrintZ(std.heap.page_allocator, "{s} at {}:{}", .{ path_res, i.data.line, i.data.column});
            defer std.heap.page_allocator.free(str);
            rl.DrawTextEx(self.font, @ptrCast(str), .{
                .x = 10 + panelScroll.x,
                .y = @floatFromInt(contentHeight)
            }, @as(f32, @floatFromInt(self.font_size)) - 2, self.spacing, self.fg_color);
            
            const w = rl.MeasureTextEx(self.font, @ptrCast(str), @as(f32, @floatFromInt(self.font_size)) - 2, self.spacing);

            if (w.x > @as(f32, @floatFromInt(contentWidth))) {
                contentWidth = @intFromFloat(w.x);
            }

            contentHeight += @intFromFloat(w.y);
        }
        contentHeight -= 30;

        panelContentRec.height = @as(f32, @floatFromInt(contentHeight));
        panelContentRec.width = @as(f32, @floatFromInt(contentWidth));

        rl.EndScissorMode();

        rl.EndDrawing();
    }

    rl.CloseWindow();
}
