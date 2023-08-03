const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const ubsan = @import("ubsan.zig");
const ubsan_c_tests = @cImport(@cInclude("testing/ubsan_tests.h"));

fn ExpectUbsanError(comptime expected_error: []const u8) *const fn (error_msg: []const u8) void {
    const CustomErrorHandler = struct {
        fn custom_error_handler(error_msg: []const u8) void {
            if (error_msg.len < expected_error.len + 1) {
                @panic(error_msg);
            }
            testing.expectEqualStrings(expected_error ++ "\n", error_msg[0 .. expected_error.len + 1]) catch unreachable;
            testing.expect(std.mem.containsAtLeast(u8, error_msg, 1, "ubsan_tests.c")) catch unreachable;
        }
    };
    return CustomErrorHandler.custom_error_handler;
}

test "addition overflow" {
    const expected_error: []const u8 = "ubsan: Addition Overflow: 2147483647 + 1 in type 'int'";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    ubsan_c_tests.addition_overflow();
}

test "subtraction overflow" {
    const expected_error: []const u8 = "ubsan: Subtraction Overflow: -2147483648 - 1 in type 'int'";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    ubsan_c_tests.subtraction_overflow();
}

test "multiplication overflow" {
    const expected_error: []const u8 = "ubsan: Multiplication Overflow: 2147483647 * 2 in type 'int'";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    ubsan_c_tests.multiplication_overflow();
}

test "negation overflow" {
    const expected_error: []const u8 = "ubsan: Negation of -2147483648 cannot be represented in type 'int32_t' (aka 'int')";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    ubsan_c_tests.negation_overflow();
}

test "division overflow" {
    const expected_error: []const u8 = "ubsan: Division of -2147483648 by -1 cannot be represented in type 'int'";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    ubsan_c_tests.division_overflow();
}

test "division by 0" {
    const expected_error: []const u8 = "ubsan: Division by 0";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    ubsan_c_tests.division_by_0();
}

test "shift by negative" {
    const expected_error: []const u8 = "ubsan: Shift exponent -1 is negative";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    ubsan_c_tests.shift_by_negative();
}

test "shift out of bounds" {
    const expected_error: []const u8 = "ubsan: Shift exponent 33 is too large for 32-bit type 'int32_t' (aka 'int')";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    ubsan_c_tests.shift_out_of_bounds();
}

test "shift out of bounds 2" {
    const expected_error: []const u8 = "ubsan: Left shift of 4 by 31 cannot be represented by a 'int32_t' (aka 'int')";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    ubsan_c_tests.shift_out_of_bounds_2();
}

test "array out of bounds" {
    const expected_error: []const u8 = "ubsan: Index 1 out of bounds for type 'int32_t[1]' (aka 'int[1]')";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    ubsan_c_tests.array_out_of_bounds();
}

// TODO: Currently segfaults! Need a panic handler for this!
// test "builtin unreachable" {
//     const expected_error: []const u8 = "ubsan: Reached an unreachable location";
//     ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
//
//     ubsan_c_tests.builtin_unreachable();
// }

test "f16 cast overflow" {
    const expected_error: []const u8 = "ubsan: The '_Float16' value 6.5504e+04 is out of range for the type 'short'";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    ubsan_c_tests.f16_cast_overflow();
}

test "f32 cast overflow" {
    const expected_error: []const u8 = "ubsan: The 'float' value 3.4028234663852886e+38 is out of range for the type 'int'";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    ubsan_c_tests.f32_cast_overflow();
}

test "f64 cast overflow" {
    const expected_error: []const u8 = "ubsan: The 'double' value 3.4028234663852886e+38 is out of range for the type 'long long'";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    ubsan_c_tests.f64_cast_overflow();
}

test "f80 cast overflow" {
    if (builtin.cpu.arch.isX86()) {
        const expected_error: []const u8 = "The 'long double' value 3.4028234663852886e+38 is out of range for the type 'long long'";
        ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
        ubsan_c_tests.f80_cast_overflow();
    }
}

// test "function type mismatch" {
//     const expected_error: []const u8 = "";
//     _ = expected_error;
//     // setCustomRecoverHandler(ExpectUbsanError(expected_error));
//
//     ubsan_c_tests.function_type_mismatch();
// }

// C++ only errors
// TODO: Currently segfaults! Need a panic handler for this!
// test "empty return" {
//     const expected_error: []const u8 = "ubsan: Reached the end of value-returning function without returning a value";
//     ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
//     _ = ubsan_c_tests.empty_return();
// }
