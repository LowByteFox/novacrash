const std = @import("std");
const rl = @import("raylib");
const rgui = @import("raygui");
const Options = @import("Options.zig");
const StackTrace = @import("StackTrace.zig");

const Ui = @This();

msg: [:0]const u8,
opts: *const Options,
font: rl.Font,
phrase_index: usize = 0,
trace: *StackTrace,
toggle_full_path: bool = false,
has_panicked: bool = false,
window: struct {
    width: i32 = 850,
    heitht: i32 = 600,
} = .{},

const WebhookPayload = struct {
    content: []const u8,
};

pub fn init(msg: [:0]const u8, trace: *StackTrace) !Ui {
    const opts = Options.opts;

    if (opts.extra.using_raylib) {
        rl.closeWindow();
    }

    rl.setTraceLogLevel(rl.TraceLogLevel.err);

    const w_height = opts.extra.window.height;
    const w_width = opts.extra.window.width;

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(w_width, w_height, opts.extra.window.title);
    if (!rl.isWindowReady())
        return error.RaylibNotReady;

    rl.setTargetFPS(60);

    return .{
        .msg = msg,
        .trace = trace,
        .font = brk: {
            if (opts.extra.theme.font) |font| {
                const f = try rl.loadFontFromMemory(".ttf", font,
                    @as(i32, @intFromFloat(opts.extra.header.title_size)),
                    null);

                rl.setTextureFilter(f.texture, rl.TextureFilter.trilinear);
                break :brk f;
            }
            break :brk try rl.getFontDefault();
        },
        .opts = opts,
    };
}

