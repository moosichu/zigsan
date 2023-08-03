// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2023 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

// Grabbed from this PR https://github.com/ziglang/zig/pull/5165
// For this issue https://github.com/ziglang/zig/issues/5163

// Useful references!
// https://compiler-rt.llvm.org/
// https://github.com/llvm-mirror/compiler-rt/blob/master/lib/ubsan
// https://github.com/llvm-mirror/compiler-rt/blob/master/lib/ubsan/ubsan_handlers.h
// https://github.com/llvm-mirror/compiler-rt/blob/master/lib/ubsan/ubsan_handlers.cpp
// https://github.com/llvm-mirror/compiler-rt/blob/master/lib/ubsan/ubsan_handlers_cxx.h
// https://github.com/llvm-mirror/compiler-rt/blob/master/lib/ubsan/ubsan_handlers_cxx.cpp"
// https://github.com/llvm-mirror/compiler-rt/tree/master/lib/ubsan_minimal

// Runtime support for Clang's Undefined Behavior sanitizer
const std = @import("std");
const builtin = @import("builtin");
const ubsan_value = @import("ubsan/ubsan_value.zig");
const ubsan_type_hash = @import("ubsan/ubsan_type_hash.zig");
const logger = std.log.scoped(.ubsan);

threadlocal var custom_recover_handler: ?*const fn (error_msg: []const u8) void = null;

export fn setCustomRecoverHandler(new_custom_recover_handler: *const fn (error_msg: []const u8) void) void {
    custom_recover_handler = new_custom_recover_handler;
}

// Creates two handlers for a given error, both of them print the specified
// return message but the `abort_` version stops the execution of the program
// XXX: Don't depend on the stdlib
fn makeHandler(comptime error_msg: []const u8) type {
    return struct {
        pub fn recover_handler() callconv(.C) void {
            if (custom_recover_handler) |custom_recover_handler_fn| {
                custom_recover_handler_fn("ubsan: " ++ error_msg);
            } else {
                logger.warn("ubsan: " ++ error_msg, .{});
            }
        }
        pub fn abort_handler() callconv(.C) noreturn {
            @panic("ubsan: " ++ error_msg);
        }
    };
}

const OverflowData = extern struct {
    source_location: ubsan_value.SourceLocation,
    type_descriptor: *const ubsan_value.TypeDescriptor, // this is a const ref in C++
};

const ShiftOutOfBoundsData = extern struct {
    source_location: ubsan_value.SourceLocation,
    lhs_type_descriptor: *const ubsan_value.TypeDescriptor, // this is a const ref in C++
    rhs_type_descriptor: *const ubsan_value.TypeDescriptor, // this is a const ref in C++
};

const OutOfBoundsData = extern struct {
    source_location: ubsan_value.SourceLocation,
    array_type: *const ubsan_value.TypeDescriptor, // this is a const ref in C++
    index_type: *const ubsan_value.TypeDescriptor, // this is a const ref in C++
};

const UnreachableData = extern struct {
    source_location: ubsan_value.SourceLocation,
};

const AmbiguousFloatCastOverflowData = extern struct {
    pub fn tryCastToV2(self: *AmbiguousFloatCastOverflowData) ?*FloatCastOverflowDataV2 {
        const overflow_data: *FloatCastOverflowDataV1 = @alignCast(@ptrCast(self));
        // Using the fact that the FloatCastOverflowDataV2's first field is a
        // string, which shouldn't have it's first two bytes match the valid]
        // type descriptor kinds.
        if (overflow_data.from_type.kind.isValid()) {
            return null; // we are almost definitely a "v1" type descriptor!
        }
        return @alignCast(@ptrCast(self));
    }
};

// Older compiled programs had a different format for passing-through float-cast
// overflow data - so we have to as well. ubsan uses a heauristic to try and
// guess which one has been passed through so we have to match that also!
const FloatCastOverflowDataV1 = extern struct {
    from_type: *const ubsan_value.TypeDescriptor, // this is a const ref in C++
    to_type: *const ubsan_value.TypeDescriptor, // this is a const ref in C++
};

const FloatCastOverflowDataV2 = extern struct {
    source_location: ubsan_value.SourceLocation,
    from_type: *const ubsan_value.TypeDescriptor, // this is a const ref in C++
    to_type: *const ubsan_value.TypeDescriptor, // this is a const ref in C++
};

// C++ handler types

