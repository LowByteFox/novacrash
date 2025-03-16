const std = @import("std");
const rl = @import("raylib");
const StackTrace = @import("StackTrace.zig");

const Ui = @This();
const icon_img = @embedFile("./dead.png");

msg: []const u8,
trace: *StackTrace,

pub fn init(using_raylib: bool, msg: []const u8, trace: *StackTrace) Ui {
    if (using_raylib) {
        rl.CloseWindow();
    }

    rl.SetTraceLogLevel(rl.LOG_ERROR);

    const w_height = 750;
    const w_width = 500;

    rl.InitWindow(w_width, w_height, "Novacrash report!");
    rl.SetTargetFPS(60);

    return .{
        .msg = msg,
        .trace = trace
    };
}

pub fn deinit(_: *Ui) void {
    rl.CloseWindow();
}

fn draw_title(_: *Ui, y: *c_int) void {
    rl.DrawText("Weh!", 30 + 128, y.*, 64, rl.WHITE);
    y.* += 64;

    rl.DrawText("Your app has reached panic!", 30 + 128, y.*, 22, rl.RAYWHITE);
}

pub fn draw(self: *Ui) !void {
    var img = rl.LoadImageFromMemory(".png", icon_img, icon_img.len);
    rl.ImageResize(&img, 128, 128);

    const texture = rl.LoadTextureFromImage(img);
    rl.UnloadImage(img);

    var panelRec: rl.Rectangle = .{ .x = 10, .y = 128 + 50 + 10, .width = @as(f32, @floatFromInt(rl.GetScreenWidth())) - 20, .height = 0 };
    panelRec.height = @as(f32, @floatFromInt(rl.GetScreenHeight())) - panelRec.y - 10;

    var panelContentRec: rl.Rectangle = .{ .x = 0, .y = 0, .width = 0, .height = 0 };
    var panelView: rl.Rectangle  = .{ .x = 0, .y = 0, .width = 0, .height = 0 };
    var panelScroll: rl.Vector2 = .{ .x = 0, .y = 0, };

    rl.GuiSetStyle(rl.DEFAULT, rl.BACKGROUND_COLOR, 0x161616FF);
    rl.GuiSetStyle(rl.DEFAULT, rl.BORDER_WIDTH, 0);

    while (!rl.WindowShouldClose()) {
        var y: c_int = 20;

        rl.BeginDrawing();
        rl.ClearBackground(.{
            .r = 0x16,
            .g = 0x16,
            .b = 0x16,
            .a = 0xFF,
        });

        rl.DrawTexture(texture, 10, y, rl.WHITE);
        self.draw_title(&y);
        y = 128 + 30;
        rl.DrawText("Stack trace:", 10, y, 24, rl.WHITE);

        _ = rl.GuiScrollPanel(panelRec, null, panelContentRec, &panelScroll, &panelView);

        rl.BeginScissorMode(@as(c_int, @intFromFloat(panelView.x)),
            @as(c_int, @intFromFloat(panelView.y)),
            @as(c_int, @intFromFloat(panelView.width)),
            @as(c_int, @intFromFloat(panelView.height)));

        var contentHeight: u32 = @as(u32, @intFromFloat(panelView.y));
        var contentWidth: u32 = 0;

        rl.DrawRectangle(0, @intCast(contentHeight), @as(c_int, @intFromFloat(panelContentRec.width)), rl.GetScreenHeight(), .{
            .r = 0x16,
            .g = 0x16,
            .b = 0x16,
            .a = 0xFF,
        });

        var iter = self.trace.trace.first;

        while (iter) |i| : (iter = i.next) {
            if (std.mem.eql(u8, i.data.file_name, "???")) {
                continue;
            }

            const str = try std.fmt.allocPrint(std.heap.page_allocator, "{s} at {}:{}", .{i.data.file_name, i.data.line, i.data.column});
            defer std.heap.page_allocator.free(str);
            rl.DrawText(@ptrCast(str), 10 + @as(c_int, @intFromFloat(panelScroll.x)), @intCast(contentHeight), 20, rl.WHITE);
            
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
