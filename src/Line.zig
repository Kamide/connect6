const std = @import("std");

const Point = @import("Point.zig");

const math = @import("math.zig");
const absoluteDifference = math.absoluteDifference;

const Line = @This();
start: Point,
end: Point,

pub fn init(start: Point, end: Point) Line {
    return .{
        .start = start,
        .end = end,
    };
}

pub fn reversed(line: Line) Line {
    return .{
        .start = line.end,
        .end = line.start,
    };
}

pub fn chebyshevDistance(line: Line) usize {
    return @max(
        absoluteDifference(line.start.row, line.end.row),
        absoluteDifference(line.start.column, line.end.column),
    );
}

const testing = std.testing;
const expectEqual = testing.expectEqual;

test "chebyshevDistance" {
    for (0..255) |expected| {
        const line = Line.init(.coincident(0), .coincident(expected));
        try expectEqual(expected, line.chebyshevDistance());
        try expectEqual(expected, line.reversed().chebyshevDistance());
    }
}
