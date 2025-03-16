const std = @import("std");
const novacrash = @import("novacrash");

pub fn nova_main() !void {
    return error.ManualError;
}

pub const main = novacrash.callMain;
pub const panic = novacrash.panic;
