const std = @import("std");
const builtin = @import("builtin");
const root = @import("root");
const StackTrace = @import("StackTrace.zig");
const Ui = @import("Ui.zig");
pub const Options = @import("Options.zig");

const native_os = builtin.os.tag;
const windows = std.os.windows;
const posix = std.posix;
const bad_main_ret = "expected return type of novaMain to be 'void', '!void', 'noreturn', 'u8', or '!u8'";

var in_panic: bool = false;

pub fn panic(fmt: []const u8, _: ?*std.builtin.StackTrace, return_addr: ?usize) noreturn {
    if (in_panic) {
        std.debug.print("DOUBLE PANIC {s}\n", .{fmt});
        std.process.abort();
    }

    in_panic = true;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    var tr = StackTrace.init(allocator);
    tr.populateCurrent(return_addr orelse @returnAddress()) catch {
        std.debug.defaultPanic(fmt, return_addr orelse @returnAddress());
    };

    const fmt_c = allocator.dupeZ(u8, fmt) catch {
        std.debug.defaultPanic(fmt, return_addr orelse @returnAddress());
    };

    var ui = Ui.init(fmt_c, &tr) catch {
        std.debug.defaultPanic(fmt, return_addr orelse @returnAddress());
    };
    ui.has_panicked = true;
    defer arena.reset(.free_all);
    defer ui.deinit();

    ui.draw() catch {
        std.debug.defaultPanic(fmt, return_addr orelse @returnAddress());
    };

    std.process.abort();
}

pub fn callMain() u8 {
    const ReturnType = @typeInfo(@TypeOf(root.novaMain)).@"fn".return_type.?;

    switch (ReturnType) {
        void => {
            root.novaMain();
            return 0;
        },
        noreturn, u8 => {
            return root.novaMain();
        },
        else => {
            if (@typeInfo(ReturnType) != .error_union) @compileError(bad_main_ret);

            const result = root.novaMain() catch |err| {
                if (builtin.zig_backend == .stage2_riscv64) {
                    std.debug.print("error: failed with error\n", .{});
                    return 1;
                }

                if (@errorReturnTrace()) |trace| {
                    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                    const allocator = arena.allocator();

                    var tr = StackTrace.init(allocator);
                    tr.populate(trace) catch {
                        std.debug.dumpStackTrace(trace.*);
                        return 1;
                    };

                    var ui = Ui.init(@errorName(err), &tr) catch {
                        std.debug.dumpStackTrace(trace.*);
                        return 1;
                    };
                    defer _ = arena.reset(.free_all);

                    ui.draw() catch {
                        std.debug.dumpStackTrace(trace.*);
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
