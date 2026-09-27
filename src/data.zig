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
