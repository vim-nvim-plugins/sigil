const std = @import("std");
const limit: u32 = 3;
fn scale(value: u32, factor: u32) u32 {
    var total = value * factor;
    var i: u32 = 0;
    while (i < limit) : (i += 1) total += i;
    return total;
}
fn twice(value: u32) u32 {
    const total = value * 2; // total in a comment
    return total;
}
pub fn main() void {
    std.debug.print("total limit {}\n", .{scale(limit, 2)});
}
