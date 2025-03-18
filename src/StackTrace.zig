const std = @import("std");
const builtin = @import("builtin");

const native_os = builtin.os.tag;
const windows = std.os.windows;
const posix = std.posix;
const ThreadContext = std.debug.ThreadContext;

const StackTrace = @This();
const List = std.DoublyLinkedList(std.debug.SourceLocation);
const Node = List.Node;

allocator: std.mem.Allocator,
trace: List,
dropped_stack_frames: usize,

pub fn init(allocator: std.mem.Allocator) StackTrace {
    return .{
        .allocator = allocator,
        .trace = List{},
        .dropped_stack_frames = 0,
    };
}

fn addTrace(self: *StackTrace, line: u64, col: u64, filename: []const u8) !void {
    var node = try self.allocator.create(Node);
    node.data.column = col;
    node.data.line = line;
    node.data.file_name = filename;

    self.trace.append(node);
}

pub fn populateCurrent(self: *StackTrace, start_addr: usize) !void {
    if (builtin.strip_debug_info) return error.MissingDebugInfo;

    const debug_info = std.debug.getSelfDebugInfo() catch |err| {
        std.debug.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)});
        return;
    };

    if (native_os == .windows) {
        var context: ThreadContext = undefined;
        std.debug.assert(std.debug.getContext(&context));

        var addr_buf: [1024]usize = undefined;
        const n = std.debug.walkStackWindows(addr_buf[0..], &context);
        const addrs = addr_buf[0..n];
        const start_i: usize = blk: {
            for (addrs, 0..) |addr, i| {
                if (addr == start_addr) break :blk i;
            }
            return;
        };

        for (addrs[start_i..]) |addr| {
            try self.populateAddress(debug_info, addr - 1);
        }

        return;
    }

    var context: ThreadContext = undefined;
    const has_context = std.debug.getContext(&context);

    var it = (if (has_context) blk: {
        break :blk std.debug.StackIterator.initWithContext(start_addr, debug_info, &context) catch null;
    } else null) orelse std.debug.StackIterator.init(start_addr, null);
    defer it.deinit();

    while (it.next()) |return_address| {
        const address = return_address -| 1;
        try self.populateAddress(debug_info, address);
    }
}

fn populateAddress(self: *StackTrace, debug_info: *std.debug.SelfInfo, address: usize) !void {
    const module = debug_info.getModuleForAddress(address) catch |err| switch (err) {
        error.MissingDebugInfo, error.InvalidDebugInfo => {
            try self.addTrace(0, 0, "???");
            return;
        },
        else => return err,
    };

    const symbol_info = module.getSymbolAtAddress(debug_info.allocator, address) catch |err| switch (err) {
        error.MissingDebugInfo, error.InvalidDebugInfo => {
            try self.addTrace(0, 0, "???");
            return;
        },
        else => return err,
    };

    if (symbol_info.source_location) |loc| {
        try self.addTrace(loc.line, loc.column, loc.file_name);
    } else {
        try self.addTrace(0, 0, "???");
    }
}

pub fn populate(self: *StackTrace, trace: *std.builtin.StackTrace) !void {
    if (builtin.strip_debug_info) return error.MissingDebugInfo;

    const debug_info = std.debug.getSelfDebugInfo() catch |err| {
        std.debug.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)});
        return;
    };

    var frame_index: usize = 0;
    var frames_left: usize = @min(trace.index, trace.instruction_addresses.len);

    while (frames_left != 0) : ({
        frames_left -= 1;
        frame_index = (frame_index + 1) % trace.instruction_addresses.len;
    }) {
        const return_address = trace.instruction_addresses[frame_index];
        try self.populateAddress(debug_info, return_address - 1);
    }

    if (trace.index > trace.instruction_addresses.len) {
        self.dropped_stack_frames = trace.index - trace.instruction_addresses.len;
    }
}