const DynamicTypeCacheMissData = extern struct {
    source_location: ubsan_value.SourceLocation,
    type_descriptor: *const ubsan_value.TypeDescriptor,
    type_info: ?*anyopaque,
    type_check_kind: u8,
};

const FunctionTypeMismatchData = extern struct {
    source_location: ubsan_value.SourceLocation,
    type_descriptor: *const ubsan_value.TypeDescriptor,
};

fn exportHandlers(comptime handlers: anytype, comptime export_name: []const u8) void {
    const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;
    {
        const handler_symbol = std.builtin.ExportOptions{ .name = "__ubsan_" ++ export_name, .linkage = linkage };
        @export(handlers.recover_handler, handler_symbol);
    }
    {
        const handler_symbol = std.builtin.ExportOptions{ .name = "__ubsan_" ++ export_name ++ "_abort", .linkage = linkage };
        @export(handlers.abort_handler, handler_symbol);
    }
}

fn ubsan_log_wrapper(comptime log: anytype, comptime format: []const u8, args: anytype) void {
    log("ubsan: " ++ format ++ "{s}:{any}:{any}\n", args);
}

fn ubsan_panic(comptime format: []const u8, args: anytype) void {
    ubsan_log_wrapper(std.debug.panic, format, args);
}

fn ubsan_warn(comptime format: []const u8, args: anytype) void {
    if (custom_recover_handler) |custom_recover_handler_fn| {
        var buffer: [2048]u8 = undefined;
        // TODO: Validate that this can't fail!
        const ubsan_error = std.fmt.bufPrint(&buffer, "ubsan: " ++ format ++ "{s}:{}:{}\n", args) catch unreachable;
        custom_recover_handler_fn(ubsan_error);
    } else {
        ubsan_log_wrapper(logger.debug, format, args);
    }
}

const abort_log = ubsan_panic;
const warn_log = ubsan_warn;

fn handleOverflow(comptime report_log: anytype, comptime name: []const u8, comptime symbol: []const u8, overflow_data: *OverflowData, lhs: ubsan_value.ValueHandle, rhs: ubsan_value.ValueHandle) void {
    const source_location = overflow_data.source_location.acquire();
    const format_string = name ++ " Overflow: {} " ++ symbol ++ " {} in type {s}\n";
    const type_name = overflow_data.type_descriptor.getNameAsString();

    if (overflow_data.type_descriptor.isSignedInteger()) {
        const lhs_value = overflow_data.type_descriptor.getSignedIntValue(lhs);
        const rhs_value = overflow_data.type_descriptor.getSignedIntValue(rhs);
        report_log(format_string, .{ lhs_value, rhs_value, type_name, source_location.file_name orelse "", source_location.line, source_location.column });
    } else {
        const lhs_value = overflow_data.type_descriptor.getUnsignedIntValue(lhs);
        const rhs_value = overflow_data.type_descriptor.getUnsignedIntValue(rhs);
        report_log(format_string, .{ lhs_value, rhs_value, type_name, source_location.file_name orelse "", source_location.line, source_location.column });
    }
}

fn makeOverflowHandler(comptime export_name: []const u8, comptime name: []const u8, comptime symbol: []const u8) void {
    const handlers = struct {
        pub fn recover_handler(overflow_data: *OverflowData, lhs: ubsan_value.ValueHandle, rhs: ubsan_value.ValueHandle) callconv(.C) void {
            handleOverflow(warn_log, name, symbol, overflow_data, lhs, rhs);
        }
        pub fn abort_handler(overflow_data: *OverflowData, lhs: ubsan_value.ValueHandle, rhs: ubsan_value.ValueHandle) callconv(.C) void {
            handleOverflow(abort_log, name, symbol, overflow_data, lhs, rhs);
        }
    };
    exportHandlers(handlers, export_name);
}

comptime {
    makeOverflowHandler("handle_add_overflow", "Addition", "+");
    makeOverflowHandler("handle_sub_overflow", "Subtraction", "-");
    makeOverflowHandler("handle_mul_overflow", "Multiplication", "*");
}

fn handleNegateOverflow(comptime report_log: anytype, overflow_data: *OverflowData, value: ubsan_value.ValueHandle) void {
    const source_location = overflow_data.source_location.acquire();
    const format_string = "Negation of {} cannot be represented in type {s}\n";
    const type_name = overflow_data.type_descriptor.getNameAsString();

    if (overflow_data.type_descriptor.isSignedInteger()) {
        const int_value = overflow_data.type_descriptor.getSignedIntValue(value);
        report_log(format_string, .{ int_value, type_name, source_location.file_name orelse "", source_location.line, source_location.column });
    } else {
        const int_value = overflow_data.type_descriptor.getUnsignedIntValue(value);
        report_log(format_string, .{ int_value, type_name, source_location.file_name orelse "", source_location.line, source_location.column });
    }
}

