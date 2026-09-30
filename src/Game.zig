const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const Line = @import("Line.zig");
const Offset = @import("Offset.zig");
const Point = @import("Point.zig");
const Size = @import("Size.zig");

const data = @import("data.zig");
const Error = data.Error;
const Piece = data.Piece;

const math = @import("math.zig");
const isEven = math.isEven;
const isOdd = math.isOdd;

const Game = @This();
allocator: Allocator,
size: Size,
lines: [Offset.to_end.len]?Line,
points: ArrayList(Point),
pieces: []?Piece,

pub fn init(allocator: Allocator, size: Size) !Game {
    if (size.area() == 0) {
        return Error.InvalidSize;
    }

    const pieces = try allocator.alloc(?Piece, size.area());
    @memset(pieces, null);

    return .{
        .allocator = allocator,
        .size = size,
        .lines = @splat(null),
        .points = .empty,
        .pieces = pieces,
    };
}

pub fn deinit(game: *Game) void {
    game.points.deinit(game.allocator);
    game.allocator.free(game.pieces);
}

pub fn reset(game: *Game) void {
    game.points.clearRetainingCapacity();
    @memset(game.pieces, null);
    game.lines = @splat(null);
}

pub fn piecesPlayed(game: *const Game) usize {
    return game.points.items.len;
}

pub fn currentPlayer(game: *const Game) Piece {
    return switch (game.piecesPlayed()) {
        0 => .black,
        else => |count| if (isOdd((count - 1) / 2)) .black else .white,
    };
}

pub fn nextPlayer(game: *const Game) Piece {
    return if (isEven(game.piecesPlayed() / 2)) .white else .black;
}

pub fn isFull(game: *const Game) bool {
    return game.piecesPlayed() == game.size.area();
}

pub fn winner(game: *const Game) ?Piece {
    for (game.lines) |line_maybe| {
        if (line_maybe) |line| {
            return game.pieceAtUnchecked(line.start);
        }
    }

    return null;
}

pub fn isOver(game: *const Game) bool {
    return game.isFull() or game.winner() != null;
}

pub fn isDraw(game: *const Game) bool {
    return game.isFull() and game.winner() == null;
}

pub fn canPlay(game: *const Game, point: Point) bool {
    _ = game.playableIndex(point) catch return false;
    return true;
}

fn playableIndex(game: *const Game, point: Point) !usize {
    if (game.isOver()) {
        return Error.GameOver;
    }

    const index = try point.rowMajorIndex(game.size);

    if (game.pieces[index] != null) {
        return Error.PieceExists;
    }

    return index;
}

pub fn play(game: *Game, point: Point) !void {
    const index = try game.playableIndex(point);
    const piece = game.currentPlayer();
    try game.points.append(game.allocator, point);
    game.pieces[index] = piece;

    for (Offset.to_start, Offset.to_end, 0..) |to_start, to_end, direction| {
        const start = game.terminalPoint(point, piece, to_start);
        const end = game.terminalPoint(point, piece, to_end);
        const line = Line.init(start, end);
        const count = line.chebyshevDistance() + 1;

        if (count >= 6) {
            game.lines[direction] = line;
        }
    }
}

fn terminalPoint(
    game: *const Game,
    point: Point,
    piece: Piece,
    offset: Offset,
) Point {
    var current = point;

    while (true) {
        const next = current.offsetOrNull(game.size, offset) orelse break;

        if (game.pieceAtUnchecked(next) != piece) {
            break;
        }

        current = next;
    }

    return current;
}

fn pieceAtUnchecked(game: *const Game, point: Point) ?Piece {
    return game.pieces[point.rowMajorIndexUnchecked(game.size)];
}

pub fn pieceAt(game: *const Game, point: Point) !?Piece {
    const index = try point.rowMajorIndex(game.size);
    return game.pieces[index];
}

pub fn canUndo(game: *const Game) bool {
    return game.piecesPlayed() > 0;
}

pub fn undo(game: *Game) ?Point {
    const point = game.points.pop() orelse return null;
    game.pieces[point.rowMajorIndexUnchecked(game.size)] = null;
    game.lines = @splat(null);
    return point;
}

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectEqualDeep = testing.expectEqualDeep;

test "Game" {
    var game = try Game.init(testing.allocator, .square(19));
    defer game.deinit();

    try expect(!game.isFull());
    try expectEqual(null, game.winner());
    try expect(!game.isOver());
    try expect(!game.isDraw());

    const moves = [_]Point{
        .init(0, 1),
        .coincident(1),
        .coincident(2),
        .init(0, 2),
        .init(0, 3),
        .coincident(3),
        .coincident(4),
        .init(0, 4),
        .init(0, 5),
        .coincident(5),
        .coincident(6),
    };

    for (moves, 0..) |move, count| {
        try expectEqual(count, game.piecesPlayed());

        switch (count) {
            0 => {
                try expectEqual(.black, game.currentPlayer());
                try expectEqual(.white, game.nextPlayer());
            },
            1, 5, 9 => {
                try expectEqual(.white, game.currentPlayer());
                try expectEqual(.white, game.nextPlayer());
            },
            2, 6, 10 => {
                try expectEqual(.white, game.currentPlayer());
                try expectEqual(.black, game.nextPlayer());
            },
            3, 7 => {
                try expectEqual(.black, game.currentPlayer());
                try expectEqual(.black, game.nextPlayer());
            },
            4, 8 => {
                try expectEqual(.black, game.currentPlayer());
                try expectEqual(.white, game.nextPlayer());
            },
            else => unreachable,
        }

        try expect(game.canPlay(move));
        try game.play(move);
        try expect(!game.canPlay(move));
    }

    try expect(!game.isFull());
    try expectEqual(.white, game.winner());
    try expect(game.isOver());
    try expect(!game.isDraw());
}

test "Game.isDraw" {
    for (1..7) |size| {
        var game = try Game.init(testing.allocator, .square(size));
        defer game.deinit();

        for (0..game.size.height) |row| {
            for (0..game.size.width) |column| {
                const point = Point.init(row, column);
                try game.play(point);
            }
        }

        try expect(game.isFull());
        try expect(game.isOver());
        try expect(game.isDraw());
    }
}

test "Game.{reset,undo}" {
    const size = 6;

    var reset_game = try Game.init(testing.allocator, .square(size));
    defer reset_game.deinit();

    var undo_game = try Game.init(testing.allocator, .square(size));
    defer undo_game.deinit();

    for (0..size) |row| {
        for (0..size) |column| {
            const point = Point.init(row, column);
            try reset_game.play(point);
            try undo_game.play(point);
        }
    }

    reset_game.reset();

    while (undo_game.canUndo()) {
        _ = undo_game.undo();
    }

    try expectEqualDeep(reset_game, undo_game);
}