pub fn draw(self: *Ui) !void {
    const texture: ?rl.Texture = brk: {
        const img_buf: ?[]const u8 = img_brk: {
            if (self.has_panicked) {
                if (self.opts.extra.header.crash_icon) |img| {
                    break :img_brk img;
                }
            } else {
                if (self.opts.extra.header.error_icon) |img| {
                    break :img_brk img;
                }
            }
            break :img_brk null;
        };

        if (img_buf) |img| {
            var image = try rl.loadImageFromMemory(".png", img);
            defer rl.unloadImage(image);
            rl.imageResize(&image,
                @as(i32, @intFromFloat(self.opts.extra.header.icon_size.x)),
                @as(i32, @intFromFloat(self.opts.extra.header.icon_size.y)));

            break :brk try image.toTexture();
        }
        break :brk null;
    };

    var rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    const rn = rng.random();
    self.phrase_index = rn.intRangeAtMost(usize, 0,
        self.opts.extra.header.catch_phrases.len - 1);

    var panel_rec: rl.Rectangle = .{ .x = 10, .y = 0, .width = @as(f32, @floatFromInt(rl.getScreenWidth())) - 20, .height = 0 };

    var content_rec: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 };
    var panel_scroll: rl.Vector2 = .{ .x = 0, .y = 0, };
    var panel_view: rl.Rectangle  = .{ .x = 0, .y = 0, .width = 0, .height = 0 };

    const bg_color = rl.colorToInt(self.opts.extra.theme.background);
    const fg_color = rl.colorToInt(self.opts.extra.theme.foreground);
    const ambient_color = rl.colorToInt(self.opts.extra.theme.ambient);

    rgui.setStyle(.default, .{ .default = .background_color }, bg_color);
    rgui.setStyle(.default, .{ .control = .text_color_normal }, fg_color);
    rgui.setStyle(.default, .{ .control = .text_color_focused }, ambient_color);
    rgui.setStyle(.default, .{ .control = .text_color_pressed }, ambient_color);
    rgui.setStyle(.default, .{ .control = .border_color_normal }, fg_color);
    rgui.setStyle(.default, .{ .control = .border_color_pressed }, fg_color);
    rgui.setStyle(.default, .{ .control = .border_color_focused }, fg_color);
    rgui.setStyle(.default, .{ .default = .line_color}, fg_color);

    rgui.setStyle(.button, .{ .control = .text_color_focused }, bg_color);
    rgui.setStyle(.button, .{ .control = .base_color_normal }, bg_color);
    rgui.setStyle(.button, .{ .control = .base_color_focused }, fg_color);
    rgui.setStyle(.button, .{ .control = .base_color_pressed }, fg_color);

    rgui.setStyle(.slider, .{ .control = .border_color_normal }, ambient_color);
    rgui.setStyle(.slider, .{ .control = .border_color_focused }, ambient_color);
    rgui.setStyle(.slider, .{ .control = .border_color_pressed }, ambient_color);

    rgui.setStyle(.scrollbar, .{ .default = .background_color }, ambient_color);

    rgui.setStyle(.statusbar, .{ .control = .base_color_normal }, bg_color);

    rgui.setStyle(.checkbox, .{ .control = .border_color_normal }, fg_color);
    rgui.setStyle(.checkbox, .{ .control = .border_color_focused }, ambient_color);
    rgui.setStyle(.checkbox, .{ .control = .border_color_pressed }, ambient_color);
    rgui.setStyle(.checkbox, .{ .control = .text_alignment }, @intFromEnum(rgui.TextAlignment.center));

    rgui.setStyle(.default, .{ .control = .border_width }, 0);
    rgui.setStyle(.default, .{ .default = .text_size},
        @as(i32, @intFromFloat(self.opts.extra.theme.font_size)));

    rgui.setFont(self.font);

    const allocator = std.heap.page_allocator;

    var show_msg_box: bool = false;
    var end: bool = false;

    while (!rl.windowShouldClose() and !end) {
        rl.beginDrawing();
        rl.clearBackground(self.opts.extra.theme.background);
        self.window.width = rl.getScreenWidth();
        self.window.heitht = rl.getScreenHeight();

        var y: f32 = try self.drawTitle(texture);
        rl.drawLineEx(.{
            .x = self.opts.extra.theme.padding,
            .y = y,
        }, .{
            .x = @as(f32, @floatFromInt(self.window.width)) - self.opts.extra.theme.padding,
            .y = y,
        }, 2, self.opts.extra.theme.foreground);
        y += self.opts.extra.theme.padding;

        const width: f32 = @as(f32, @floatFromInt(self.window.width)) - self.opts.extra.theme.padding * 2;

        rgui.setStyle(.default, .{ .control = .text_color_normal }, ambient_color);
        _ = rgui.label(.{
            .x = self.opts.extra.theme.padding,
            .y = y,
            .height = self.opts.extra.theme.font_size,
            .width = width,
        }, self.msg);
        rgui.setStyle(.default, .{ .control = .text_color_normal }, fg_color);

        y += self.opts.extra.theme.font_size + self.opts.extra.theme.padding;
        _ = rgui.label(.{
            .x = self.opts.extra.theme.padding,
            .y = y,
            .height = self.opts.extra.theme.font_size,
            .width = width,
        }, "Options:");
        y += self.opts.extra.theme.font_size + self.opts.extra.theme.padding;

        rgui.setStyle(.default, .{ .control = .border_width }, 2);
        _ = rgui.checkBox(.{
            .x = self.opts.extra.theme.padding,
            .y = y,
            .height = self.opts.extra.theme.font_size,
            .width = self.opts.extra.theme.font_size,
        }, "Enable full trace paths", &self.toggle_full_path);
        rgui.setStyle(.default, .{ .control = .border_width }, 0);
        y += self.opts.extra.theme.font_size + self.opts.extra.theme.padding;

        _ = rgui.label(.{
            .x = self.opts.extra.theme.padding,
            .y = y,
            .height = self.opts.extra.theme.font_size,
            .width = width,
        }, "Stack Trace:");
        y += self.opts.extra.theme.font_size + self.opts.extra.theme.padding / 2;

        rl.drawRectangleLinesEx(.{
            .x = self.opts.extra.theme.padding,
            .y = y,
            .width = width,
            .height = self.opts.extra.theme.font_size + 4,
        }, 2, self.opts.extra.theme.foreground);

        y += 2;

        const width_forth = width / 3.5;

        _ = rgui.label(.{
            .x = self.opts.extra.theme.padding + 4,
            .y = y,
            .height = self.opts.extra.theme.font_size,
            .width = width_forth / 2,
        }, "Line");

        _ = rgui.label(.{
            .x = self.opts.extra.theme.padding + 4 + width_forth / 2,
            .y = y,
            .height = self.opts.extra.theme.font_size,
            .width = width_forth / 2,
        }, "Column");

        _ = rgui.label(.{
            .x = self.opts.extra.theme.padding + width_forth + 4,
            .y = y,
            .height = self.opts.extra.theme.font_size,
            .width = width - width_forth,
        }, "File");
        y += self.opts.extra.theme.font_size;

        panel_rec.y = y;
        panel_rec.height = @as(f32, @floatFromInt(self.window.heitht)) - panel_rec.y - self.opts.extra.theme.padding;
        if (self.opts.extra.webhook_url != null)
            panel_rec.height -= self.opts.extra.theme.font_size * 2 + self.opts.extra.theme.padding;

        panel_rec.width = @as(f32, @floatFromInt(self.window.width)) - self.opts.extra.theme.padding * 2;

        rgui.setStyle(.default, .{ .control = .border_width }, 2);
        _ = rgui.scrollPanel(panel_rec, null, content_rec, &panel_scroll, &panel_view);
        rgui.setStyle(.default, .{ .control = .border_width }, 0);
        rl.beginScissorMode(@intFromFloat(panel_view.x), @intFromFloat(panel_view.y),
            @intFromFloat(panel_view.width), @intFromFloat(panel_view.height));

        var content_height: f32 = y;
        var content_width: f32 = 0;

        var iter = self.trace.trace.first;

        while (iter) |i| : (iter = i.next) {
            if (std.mem.eql(u8, i.data.file_name, "???")) {
                continue;
            }

            const path = if (self.toggle_full_path) i.data.file_name else std.fs.path.basename(i.data.file_name);

            var str = try std.fmt.allocPrintZ(allocator, "{}", .{i.data.line});
            _ = rgui.label(.{
                .x = self.opts.extra.theme.padding + panel_scroll.x + 4,
                .y = content_height + 4 + panel_scroll.y,
                .height = self.opts.extra.theme.font_size,
                .width = width_forth / 2,
            }, str);
            allocator.free(str);

            str = try std.fmt.allocPrintZ(allocator, "{}", .{i.data.column});
            _ = rgui.label(.{
                .x = self.opts.extra.theme.padding + panel_scroll.x + 4 + width_forth / 2,
                .y = content_height + 4 + panel_scroll.y,
                .height = self.opts.extra.theme.font_size,
                .width = width_forth,
            }, str);
            allocator.free(str);

            str = try std.fmt.allocPrintZ(allocator, "{s}", .{path});
            defer allocator.free(str);

            rl.drawTextEx(self.font, str, .{
                .x = self.opts.extra.theme.padding + panel_scroll.x + 4 + width_forth,
                .y = content_height + 4 + panel_scroll.y,
            }, self.opts.extra.theme.font_size, self.opts.extra.theme.spacing,
                self.opts.extra.theme.foreground);

            const w = rl.measureTextEx(self.font, str, self.opts.extra.theme.font_size,
                self.opts.extra.theme.spacing);

            if (w.x + width_forth > content_width) {
                content_width = w.x + 8 + width_forth;
            }

            content_height += w.y;
        }

        content_rec.height = content_height - y + 8;
        content_rec.width = content_width;

        rl.endScissorMode();

        rgui.setStyle(.default, .{ .control = .border_width }, 2);
        if (self.opts.extra.webhook_url) |url| {
            if (rgui.button(.{
                .x = self.opts.extra.theme.padding,
                .y = @as(f32, @floatFromInt(self.window.heitht)) - 
                    self.opts.extra.theme.font_size * 2 - self.opts.extra.theme.padding,
                .height = self.opts.extra.theme.font_size * 2,
                .width = width,
            }, "Send crash report") and !show_msg_box) {

                show_msg_box = true;

                var hook_client = std.http.Client {
                    .allocator = allocator,
                };

                var buffer = try std.fmt.allocPrint(std.heap.page_allocator, "{s} {s} {s}\n\n", .{
                    self.opts.app_name,
                    if (self.has_panicked) self.opts.panic_message else self.opts.error_message,
                    if (self.has_panicked) "panic" else "error"
                });

                iter = self.trace.trace.first;

                while (iter) |i| : (iter = i.next) {
                    buffer = try std.fmt.allocPrint(allocator, "{s}{}:{} at {s}\n",
                        .{buffer, i.data.line, i.data.column, i.data.file_name});
                }

                _ = try hook_client.fetch(.{
                    .method = .POST,
                    .location = .{
                        .url = url,
                    },
                    .payload = try std.json.stringifyAlloc(allocator, WebhookPayload{
                            .content = buffer,
                        }, .{}),
                    .headers = .{
                        .content_type = .{ .override = "application/json" }
                    }
                });
            }
        }

        if (show_msg_box) {
            const msg_box_width = width / 1.5;
            const msg_box_height: f32 = 250;
            if (rgui.messageBox(.{
                .x = width / 2 - msg_box_width / 2,
                .y = @as(f32, @floatFromInt(self.window.heitht)) / 2 - msg_box_height / 2,
                .height = msg_box_height,
                .width = msg_box_width,
            }, "#191#Send crash", "Crash report sent successfully!", "Ok;Cancel") >= 0) {
                show_msg_box = false;
                end = true;
            }
        }
        rgui.setStyle(.default, .{ .control = .border_width }, 0);

        rl.endDrawing();
    }

    rl.closeWindow();
}