comptime {
    const handlers = struct {
        pub fn recover_handler(overflow_data: *OverflowData, value: ubsan_value.ValueHandle) callconv(.C) void {
            handleNegateOverflow(warn_log, overflow_data, value);
        }
        pub fn abort_handler(overflow_data: *OverflowData, value: ubsan_value.ValueHandle) callconv(.C) void {
            handleNegateOverflow(abort_log, overflow_data, value);
        }
    };
    exportHandlers(handlers, "handle_negate_overflow");
}

fn handleDivremOverflow(comptime report_log: anytype, overflow_data: *OverflowData, lhs: ubsan_value.ValueHandle, rhs: ubsan_value.ValueHandle) void {
    const source_location = overflow_data.source_location.acquire();
    if (overflow_data.type_descriptor.isSignedInteger() and (overflow_data.type_descriptor.getSignedIntValue(rhs) == -1)) {
        const format_string = "Division of {} by -1 cannot be represented in type {s}\n";
        const type_name = overflow_data.type_descriptor.getNameAsString();
        const int_value = overflow_data.type_descriptor.getSignedIntValue(lhs);
        report_log(format_string, .{ int_value, type_name, source_location.file_name orelse "", source_location.line, source_location.column });
    } else switch (overflow_data.type_descriptor.kind) {
        .float, .integer => {
            const format_string = "Division by 0\n";
            report_log(format_string, .{ source_location.file_name orelse "", source_location.line, source_location.column });
        },
        else => {
            unreachable;
        },
    }
}

comptime {
    const handlers = struct {
        pub fn recover_handler(overflow_data: *OverflowData, lhs: ubsan_value.ValueHandle, rhs: ubsan_value.ValueHandle) callconv(.C) void {
            handleDivremOverflow(warn_log, overflow_data, lhs, rhs);
        }
        pub fn abort_handler(overflow_data: *OverflowData, lhs: ubsan_value.ValueHandle, rhs: ubsan_value.ValueHandle) callconv(.C) void {
            handleDivremOverflow(abort_log, overflow_data, lhs, rhs);
        }
    };
    exportHandlers(handlers, "handle_divrem_overflow");
}

fn handleShiftOutOfBounds(comptime report_log: anytype, shift_out_of_bounds_data: *ShiftOutOfBoundsData, lhs: ubsan_value.ValueHandle, rhs: ubsan_value.ValueHandle) void {
    const source_location = shift_out_of_bounds_data.source_location.acquire();

    const rhs_type_descriptor = shift_out_of_bounds_data.rhs_type_descriptor;
    const lhs_type_descriptor = shift_out_of_bounds_data.lhs_type_descriptor;

    if (rhs_type_descriptor.isNegative(rhs)) {
        const exponent = rhs_type_descriptor.getSignedIntValue(rhs);
        report_log("Shift exponent {} is negative\n", .{ exponent, source_location.file_name orelse "", source_location.line, source_location.column });
        return;
    }

    const exponent = rhs_type_descriptor.getPositiveIntValue(rhs);

    {
        const base_integer_size = lhs_type_descriptor.getIntegerBitSize();
        if (exponent >= base_integer_size) {
            report_log("Shift exponent {} is too large for {}-bit type {s}\n", .{ exponent, base_integer_size, lhs_type_descriptor.getNameAsString(), source_location.file_name orelse "", source_location.line, source_location.column });
            return;
        }
    }

    if (lhs_type_descriptor.isNegative(lhs)) {
        const base = lhs_type_descriptor.getSignedIntValue(lhs);
        report_log("Left shift of {}, a negative value\n", .{
            base,
            source_location.file_name orelse "",
            source_location.line,
            source_location.column,
        });
    } else {
        const base = lhs_type_descriptor.getPositiveIntValue(lhs);
        report_log("Left shift of {} by {} cannot be represented by a {s}\n", .{
            base,
            exponent,
            lhs_type_descriptor.getNameAsString(),
            source_location.file_name orelse "",
            source_location.line,
            source_location.column,
        });
    }
}

