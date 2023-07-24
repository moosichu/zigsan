const builtin = @import("builtin");
const std = @import("std");
const ubsan_value = @import("ubsan_value.zig");

extern fn cppCheckTypeInfoEquality(typeInfo1: *anyopaque, typeInfo2: *anyopaque) callconv(.C) bool;

pub fn checkTypeInfoEquality(typeInfo1: ubsan_value.ValueHandle, typeInfo2: ubsan_value.ValueHandle) bool {
    // Windows implementation of this always returns false
    if (comptime builtin.target.os.tag == .windows) {
        return false;
    }

    return cppCheckTypeInfoEquality(typeInfo1, typeInfo2);
}
