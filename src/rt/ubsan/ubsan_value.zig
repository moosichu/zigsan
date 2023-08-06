// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const builtin = @import("builtin");

pub const ReportOptions = extern struct {
    // if from_unrecoverable_handler is true, the handler isn't expected to return
    from_unrecoverable_handler: bool,
    /// pc/bp are used to unwind the stack trace.
    pc: *anyopaque,
    bp: *anyopaque,
};

pub const ErrorType = enum {
    invalid_bool_load,
    invalid_enum_load,
};

pub const SourceLocation = extern struct {
    file_name: ?[*:0]const u8,
    line: u32,
    column: u32,

    pub fn acquire(source_location: *SourceLocation) SourceLocation {
        // TODO: Figure out why zig gives the error
        // error: @atomicRmw atomic ordering must not be Unordered
        // const returnColumn: u32 = @atomicRmw(u32, &source_location.column, .Xchg, ~@as(u32, 0), .Unordered);
        const returnColumn: u32 = @atomicRmw(u32, &source_location.column, .Xchg, ~@as(u32, 0), .Monotonic);
        return SourceLocation{
            .file_name = source_location.file_name,
            .line = source_location.line,
            .column = returnColumn,
        };
    }

    pub fn isDisabled(source_location: *const SourceLocation) bool {
        return source_location.column == ~@as(u32, 0);
    }

    // TODO: Implement this!
    // pub fn format(self: SourceLocation, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    //     writer.
    // }
};

pub const TypeKind = enum(u16) {
    // If you have an integer type:
    // - Lowest bit on info = signed/unsigned integer
    // - The remaining bits are log_2(bit width)
    integer = 0x0000,
    // If you have a floating point type:
    // - Type info is the bit width.
    float = 0x0001,
    // Any other type. The value representation is unspecified.
    unknown = 0xffff,
    _,

    pub fn isValid(self: TypeKind) bool {
        switch (self) {
            .integer, .float, .unknown => return true,
            else => return false,
        }
    }
};

pub const Value = struct {
    type_descriptor: *const TypeDescriptor,
    value_handle: ValueHandle,
    pub fn format(self: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        if (self.type_descriptor.isSignedInteger()) {
            return writer.print("{}", .{self.type_descriptor.getSignedIntValue(self.value_handle)});
        } else if (self.type_descriptor.kind == .integer) {
            return writer.print("{}", .{self.type_descriptor.getPositiveIntValue(self.value_handle)});
        } else if (self.type_descriptor.kind == .float) {
            return writer.print("{}", .{self.type_descriptor.getFloatValue(self.value_handle)});
        }

        unreachable;
        // return write.print("{}
    }
};

