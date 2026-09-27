const std = @import("std");

pub fn absoluteDifference(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    return @max(a, b) - @min(a, b);
}

pub fn isEven(n: anytype) bool {
    return (n & 1) == 0;
}

pub fn isOdd(n: anytype) bool {
    return (n & 1) == 1;
}

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "absoluteDifference" {
    for ([_][3]isize{
        .{ 3, 2, 1 },
        .{ -4, -1, 3 },
        .{ -3, 2, 5 },
    }) |test_case| {
        const a, const b, const expected = test_case;
        const ltr = absoluteDifference(a, b);
        const rtl = absoluteDifference(b, a);
        try expectEqual(expected, ltr);
        try expectEqual(expected, rtl);
    }
}

test "parity" {
    var even: isize = -8;
    var odd: isize = -9;

    while (even <= 8) : (even += 2) {
        try expect(isEven(even));
        try expect(!isOdd(even));
    }

    while (odd <= 9) : (odd += 2) {
        try expect(!isEven(odd));
        try expect(isOdd(odd));
    }
}
