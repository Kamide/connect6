const std = @import("std");
const c6 = @import("connect6");
const Comparator = @import("Comparator.zig");

const Ai = @This();
allocator: std.mem.Allocator,
prng: std.Random.DefaultPrng,
temperature: f64,
search_depth: usize,
cancelation_requested: std.atomic.Value(bool),

const AiError = c6.Error || error{
    Canceled,
    OutOfMemory,
};

const MAX_RANDOMIZED_CANDIDATES = 16;
const MAX_ROOT_CANDIDATES = 24;
const MAX_SEARCH_BRANCHING_FACTOR = 10;
const ROOT_CANDIDATE_RADIUS = 2;
const SEARCH_CANDIDATE_RADIUS = 2;
const SEARCH_INFINITY_SCORE = 1_000_000_000;

pub fn init(
    allocator: std.mem.Allocator,
    seed: u64,
    temperature: f64,
    search_depth: usize,
) Ai {
    return .{
        .allocator = allocator,
        .prng = .init(seed),
        .temperature = @max(0.0, temperature),
        .search_depth = search_depth,
        .cancelation_requested = .init(false),
    };
}

pub fn isCanceled(ai: *const Ai) bool {
    return ai.cancelation_requested.load(.acquire);
}

pub fn requestCancel(ai: *Ai) void {
    ai.cancelation_requested.store(true, .release);
}

pub fn resetCancel(ai: *Ai) void {
    ai.cancelation_requested.store(false, .release);
}

pub fn chooseMove(ai: *Ai, game: *c6.Game) AiError!c6.Point {
    if (game.isEmpty()) {
        return .init(game.size.height / 2, game.size.width / 2);
    }

    if (ai.isCanceled()) {
        return AiError.Canceled;
    }

    if (ai.search_depth == 0) {
        return chooseFallbackMove(
            game,
            ai.allocator,
            ai.prng.random(),
        );
    }

    var candidate_points: std.ArrayList(c6.Point) = .empty;
    defer candidate_points.deinit(ai.allocator);

    try collectCandidates(
        ai,
        game,
        ROOT_CANDIDATE_RADIUS,
        &candidate_points,
        ai.allocator,
    );

    if (candidate_points.items.len == 0) {
        return chooseFallbackMove(
            game,
            ai.allocator,
            ai.prng.random(),
        );
    }

    if (ai.search_depth == 1) {
        return chooseGreedyMove(
            ai,
            game,
            candidate_points.items,
        );
    }

    const root_player = game.currentPlayer();

    const root_candidates = try orderCandidates(
        ai,
        game,
        candidate_points.items,
        root_player,
        MAX_ROOT_CANDIDATES,
    );
    defer ai.allocator.free(root_candidates);

    const scored_candidates = try ai.allocator.alloc(
        ScoredPoint,
        root_candidates.len,
    );
    defer ai.allocator.free(scored_candidates);

    const opponent_depth = ai.search_depth - 1;

    for (root_candidates, 0..) |candidate, index| {
        if (ai.isCanceled()) {
            return AiError.Canceled;
        }

        try game.play(candidate);
        defer _ = game.undo();

        const score = try searchAfterFirstStone(
            ai,
            game,
            root_player,
            opponent_depth,
            -SEARCH_INFINITY_SCORE,
            SEARCH_INFINITY_SCORE,
        );

        scored_candidates[index] = .{
            .point = candidate,
            .score = score,
        };
    }

    std.mem.sort(
        ScoredPoint,
        scored_candidates,
        {},
        ScoredPoint.by.score.descending,
    );

    return selectCandidate(ai, scored_candidates);
}

fn chooseGreedyMove(
    ai: *Ai,
    game: *c6.Game,
    candidate_points: []const c6.Point,
) AiError!c6.Point {
    const current_player = game.currentPlayer();

    const scored_candidates = try ai.allocator.alloc(
        ScoredPoint,
        candidate_points.len,
    );
    defer ai.allocator.free(scored_candidates);

    for (candidate_points, 0..) |candidate, index| {
        if (ai.isCanceled()) {
            return AiError.Canceled;
        }

        try game.play(candidate);

        const score = blk: {
            defer _ = game.undo();
            break :blk try evaluate(ai, game, current_player);
        };

        scored_candidates[index] = .{
            .point = candidate,
            .score = score,
        };
    }

    std.mem.sort(
        ScoredPoint,
        scored_candidates,
        {},
        ScoredPoint.by.score.descending,
    );

    return selectCandidate(ai, scored_candidates);
}