pub const TypeDescriptor = extern struct {
    kind: TypeKind,
    info: u16,
    name: [1]u8,

    pub fn getNameAsString(type_descriptor: *const TypeDescriptor) [*:0]const u8 {
        return @as([*:0]const u8, @ptrCast(&type_descriptor.name));
    }

    pub fn isSignedInteger(type_descriptor: *const TypeDescriptor) bool {
        return type_descriptor.kind == .integer and (type_descriptor.info & 1) == 1;
    }

    pub fn getIntegerBitSize(type_descriptor: *const TypeDescriptor) u64 {
        if (type_descriptor.kind != .integer) unreachable;
        // Bit-shift the signed value away and then get 2^n out
        return @as(u64, 1) << @as(u6, @intCast(type_descriptor.info >> 1));
    }

    pub fn getFloatBitSize(type_descriptor: *const TypeDescriptor) u64 {
        if (type_descriptor.kind != .float) unreachable;
        return type_descriptor.info;
    }

    fn getIntValueBits(type_descriptor: *const TypeDescriptor, value_handle: ValueHandle) u128 {
        if (type_descriptor.kind != .integer) unreachable;
        const size = type_descriptor.getIntegerBitSize();
        const max_inline_size = @sizeOf(ValueHandle) * 8;
        if (size <= max_inline_size) {
            return @intFromPtr(value_handle);
        } else {
            if (size == 64) {
                return @as(*u64, @ptrCast(@alignCast(value_handle))).*;
            } else if (size == 128) {
                return @as(*u128, @ptrCast(@alignCast(value_handle))).*;
            } else {
                unreachable;
            }
        }
    }

    pub fn getPositiveIntValue(type_descriptor: *const TypeDescriptor, value_handle: ValueHandle) u128 {
        if (type_descriptor.isNegative(value_handle)) unreachable;
        return type_descriptor.getIntValueBits(value_handle);
    }

    pub fn getSignedIntValue(type_descriptor: *const TypeDescriptor, value_handle: ValueHandle) i128 {
        if (!type_descriptor.isSignedInteger()) unreachable;
        const signed_value: i128 = switch (type_descriptor.getIntegerBitSize()) {
            8 => @as(i8, @bitCast(@as(u8, @intCast(type_descriptor.getIntValueBits(value_handle))))),
            16 => @as(i16, @bitCast(@as(u16, @intCast(type_descriptor.getIntValueBits(value_handle))))),
            32 => @as(i32, @bitCast(@as(u32, @intCast(type_descriptor.getIntValueBits(value_handle))))),
            64 => @as(i64, @bitCast(@as(u64, @intCast(type_descriptor.getIntValueBits(value_handle))))),
            128 => @as(i128, @bitCast(@as(u128, @intCast(type_descriptor.getIntValueBits(value_handle))))),
            else => unreachable,
        };
        return signed_value;
    }

    pub fn getUnsignedIntValue(type_descriptor: *const TypeDescriptor, value_handle: ValueHandle) u128 {
        if (type_descriptor.isSignedInteger()) unreachable;
        return type_descriptor.getIntValueBits(value_handle);
    }

    pub fn isNegative(type_descriptor: *const TypeDescriptor, value_handle: ValueHandle) bool {
        if (!type_descriptor.isSignedInteger()) {
            return false;
        }
        return type_descriptor.getSignedIntValue(value_handle) < 0;
    }

    pub fn decodeFloat(comptime float_type: type, value_handle: ValueHandle) float_type {
        if (@bitSizeOf(float_type) <= @bitSizeOf(ValueHandle)) {
            // We need to ensure the thing we are pointing to is decoded correctly!
            switch (@bitSizeOf(float_type)) {
                16 => switch (builtin.cpu.arch.endian()) {
                    .Big => {
                        const pointer_end = &(@as([*]const ValueHandle, @ptrCast(&value_handle))[1]);
                        const result = (@as([*]const f16, @ptrCast(pointer_end)) - 1)[0];
                        return result;
                    },
                    .Little => {
                        const result = @as(*const f16, @ptrCast(&value_handle)).*;
                        return result;
                    },
                },
                32 => switch (builtin.cpu.arch.endian()) {
                    .Big => {
                        const pointer_end = &(@as([*]const ValueHandle, @ptrCast(&value_handle))[1]);
                        const result = (@as([*]const f32, @ptrCast(pointer_end)) - 1)[0];
                        return result;
                    },
                    .Little => {
                        const result: f32 = @as(*const f32, @ptrCast(&value_handle)).*;
                        return result;
                    },
                },
                64 => {
                    const result: f64 = @as(*const f64, @ptrCast(&value_handle)).*;
                    return result;
                },
                else => unreachable,
            }
        } else {
            const result = @as(*float_type, @alignCast(@ptrCast(value_handle))).*;
            return result;
        }
    }

    pub fn getFloatValue(type_descriptor: *const TypeDescriptor, value_handle: ValueHandle) f128 {
        if (type_descriptor.getFloatBitSize() > @bitSizeOf(f128)) unreachable;

        switch (type_descriptor.getFloatBitSize()) {
            16 => return decodeFloat(f16, value_handle),
            32 => return decodeFloat(f32, value_handle),
            64 => return decodeFloat(f64, value_handle),
            // TODO: verify that this actually works on intel hardware?
            80 => return decodeFloat(f80, value_handle),
            // TODO: Handle this!
            // 96 => return decodeFloat(f96, value_handle),
            128 => return decodeFloat(f128, value_handle),
            else => unreachable,
        }
    }
};

// Represents either a float or an integer.
// If the type is small enough - its value is stored in
// in the ValueHandle pointer, otherwise it is what the
//  the ValueHandle points at.
pub const ValueHandle = *anyopaque;
