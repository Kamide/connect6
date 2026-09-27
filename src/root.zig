pub const Game = @import("Game.zig");
pub const Line = @import("Line.zig");
pub const Offset = @import("Offset.zig");
pub const Point = @import("Point.zig");
pub const Size = @import("Size.zig");

const data = @import("data.zig");
pub const Error = data.Error;
pub const Piece = data.Piece;

const math = @import("math.zig");
pub const absoluteDifference = math.absoluteDifference;
pub const isEven = math.isEven;
pub const isOdd = math.isOdd;

test "root" {
    _ = @import("math.zig");
    _ = @import("Size.zig");
    _ = @import("Point.zig");
    _ = @import("Line.zig");
    _ = @import("Game.zig");
}