comptime {
    const handlers = struct {
        pub fn recover_handler(shift_out_of_bounds_data: *ShiftOutOfBoundsData, lhs: ubsan_value.ValueHandle, rhs: ubsan_value.ValueHandle) callconv(.C) void {
            handleShiftOutOfBounds(warn_log, shift_out_of_bounds_data, lhs, rhs);
        }
        pub fn abort_handler(shift_out_of_bounds_data: *ShiftOutOfBoundsData, lhs: ubsan_value.ValueHandle, rhs: ubsan_value.ValueHandle) callconv(.C) void {
            handleShiftOutOfBounds(abort_log, shift_out_of_bounds_data, lhs, rhs);
        }
    };
    exportHandlers(handlers, "handle_shift_out_of_bounds");
}

fn handleOutOfBounds(comptime report_log: anytype, out_of_bounds_data: *OutOfBoundsData, index: ubsan_value.ValueHandle) void {
    const source_location = out_of_bounds_data.source_location.acquire();
    if (out_of_bounds_data.index_type.isSignedInteger()) {
        const index_value = out_of_bounds_data.index_type.getSignedIntValue(index);
        report_log("Index {} out of bounds for type {s}\n", .{
            index_value,
            out_of_bounds_data.array_type.getNameAsString(),
            source_location.file_name orelse "",
            source_location.line,
            source_location.column,
        });
    } else {
        const index_value = out_of_bounds_data.index_type.getUnsignedIntValue(index);
        report_log("Index {} out of bounds for type {s}\n", .{
            index_value,
            out_of_bounds_data.array_type.getNameAsString(),
            source_location.file_name orelse "",
            source_location.line,
            source_location.column,
        });
    }
}

comptime {
    const handlers = struct {
        pub fn recover_handler(out_of_bounds_data: *OutOfBoundsData, index: ubsan_value.ValueHandle) callconv(.C) void {
            handleOutOfBounds(warn_log, out_of_bounds_data, index);
        }
        pub fn abort_handler(out_of_bounds_data: *OutOfBoundsData, index: ubsan_value.ValueHandle) callconv(.C) void {
            handleOutOfBounds(abort_log, out_of_bounds_data, index);
        }
    };
    exportHandlers(handlers, "handle_out_of_bounds");
}

fn handleBuiltinUnreachable(comptime report_log: anytype, unreachable_data: *UnreachableData) void {
    const source_location = unreachable_data.source_location.acquire();
    report_log("Reached an unreachable location\n", .{
        source_location.file_name orelse "",
        source_location.line,
        source_location.column,
    });
}

comptime {
    const handlers = struct {
        pub fn recover_handler(unreachable_data: *UnreachableData) callconv(.C) void {
            handleBuiltinUnreachable(warn_log, unreachable_data);
        }
        pub fn abort_handler(unreachable_data: *UnreachableData) callconv(.C) void {
            handleBuiltinUnreachable(abort_log, unreachable_data);
        }
    };
    exportHandlers(handlers, "handle_builtin_unreachable");
}

fn handleMissingReturn(comptime report_log: anytype, unreachable_data: *UnreachableData) void {
    const source_location = unreachable_data.source_location.acquire();
    report_log("Reached the end of value-returning function without returning a value\n", .{
        source_location.file_name orelse "",
        source_location.line,
        source_location.column,
    });
}

comptime {
    const handlers = struct {
        pub fn recover_handler(unreachable_data: *UnreachableData) callconv(.C) void {
            handleMissingReturn(warn_log, unreachable_data);
        }
        pub fn abort_handler(unreachable_data: *UnreachableData) callconv(.C) void {
            handleMissingReturn(abort_log, unreachable_data);
        }
    };
    exportHandlers(handlers, "handle_missing_return");
}

fn handleFloatCastOverflow(comptime report_log: anytype, ambiguous_overflow_data: *AmbiguousFloatCastOverflowData, from: ubsan_value.ValueHandle, report_options: ubsan_value.ReportOptions) void {
    var file_name: [*:0]const u8 = undefined;
    var line: i64 = undefined;
    var column: i64 = undefined;
    var from_type: *const ubsan_value.TypeDescriptor = undefined;
    var to_type: *const ubsan_value.TypeDescriptor = undefined;
    if (ambiguous_overflow_data.tryCastToV2()) |overflow_data| {
        const source_location = overflow_data.source_location.acquire();
        file_name = source_location.file_name orelse "";
        line = source_location.line;
        column = source_location.column;

        from_type = overflow_data.from_type;
        to_type = overflow_data.to_type;
    } else {
        const overflow_data: *FloatCastOverflowDataV1 = @alignCast(@ptrCast(ambiguous_overflow_data));
        _ = report_options;
        // TODO: look at how old-style source location is properly aquired!
        file_name = "";
        line = -1;
        column = -1;

        from_type = overflow_data.from_type;
        to_type = overflow_data.to_type;
    }

    report_log("The {s} value {} is out of range for the type {s}\n", .{
        from_type.getNameAsString(),
        ubsan_value.Value{ .type_descriptor = from_type, .value_handle = from },
        to_type.getNameAsString(),
        file_name,
        line,
        column,
    });
}

