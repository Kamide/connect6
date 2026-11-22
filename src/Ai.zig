const std = @import("std");
const c6 = @import("connect6");

const Ai = @This();
allocator: std.mem.Allocator,
prng: std.Random.DefaultPrng,
temperature: f64,

const MAX_TOP_CANDIDATES = 16;
const CANDIDATE_RADIUS: usize = 2;

pub fn init(allocator: std.mem.Allocator, seed: u64, temperature: f64) Ai {
    return .{
        .allocator = allocator,
        .prng = std.Random.DefaultPrng.init(seed),
        .temperature = @max(0.0, temperature),
    };
}

pub fn chooseMove(ai: *Ai, game: *c6.Game) !c6.Point {
    if (game.isEmpty()) {
        return .init(game.size.height / 2, game.size.width / 2);
    }

    const current_player = game.currentPlayer();

    var candidates: std.ArrayList(c6.Point) = .empty;
    defer candidates.deinit(ai.allocator);

    try collectCandidates(game, &candidates, ai.allocator);

    if (candidates.items.len == 0) {
        return fallbackMove(game, ai.allocator, ai.prng.random());
    }

    const scored = try ai.allocator.alloc(ScoredPoint, candidates.items.len);
    defer ai.allocator.free(scored);

    for (candidates.items, 0..) |candidate, index| {
        try game.play(candidate);

        const score = evaluate(game, current_player);

        _ = game.undo();

        scored[index] = .{
            .point = candidate,
            .score = score,
        };
    }

    std.mem.sort(
        ScoredPoint,
        scored,
        {},
        ScoredPoint.lessThan,
    );

    return selectPoint(ai, scored);
}

const ScoredPoint = struct {
    point: c6.Point,
    score: i32,

    fn lessThan(_: void, left: ScoredPoint, right: ScoredPoint) bool {
        return left.score > right.score;
    }
};

fn collectCandidates(
    game: *const c6.Game,
    candidates: *std.ArrayList(c6.Point),
    allocator: std.mem.Allocator,
) !void {
    for (0..game.size.height) |row| {
        for (0..game.size.width) |column| {
            const point = c6.Point.init(row, column);

            if (game.pieceAtUnchecked(point) != null) {
                continue;
            }

            if (hasOccupiedNeighbor(game, point, CANDIDATE_RADIUS)) {
                try candidates.append(allocator, point);
            }
        }
    }
}

fn hasOccupiedNeighbor(
    game: *const c6.Game,
    point: c6.Point,
    radius: usize,
) bool {
    const row_low = if (point.row >= radius)
        point.row - radius
    else
        0;

    const row_high = @min(
        point.row + radius,
        game.size.height - 1,
    );

    const column_low = if (point.column >= radius)
        point.column - radius
    else
        0;

    const column_high = @min(
        point.column + radius,
        game.size.width - 1,
    );

    var row = row_low;

    while (row <= row_high) : (row += 1) {
        var column = column_low;

        while (column <= column_high) : (column += 1) {
            if (game.pieceAtUnchecked(.init(row, column)) != null) {
                return true;
            }
        }
    }

    return false;
}

fn selectPoint(
    ai: *Ai,
    scored: []const ScoredPoint,
) c6.Point {
    std.debug.assert(scored.len > 0);

    if (ai.temperature == 0.0) {
        return scored[0].point;
    }

    const top_count = @min(scored.len, MAX_TOP_CANDIDATES);
    const top = scored[0..top_count];
    const best_score = scored[0].score;

    const score_scale = @max(
        @abs(@as(f64, @floatFromInt(best_score))),
        1.0,
    );

    const effective_temperature = score_scale * ai.temperature;

    var total_weight: f64 = 0.0;

    for (top) |candidate| {
        const difference =
            @as(f64, @floatFromInt(candidate.score)) -
            @as(f64, @floatFromInt(best_score));

        total_weight += @exp(difference / effective_temperature);
    }

    var target = ai.prng.random().float(f64) * total_weight;

    for (top) |candidate| {
        const difference =
            @as(f64, @floatFromInt(candidate.score)) -
            @as(f64, @floatFromInt(best_score));

        const weight = @exp(difference / effective_temperature);

        if (target < weight) {
            return candidate.point;
        }

        target -= weight;
    }

    return top[0].point;
}

fn fallbackMove(
    game: *const c6.Game,
    allocator: std.mem.Allocator,
    random: std.Random,
) !c6.Point {
    var available: std.ArrayList(c6.Point) = .empty;
    defer available.deinit(allocator);

    for (0..game.size.height) |row| {
        for (0..game.size.width) |column| {
            const point = c6.Point.init(row, column);

            if (game.pieceAtUnchecked(point) == null) {
                try available.append(allocator, point);
            }
        }
    }

    if (available.items.len == 0) {
        return error.NoMoves;
    }

    const index = random.uintLessThan(usize, available.items.len);
    return available.items[index];
}

fn evaluate(
    game: *const c6.Game,
    for_piece: c6.Piece,
) i32 {
    var score: i32 = 0;

    for (c6.Offset.to_end, c6.Offset.to_start) |forward, backward| {
        for (0..game.size.height) |row| {
            for (0..game.size.width) |column| {
                const point = c6.Point.init(row, column);
                const piece = game.pieceAtUnchecked(point) orelse continue;
                const before_point_maybe = point.offsetOrNull(game.size, backward);

                if (before_point_maybe) |before_point| {
                    if (game.pieceAtUnchecked(before_point) == piece) {
                        continue;
                    }
                }

                var length: usize = 0;
                var after_point_maybe: ?c6.Point = point;

                while (after_point_maybe) |after_point| {
                    if (game.pieceAtUnchecked(after_point) != piece) {
                        break;
                    }

                    length += 1;
                    after_point_maybe = after_point.offsetOrNull(game.size, forward);
                }

                var open: usize = 0;

                if (before_point_maybe) |before_point| {
                    if (game.pieceAtUnchecked(before_point) == null) {
                        open += 1;
                    }
                }

                if (after_point_maybe) |after_point| {
                    if (game.pieceAtUnchecked(after_point) == null) {
                        open += 1;
                    }
                }

                const value = scoreRun(length, open);

                if (piece == for_piece) {
                    score += value;
                } else {
                    score -= @divFloor(value * 11, 10);
                }
            }
        }
    }

    return score;
}

fn scoreRun(
    length: usize,
    open: usize,
) i32 {
    if (length >= 6) {
        return 1_000_000;
    }

    return switch (length) {
        5 => switch (open) {
            2 => 100_000,
            1 => 30_000,
            else => 5_000,
        },
        4 => switch (open) {
            2 => 10_000,
            1 => 3_000,
            else => 500,
        },
        3 => switch (open) {
            2 => 500,
            1 => 100,
            else => 20,
        },
        2 => switch (open) {
            2 => 50,
            1 => 15,
            else => 5,
        },
        else => 1,
    };
}
