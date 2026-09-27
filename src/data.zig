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