fn drawTitle(self: *Ui, icon: ?rl.Texture) !f32 {
    const width: f32 = @as(f32, @floatFromInt(self.window.width)) - 
        self.opts.extra.theme.padding * 2;
    if (icon) |ic| {
        rl.drawTexture(ic,
            @as(i32, @intFromFloat(self.opts.extra.theme.padding)),
            @as(i32, @intFromFloat(self.opts.extra.theme.padding)), rl.Color.white);
    }

    var y: f32 = self.opts.extra.theme.padding;
    var x: f32 = self.opts.extra.theme.padding + self.opts.extra.header.icon_size.x;
    x += self.opts.extra.theme.padding;

    const phrase = self.opts.extra.header.catch_phrases[self.phrase_index];

    const prev_height = rgui.getStyle(.default, .{ .default = .text_size });
    rgui.setStyle(.default, .{ .default = .text_size },
        @intFromFloat(self.opts.extra.header.title_size));

    _ = rgui.label(.{
        .x = x,
        .y = y,
        .height = self.opts.extra.header.title_size,
        .width = width - self.opts.extra.header.icon_size.x,
    }, phrase);

    rgui.setStyle(.default, .{ .default = .text_size }, prev_height);

    y += rl.measureTextEx(self.font, phrase, self.opts.extra.header.title_size,
        self.opts.extra.theme.padding).y;

    const str = try std.fmt.allocPrintZ(std.heap.page_allocator, "{s} {s} {s}", .{
        self.opts.app_name,
        if (self.has_panicked) self.opts.panic_message else self.opts.error_message,
        if (self.has_panicked) "panic" else "error"
    });
    defer std.heap.page_allocator.free(str);

    _ = rgui.label(.{
        .x = x,
        .y = y,
        .height = self.opts.extra.header.title_size,
        .width = width - self.opts.extra.header.icon_size.x,
    }, str);

    return self.opts.extra.header.icon_size.y + self.opts.extra.theme.padding * 2;
}