comptime {
    const handlers = struct {
        pub fn recover_handler(overflow_data: *AmbiguousFloatCastOverflowData, from: ubsan_value.ValueHandle, report_options: ubsan_value.ReportOptions) callconv(.C) void {
            handleFloatCastOverflow(warn_log, overflow_data, from, report_options);
        }
        pub fn abort_handler(overflow_data: *AmbiguousFloatCastOverflowData, from: ubsan_value.ValueHandle, report_options: ubsan_value.ReportOptions) callconv(.C) void {
            handleFloatCastOverflow(abort_log, overflow_data, from, report_options);
        }
    };
    exportHandlers(handlers, "handle_float_cast_overflow");
}

// C++ handlers

fn handleDynamicTypeCacheMiss(dynamic_type_cache_miss_data: *DynamicTypeCacheMissData, pointer: ubsan_value.ValueHandle, hash: ubsan_value.ValueHandle) bool {
    _ = dynamic_type_cache_miss_data;
    _ = pointer;
    _ = hash;
    // TODO(TRC):NowNow handle dynamic type cache miss properly
    return false;
}

export fn __ubsan_handle_dynamic_type_cache_miss_abort(dynamic_type_cache_miss_data: *DynamicTypeCacheMissData, pointer: ubsan_value.ValueHandle, hash: ubsan_value.ValueHandle) callconv(.C) void {
    if (handleDynamicTypeCacheMiss(dynamic_type_cache_miss_data, pointer, hash)) {
        @panic("ubsan: " ++ "handle_dynamic_type_cache_miss");
    }
}

export fn __ubsan_handle_dynamic_type_cache_miss(dynamic_type_cache_miss_data: *DynamicTypeCacheMissData, pointer: ubsan_value.ValueHandle, hash: ubsan_value.ValueHandle) callconv(.C) void {
    if (handleDynamicTypeCacheMiss(dynamic_type_cache_miss_data, pointer, hash)) {
        logger.warn("ubsan: " ++ "handle_dynamic_type_cache_miss", .{});
    }
}

fn handleFunctionTypeMismatch(comptime report_log: anytype, function_type_mismatch_data: *FunctionTypeMismatchData, function: ubsan_value.ValueHandle, calleeRtti: ubsan_value.ValueHandle, fnRtti: ubsan_value.ValueHandle) void {
    _ = function;

    if (ubsan_type_hash.checkTypeInfoEquality(calleeRtti, fnRtti)) {
        // Function types are equal - no mis-match
        @panic("PANCI");
        // return;
    }

    const source_location = function_type_mismatch_data.source_location.acquire();

    // TODO: impoement ignore report
    // https://github.com/llvm-mirror/compiler-rt/blob/69445f095c22aac2388f939bedebf224a6efcdaf/lib/ubsan/ubsan_handlers.cpp

    // const source_location = shift_out_of_bounds_data.source_location.acquire();

    // TODO: Implement issue suppression

    // https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html#issue-suppression
    // Parse the ignore list:
    // https://clang.llvm.org/docs/SanitizerSpecialCaseList.html

    report_log("Call to function through incorrect function type {s}\n", .{ function_type_mismatch_data.type_descriptor.getNameAsString(), source_location.file_name orelse "", source_location.line, source_location.column });
    @panic("PANCI");
}

comptime {
    const handlers = struct {
        pub fn recover_handler(function_type_mismatch_data: *FunctionTypeMismatchData, function: ubsan_value.ValueHandle, calleeRtti: ubsan_value.ValueHandle, fnRtti: ubsan_value.ValueHandle) callconv(.C) void {
            handleFunctionTypeMismatch(warn_log, function_type_mismatch_data, function, calleeRtti, fnRtti);
        }
        pub fn abort_handler(function_type_mismatch_data: *FunctionTypeMismatchData, function: ubsan_value.ValueHandle, calleeRtti: ubsan_value.ValueHandle, fnRtti: ubsan_value.ValueHandle) callconv(.C) void {
            handleFunctionTypeMismatch(abort_log, function_type_mismatch_data, function, calleeRtti, fnRtti);
        }
    };
    exportHandlers(handlers, "handle_function_type_mismatch_v1");
}

