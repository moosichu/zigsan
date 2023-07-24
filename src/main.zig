const std = @import("std");
const testing = std.testing;
const ubsan = @import("ubsan.zig");

fn ExpectUbsanError(comptime expected_error: []const u8) *const fn (error_msg: []const u8) void {
    const CustomErrorHandler = struct {
        fn custom_error_handler(error_msg: []const u8) void {
            testing.expectEqualStrings(expected_error ++ "\n", error_msg[0 .. expected_error.len + 1]) catch unreachable;
            testing.expect(std.mem.containsAtLeast(u8, error_msg, 1, "ubsan_c_tests.c")) catch unreachable;
        }
    };
    return CustomErrorHandler.custom_error_handler;
}

test "addition overflow" {
    const expected_error: []const u8 = "ubsan: Addition Overflow: 2147483647 + 1 in type 'int'";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    const ubsan_c_tests = @cImport(@cInclude("testing/ubsan_c_tests.h"));
    ubsan_c_tests.addition_overflow();
}

test "subtraction overflow" {
    const expected_error: []const u8 = "ubsan: Subtraction Overflow: -2147483648 - 1 in type 'int'";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    const ubsan_c_tests = @cImport(@cInclude("testing/ubsan_c_tests.h"));
    ubsan_c_tests.subtraction_overflow();
}

test "multiplication overflow" {
    const expected_error: []const u8 = "ubsan: Multiplication Overflow: 2147483647 * 2 in type 'int'";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    const ubsan_c_tests = @cImport(@cInclude("testing/ubsan_c_tests.h"));
    ubsan_c_tests.multiplication_overflow();
}

test "negation overflow" {
    const expected_error: []const u8 = "ubsan: Negation of -2147483648 cannot be represented in type 'int32_t' (aka 'int')";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    const ubsan_c_tests = @cImport(@cInclude("testing/ubsan_c_tests.h"));
    ubsan_c_tests.negation_overflow();
}

test "division overflow" {
    const expected_error: []const u8 = "ubsan: Division of -2147483648 by -1 cannot be represented in type 'int'";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    const ubsan_c_tests = @cImport(@cInclude("testing/ubsan_c_tests.h"));
    ubsan_c_tests.division_overflow();
}

test "division by 0" {
    const expected_error: []const u8 = "ubsan: Division by 0";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    const ubsan_c_tests = @cImport(@cInclude("testing/ubsan_c_tests.h"));
    ubsan_c_tests.division_by_0();
}

test "shift by negative" {
    const expected_error: []const u8 = "ubsan: Shift exponent -1 is negative";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    const ubsan_c_tests = @cImport(@cInclude("testing/ubsan_c_tests.h"));
    ubsan_c_tests.shift_by_negative();
}

test "shift out of bounds" {
    const expected_error: []const u8 = "ubsan: Shift exponent 33 is too large for 32-bit type 'int32_t' (aka 'int')";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    const ubsan_c_tests = @cImport(@cInclude("testing/ubsan_c_tests.h"));
    ubsan_c_tests.shift_out_of_bounds();
}

test "shift out of bounds 2" {
    const expected_error: []const u8 = "ubsan: Left shift of 4 by 31 cannot be represented by a 'int32_t' (aka 'int')";
    ubsan.setCustomRecoverHandler(ExpectUbsanError(expected_error));
    const ubsan_c_tests = @cImport(@cInclude("testing/ubsan_c_tests.h"));
    ubsan_c_tests.shift_out_of_bounds_2();
}

// test "array out of bounds" {
//     const expected_error: []const u8 = "";
//     setCustomRecoverHandler(ExpectUbsanError(expected_error));
//     const ubsan_c_tests = @cImport(@cInclude("testing/ubsan_c_tests.h"));
//     ubsan_c_tests.array_out_of_bounds();
// }
