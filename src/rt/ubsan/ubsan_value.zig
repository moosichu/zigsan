// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

pub const SourceLocation = extern struct {
    file_name: ?[*:0]u8,
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
};

// Represents either a float or an integer.
// If the type is small enough - its value is stored in
// in the ValueHandle pointer, otherwise it is what the
//  the ValueHandle points at.
pub const ValueHandle = *anyopaque;