comptime {
    const HANDLERS = .{
        .{ "handle_type_mismatch", "type-mismatch", .Both, .Both },
        .{ "handle_alignment_assumption", "alignment-assumption", .Both, .Both },
        .{ "handle_add_overflow", "add-overflow", .Both, .Minimal },
        .{ "handle_sub_overflow", "sub-overflow", .Both, .Minimal },
        .{ "handle_mul_overflow", "mul-overflow", .Both, .Minimal },
        .{ "handle_negate_overflow", "negate-overflow", .Both, .Minimal },
        .{ "handle_divrem_overflow", "divrem-overflow", .Both, .Minimal },
        .{ "handle_shift_out_of_bounds", "shift-out-of-bounds", .Both, .Minimal },
        .{ "handle_out_of_bounds", "out-of-bounds", .Both, .Minimal },
        .{ "handle_builtin_unreachable", "builtin-unreachable", .Recover, .Minimal },
        .{ "handle_missing_return", "missing-return", .Recover, .Minimal },
        .{ "handle_vla_bound_not_positive", "vla-bound-not-positive", .Both, .Both },
        .{ "handle_float_cast_overflow", "float-cast-overflow", .Both, .Minimal },
        .{ "handle_load_invalid_value", "load-invalid-value", .Both, .Both },
        .{ "handle_invalid_builtin", "invalid-builtin", .Both, .Both },
        .{ "handle_function_type_mismatch", "function-type-mismatch", .Both, .Both },
        .{ "handle_implicit_conversion", "implicit-conversion", .Both, .Both },
        .{ "handle_nonnull_arg", "nonnull-arg", .Both, .Both },
        .{ "handle_nonnull_return", "nonnull-return", .Both, .Both },
        .{ "handle_nullability_arg", "nullability-arg", .Both, .Both },
        .{ "handle_nullability_return", "nullability-return", .Both, .Both },
        .{ "handle_pointer_overflow", "pointer-overflow", .Both, .Both },
        .{ "handle_cfi_check_fail", "cfi-check-fail", .Both, .Both },
        .{ "handle_type_mismatch_v1", "type-mismatch-v1", .Both, .Full },
        .{ "handle_function_type_mismatch_v1", "function-type-mismatch-v1", .Both, .Minimal },
        .{ "vptr_type_cache", "vptr-type-cache", .Recover, .Full },
    };

    const linkage: std.builtin.GlobalLinkage = if (builtin.is_test) .Internal else .Weak;

    inline for (HANDLERS) |entry| {
        const handler = makeHandler(entry[1]);

        if ((entry[2] == .Both or entry[2] == .Recover) and (entry[3] == .Both or entry[3] == .Full)) {
            const handler_name = "__ubsan_" ++ entry[0];
            const handler_symbol = std.builtin.ExportOptions{ .name = handler_name, .linkage = linkage };
            @export(handler.recover_handler, handler_symbol);
        }

        if ((entry[2] == .Both or entry[2] == .Abort) and (entry[3] == .Both or entry[3] == .Full)) {
            const handler_name = "__ubsan_" ++ entry[0] ++ "_abort";
            const handler_symbol = std.builtin.ExportOptions{ .name = handler_name, .linkage = linkage };
            @export(handler.abort_handler, handler_symbol);
        }

        // Minimal traps as well - these are meant to be simpler so should probably make them different implementations long-term
        if ((entry[2] == .Both or entry[2] == .Recover) and (entry[3] == .Both or entry[3] == .Minimal)) {
            const handler_name = "__ubsan_" ++ entry[0] ++ "_minimal";
            const handler_symbol = std.builtin.ExportOptions{ .name = handler_name, .linkage = linkage };
            @export(handler.recover_handler, handler_symbol);
        }

        if ((entry[2] == .Both or entry[2] == .Abort) and (entry[3] == .Both or entry[3] == .Minimal)) {
            const handler_name = "__ubsan_" ++ entry[0] ++ "_minimal_abort";
            const handler_symbol = std.builtin.ExportOptions{ .name = handler_name, .linkage = linkage };
            @export(handler.abort_handler, handler_symbol);
        }
    }
}
