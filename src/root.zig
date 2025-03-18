const std = @import("std");
const builtin = @import("builtin");
const root = @import("root");
const StackTrace = @import("StackTrace.zig");
const Ui = @import("Ui.zig");
pub const Options = @import("Options.zig");

const native_os = builtin.os.tag;
const windows = std.os.windows;
const posix = std.posix;
const bad_main_ret = "expected return type of nova_main to be 'void', '!void', 'noreturn', 'u8', or '!u8'";

var in_panic: bool = false;

pub fn panic(fmt: []const u8, _: ?*std.builtin.StackTrace, return_addr: ?usize) noreturn {
    if (in_panic) {
        std.debug.print("DOUBLE PANICKED {s}\n", .{fmt});
        std.process.abort();
    }

    in_panic = true;

    // if (builtin.single_threaded) {
    //     std.debug.print("panic: ", .{}) catch posix.abort();
    // } else {
    //     const current_thread_id = std.Thread.getCurrentId();
    //     std.debug.print("thread {} panic: ", .{current_thread_id});
    // }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    var tr = StackTrace.init(allocator);
    tr.populateCurrent(return_addr orelse @returnAddress()) catch |err| {
        std.log.err("{s}", .{@errorName(err)});
        std.process.abort();
    };

    var ui = Ui.init(fmt, &tr);
    ui.has_panicked = true;
    defer arena.reset(.free_all);
    defer ui.deinit();

    ui.draw() catch std.process.abort();

    std.process.abort();
}

pub fn callMain() u8 {
    const ReturnType = @typeInfo(@TypeOf(root.nova_main)).@"fn".return_type.?;

    switch (ReturnType) {
        void => {
            root.nova_main();
            return 0;
        },
        noreturn, u8 => {
            return root.nova_main();
        },
        else => {
            if (@typeInfo(ReturnType) != .error_union) @compileError(bad_main_ret);

            const result = root.nova_main() catch |err| {
                if (builtin.zig_backend == .stage2_riscv64) {
                    std.debug.print("error: failed with error\n", .{});
                    return 1;
                }

                if (@errorReturnTrace()) |trace| {
                    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                    const allocator = arena.allocator();

                    var tr = StackTrace.init(allocator);
                    tr.populate(trace) catch |err2| {
                        std.log.err("{s}", .{@errorName(err2)});
                        return 1;
                    };

                    var ui = Ui.init(@errorName(err), &tr);
                    defer _ = arena.reset(.free_all);
                    defer ui.deinit();

                    ui.draw() catch |err2| {
                        std.log.err("{s}", .{@errorName(err2)});
                        return 1;
                    };
                }
                return 1;
            };

            return switch (@TypeOf(result)) {
                void => 0,
                u8 => result,
                else => @compileError(bad_main_ret),
            };
        },
    }
}
