const std = @import("std");

pub const Error = error{
    GameOver,
    InvalidSize,
    OutOfBounds,
    PieceExists,
};

pub const Piece = enum {
    black,
    white,
};

pub const Trit = enum(i8) {
    negative = -1,
    zero = 0,
    positive = 1,

    pub fn negate(trit: Trit) Trit {
        return switch (trit) {
            .negative => .positive,
            .zero => .zero,
            .positive => .negative,
        };
    }

    pub fn addUnsigned(trit: Trit, operand: usize, max: usize) ?usize {
        return switch (trit) {
            .negative => if (operand == 0) null else operand - 1,
            .zero => if (operand < max) operand else null,
            .positive => if (max == 0 or operand >= max - 1) null else operand + 1,
        };
    }
};

const testing = std.testing;
const expectEqual = testing.expectEqual;

test "Trit" {
    const TestCase = struct { Trit, usize, usize, ?usize };

    for ([_]TestCase{
        .{ .negative, 0, 0, null },
        .{ .zero, 0, 0, null },
        .{ .positive, 0, 0, null },

        .{ .negative, 0, 1, null },
        .{ .zero, 0, 1, 0 },
        .{ .positive, 0, 1, null },

        .{ .negative, 1, 2, 0 },
        .{ .zero, 1, 2, 1 },
        .{ .positive, 1, 2, null },

        .{ .negative, 2, 2, 1 },
        .{ .zero, 2, 2, null },
        .{ .positive, 0, 2, 1 },
    }) |test_case| {
        const trit, const operand, const max, const expected = test_case;
        try expectEqual(expected, trit.addUnsigned(operand, max));
    }
}
