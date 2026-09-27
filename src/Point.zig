const std = @import("std");

const Offset = @import("Offset.zig");
const Size = @import("Size.zig");

const data = @import("data.zig");
const Error = data.Error;

const Point = @This();
row: usize,
column: usize,

pub fn init(row: usize, column: usize) Point {
    return .{
        .row = row,
        .column = column,
    };
}

pub fn coincident(index: usize) Point {
    return init(index, index);
}

pub fn rowMajorIndexUnchecked(point: Point, size: Size) usize {
    return size.width * point.row + point.column;
}

pub fn rowMajorIndex(point: Point, size: Size) !usize {
    if (point.row >= size.height or point.column >= size.width) {
        return Error.OutOfBounds;
    }

    return point.rowMajorIndexUnchecked(size);
}

pub fn offsetOrNull(point: Point, size: Size, offset: Offset) ?Point {
    return init(
        Offset.add(point.row, offset.row, size.height) orelse return null,
        Offset.add(point.column, offset.column, size.width) orelse return null,
    );
}

const testing = std.testing;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;

test "rowMajorIndex" {
    const size = Size.init(4, 3);

    for ([_][3]u8{
        .{ 0, 0, 0 },
        .{ 1, 1, 5 },
        .{ 2, 2, 10 },
        .{ 2, 3, 11 },
    }) |test_case| {
        const row, const column, const expected = test_case;
        const index = Point.init(row, column).rowMajorIndex(size);
        try expectEqual(expected, index);
    }

    for ([_][2]u8{
        .{ 2, 4 },
        .{ 3, 3 },
    }) |test_case| {
        const row, const column = test_case;
        const index = Point.init(row, column).rowMajorIndex(size);
        try expectError(Error.OutOfBounds, index);
    }
}
