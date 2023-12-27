const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const ubsan = @import("ubsan.zig");
const ubsan_tests = @cImport(@cInclude("testing/ubsan_tests.h"));

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

// TODO: Tests for different ubsan options when compiling the c file maybe? So have to compile in-place?
// (then can have panic handlers for launching process) - can look at the zar implementation for examples of this!

test "addition overflow" {
    const expected_error: []const u8 = "ubsan: Addition Overflow: 2147483647 + 1 in type 'int'";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.additionOverflow();
}

test "subtraction overflow" {
    const expected_error: []const u8 = "ubsan: Subtraction Overflow: -2147483648 - 1 in type 'int'";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.subtractionOverflow();
}

test "multiplication overflow" {
    const expected_error: []const u8 = "ubsan: Multiplication Overflow: 2147483647 * 2 in type 'int'";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.multiplicationOverflow();
}

test "negation overflow" {
    const expected_error: []const u8 = "ubsan: Negation of -2147483648 cannot be represented in type 'int32_t' (aka 'int')";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.negationOverflow();
}

test "division overflow" {
    const expected_error: []const u8 = "ubsan: Division of -2147483648 by -1 cannot be represented in type 'int'";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.divisionOverflow();
}

test "division by 0" {
    const expected_error: []const u8 = "ubsan: Division by 0";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.divisionBy0();
}

test "shift by negative" {
    const expected_error: []const u8 = "ubsan: Shift exponent -1 is negative";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.shiftByNegative();
}

test "shift out of bounds" {
    const expected_error: []const u8 = "ubsan: Shift exponent 33 is too large for 32-bit type 'int32_t' (aka 'int')";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.shiftOutOfBounds();
}

test "shift out of bounds 2" {
    const expected_error: []const u8 = "ubsan: Left shift of 4 by 31 cannot be represented by a 'int32_t' (aka 'int')";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.shiftOutOfBounds2();
}

// TODO: Currently segfaults! Need a panic handler for this!
// test "array out of bounds" {
//     const expected_error: []const u8 = "ubsan: Index 1 out of bounds for type 'int32_t[1]' (aka 'int[1]')";
//     ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
//     ubsan_tests.arrayOutOfBounds();
// }

// TODO: Currently segfaults! Need a panic handler for this!
// test "builtin unreachable" {
//     const expected_error: []const u8 = "ubsan: Reached an unreachable location";
//     ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
//
//     ubsan_tests.builtinUnreachable();
// }

test "f16 cast overflow" {
    const expected_error: []const u8 = "ubsan: The '_Float16' value 6.5504e+04 is out of range for the type 'short'";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.f16CastOverflow();
}

test "f32 cast overflow" {
    const expected_error: []const u8 = "ubsan: The 'float' value 3.4028234663852886e+38 is out of range for the type 'int'";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.f32CastOverflow();
}

test "f64 cast overflow" {
    const expected_error: []const u8 = "ubsan: The 'double' value 3.4028234663852886e+38 is out of range for the type 'long long'";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.f64CastOverflow();
}

test "f80 cast overflow" {
    if (builtin.cpu.arch.isX86()) {
        const expected_error: []const u8 = "The 'long double' value 3.4028234663852886e+38 is out of range for the type 'long long'";
        ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
        ubsan_tests.f80CastOverflow();
    }
}

// test "alignment assumption" {
//     const expected_error: []const u8 = "The 'long double' value 3.4028234663852886e+38 is out of range for the type 'long long'";
//     ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
//     ubsan_tests.alignmentAssumption();
// }

test "invalid bool" {
    const expected_error: []const u8 = "ubsan: Invalid load of value 4 for type 'bool'";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.invalidBool();
}

test "invalid bool aliased" {
    const expected_error: []const u8 = "ubsan: Invalid load of value 3 for type 'test_bool_type' (aka 'bool')";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.invalidBoolAliased();
}

// TODO: figure out how to get this test to trigger!
// test "invalid enum" {
//     const expected_error: []const u8 = "ubsan: Invalid load of value 3 for enum 'Enum'";
//     ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
//     ubsan_tests.invalidEnum();
// }

test "signed integer truncation" {
    const expected_error: []const u8 = "ubsan: Invalid implicit cast of 16-bit signed integer -500 ('int16_t' (aka 'short')) to 8-bit signed integer 12 ('int8_t' (aka 'signed char'))";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.signedIntegerTruncation();
}

test "unsigned integer truncation" {
    const expected_error: []const u8 = "ubsan: Invalid implicit cast of 16-bit unsigned integer 500 ('uint16_t' (aka 'unsigned short')) to 8-bit unsigned integer 244 ('uint8_t' (aka 'unsigned char'))";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.unsignedIntegerTruncation();
}

test "sign change" {
    const expected_error: []const u8 = "ubsan: Invalid implicit cast of 8-bit signed integer -1 ('int8_t' (aka 'signed char')) to 16-bit unsigned integer 65535 ('uint16_t' (aka 'unsigned short'))";
    ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
    ubsan_tests.signChange();
}

// test "function type mismatch" {
//     const expected_error: []const u8 = "";
//     _ = expected_error;
//     // setCustomRecoverHandler(&ExpectUbsanError(expected_error));
//
//     ubsan_tests.functionTypeMismatch();
// }

// C++ only errors
// TODO: Currently segfaults! Need a panic handler for this!
// test "empty return" {
//     const expected_error: []const u8 = "ubsan: Reached the end of value-returning function without returning a value";
//     ubsan.setCustomRecoverHandler(&ExpectUbsanError(expected_error));
//     _ = ubsan_tests.empty_return();
// }