fn negamax(
    ai: *Ai,
    game: *c6.Game,
    remaining_depth: usize,
    alpha_bound: i32,
    beta_bound: i32,
) AiError!i32 {
    if (ai.isCanceled()) {
        return AiError.Canceled;
    }

    const player = game.currentPlayer();

    if (game.isOver() or remaining_depth == 0) {
        return evaluate(ai, game, player);
    }

    var candidate_points: std.ArrayList(c6.Point) = .empty;
    defer candidate_points.deinit(ai.allocator);

    try collectCandidates(
        ai,
        game,
        SEARCH_CANDIDATE_RADIUS,
        &candidate_points,
        ai.allocator,
    );

    if (candidate_points.items.len == 0) {
        return evaluate(ai, game, player);
    }

    const search_candidates = try orderCandidates(
        ai,
        game,
        candidate_points.items,
        player,
        MAX_SEARCH_BRANCHING_FACTOR,
    );
    defer ai.allocator.free(search_candidates);

    var alpha = alpha_bound;
    var best_score: i32 = -SEARCH_INFINITY_SCORE;

    for (search_candidates) |candidate| {
        if (ai.isCanceled()) {
            return AiError.Canceled;
        }

        try game.play(candidate);
        defer _ = game.undo();

        const score = try searchAfterFirstStone(
            ai,
            game,
            player,
            remaining_depth - 1,
            alpha,
            beta_bound,
        );

        best_score = @max(best_score, score);
        alpha = @max(alpha, score);

        if (alpha >= beta_bound) {
            break;
        }
    }

    return best_score;
}

fn searchAfterFirstStone(
    ai: *Ai,
    game: *c6.Game,
    player: c6.Piece,
    remaining_depth: usize,
    alpha_bound: i32,
    beta_bound: i32,
) AiError!i32 {
    if (ai.isCanceled()) {
        return AiError.Canceled;
    }

    if (game.isOver()) {
        return evaluate(ai, game, player);
    }

    if (game.currentPlayer() != player) {
        return -try negamax(
            ai,
            game,
            remaining_depth,
            -beta_bound,
            -alpha_bound,
        );
    }

    var candidate_points: std.ArrayList(c6.Point) = .empty;
    defer candidate_points.deinit(ai.allocator);

    try collectCandidates(
        ai,
        game,
        SEARCH_CANDIDATE_RADIUS,
        &candidate_points,
        ai.allocator,
    );

    if (candidate_points.items.len == 0) {
        return evaluate(ai, game, player);
    }

    const second_stone_candidates = try orderCandidates(
        ai,
        game,
        candidate_points.items,
        player,
        MAX_SEARCH_BRANCHING_FACTOR,
    );
    defer ai.allocator.free(second_stone_candidates);

    var alpha = alpha_bound;
    var best_score: i32 = -SEARCH_INFINITY_SCORE;

    for (second_stone_candidates) |candidate| {
        if (ai.isCanceled()) {
            return AiError.Canceled;
        }

        try game.play(candidate);
        defer _ = game.undo();

        const score = if (game.isOver())
            try evaluate(ai, game, player)
        else if (game.currentPlayer() != player)
            -try negamax(
                ai,
                game,
                remaining_depth,
                -beta_bound,
                -alpha,
            )
        else
            try evaluate(ai, game, player);

        best_score = @max(best_score, score);
        alpha = @max(alpha, score);

        if (alpha >= beta_bound) {
            break;
        }
    }

    return best_score;
}

fn orderCandidates(
    ai: *Ai,
    game: *c6.Game,
    candidate_points: []const c6.Point,
    perspective_piece: c6.Piece,
    candidate_limit: usize,
) AiError![]c6.Point {
    const scored_candidates = try ai.allocator.alloc(
        ScoredPoint,
        candidate_points.len,
    );
    defer ai.allocator.free(scored_candidates);

    for (candidate_points, 0..) |candidate, index| {
        if (ai.isCanceled()) {
            return AiError.Canceled;
        }

        try game.play(candidate);
        defer _ = game.undo();

        const score = try evaluate(
            ai,
            game,
            perspective_piece,
        );

        scored_candidates[index] = .{
            .point = candidate,
            .score = score,
        };
    }

    std.mem.sort(
        ScoredPoint,
        scored_candidates,
        {},
        ScoredPoint.by.score.descending,
    );

    const selected_count = @min(
        scored_candidates.len,
        candidate_limit,
    );

    const ordered_points = try ai.allocator.alloc(
        c6.Point,
        selected_count,
    );

    for (scored_candidates[0..selected_count], 0..) |entry, index| {
        ordered_points[index] = entry.point;
    }

    return ordered_points;
}

const ScoredPoint = struct {
    point: c6.Point,
    score: i32,

    const by = struct {
        const score = Comparator.by(ScoredPoint, "score");
    };
};

fn collectCandidates(
    ai: *const Ai,
    game: *const c6.Game,
    neighbor_radius: usize,
    candidate_points: *std.ArrayList(c6.Point),
    allocator: std.mem.Allocator,
) AiError!void {
    for (0..game.size.height) |row| {
        if (ai.isCanceled()) {
            return AiError.Canceled;
        }

        for (0..game.size.width) |column| {
            const point = c6.Point.init(row, column);

            if (game.pieceAtUnchecked(point) != null) {
                continue;
            }

            if (hasNearbyPiece(game, point, neighbor_radius)) {
                try candidate_points.append(allocator, point);
            }
        }
    }
}

fn hasNearbyPiece(
    game: *const c6.Game,
    point: c6.Point,
    neighbor_radius: usize,
) bool {
    const row_low = if (point.row >= neighbor_radius)
        point.row - neighbor_radius
    else
        0;

    const row_high = @min(
        point.row + neighbor_radius,
        game.size.height - 1,
    );

    const column_low = if (point.column >= neighbor_radius)
        point.column - neighbor_radius
    else
        0;

    const column_high = @min(
        point.column + neighbor_radius,
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

fn selectCandidate(
    ai: *Ai,
    scored_candidates: []const ScoredPoint,
) c6.Point {
    std.debug.assert(scored_candidates.len > 0);

    if (ai.temperature == 0.0) {
        return scored_candidates[0].point;
    }

    const top_count = @min(
        scored_candidates.len,
        MAX_RANDOMIZED_CANDIDATES,
    );

    const top_candidates = scored_candidates[0..top_count];
    const best_score = scored_candidates[0].score;

    const score_scale = @max(
        @abs(@as(f64, @floatFromInt(best_score))),
        1.0,
    );

    const effective_temperature = score_scale * ai.temperature;

    var total_weight: f64 = 0.0;

    for (top_candidates) |candidate| {
        const difference =
            @as(f64, @floatFromInt(candidate.score)) -
            @as(f64, @floatFromInt(best_score));

        total_weight += @exp(difference / effective_temperature);
    }

    var random_weight_target = ai.prng.random().float(f64) * total_weight;

    for (top_candidates) |candidate| {
        const difference =
            @as(f64, @floatFromInt(candidate.score)) -
            @as(f64, @floatFromInt(best_score));

        const weight = @exp(difference / effective_temperature);

        if (random_weight_target < weight) {
            return candidate.point;
        }

        random_weight_target -= weight;
    }

    return top_candidates[0].point;
}

fn chooseFallbackMove(
    game: *const c6.Game,
    allocator: std.mem.Allocator,
    random: std.Random,
) AiError!c6.Point {
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
        return AiError.GameOver;
    }

    const index = random.uintLessThan(
        usize,
        available.items.len,
    );

    return available.items[index];
}

fn evaluate(
    ai: *const Ai,
    game: *const c6.Game,
    perspective_piece: c6.Piece,
) AiError!i32 {
    var total_score: i32 = 0;

    for (c6.Offset.to_end, c6.Offset.to_start) |forward, backward| {
        if (ai.isCanceled()) {
            return AiError.Canceled;
        }

        for (0..game.size.height) |row| {
            if (ai.isCanceled()) {
                return AiError.Canceled;
            }

            for (0..game.size.width) |column| {
                const point = c6.Point.init(row, column);
                const piece = game.pieceAtUnchecked(point) orelse continue;
                const before_point_maybe = point.offsetOrNull(game.size, backward);

                if (before_point_maybe) |before_point| {
                    if (game.pieceAtUnchecked(before_point) == piece) {
                        continue;
                    }
                }

                var run_length: usize = 0;
                var after_point_maybe: ?c6.Point = point;

                while (after_point_maybe) |after_point| {
                    if (game.pieceAtUnchecked(after_point) != piece) {
                        break;
                    }

                    run_length += 1;
                    after_point_maybe =
                        after_point.offsetOrNull(game.size, forward);
                }

                var open_ends: usize = 0;

                if (before_point_maybe) |before_point| {
                    if (game.pieceAtUnchecked(before_point) == null) {
                        open_ends += 1;
                    }
                }

                if (after_point_maybe) |after_point| {
                    if (game.pieceAtUnchecked(after_point) == null) {
                        open_ends += 1;
                    }
                }

                const run_score = scoreRun(
                    run_length,
                    open_ends,
                );

                if (piece == perspective_piece) {
                    total_score += run_score;
                } else {
                    total_score -= @divFloor(
                        run_score * 11,
                        10,
                    );
                }
            }
        }
    }

    return total_score;
}

fn scoreRun(
    run_length: usize,
    open_ends: usize,
) i32 {
    if (run_length >= 6) {
        return 1_000_000;
    }

    return switch (run_length) {
        5 => switch (open_ends) {
            2 => 100_000,
            1 => 30_000,
            else => 5_000,
        },
        4 => switch (open_ends) {
            2 => 10_000,
            1 => 3_000,
            else => 500,
        },
        3 => switch (open_ends) {
            2 => 500,
            1 => 100,
            else => 20,
        },
        2 => switch (open_ends) {
            2 => 50,
            1 => 15,
            else => 5,
        },
        else => 1,
    };
}
