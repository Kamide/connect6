const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const c6 = @import("connect6");
const Ai = @import("Ai.zig");

const is_wasm = builtin.cpu.arch == .wasm32 or builtin.cpu.arch == .wasm64;

pub fn main(init: std.process.Init) !void {
    var seed: u64 = undefined;
    init.io.random(std.mem.asBytes(&seed));

    var app = App.init(init.gpa, init.io, seed);
    defer app.deinit();
    try app.main();
}

const Colors = struct {
    background: rl.Color,
    heading: rl.Color,
    subtitle: rl.Color,
    button_label: rl.Color,
    button_label_disabled: rl.Color,
    button: rl.Color,
    button_hover: rl.Color,
    button_pressed: rl.Color,
    button_primary: rl.Color,
    button_primary_hover: rl.Color,
    button_primary_pressed: rl.Color,
    line: rl.Color,
    highlight: rl.Color,

    fn init() Colors {
        return .{
            .background = .fromInt(0x48c4ccff),
            .heading = .fromInt(0xffffffff),
            .subtitle = .fromInt(0xfff4d6ff),
            .button_label = .fromInt(0x000000ff),
            .button_label_disabled = .fromInt(0x7a7a7aff),
            .button = .fromInt(0xf7d561ff),
            .button_hover = .fromInt(0xfceb9aff),
            .button_pressed = .fromInt(0xe89941ff),
            .button_primary = .fromInt(0xffffffff),
            .button_primary_hover = .fromInt(0xf0f0f0ff),
            .button_primary_pressed = .fromInt(0xd0d0d0ff),
            .line = .fromInt(0xe89941ff),
            .highlight = .fromInt(0xffffff7d),
        };
    }
};

const Language = enum {
    english,
    chinese,

    fn label(language: Language) [:0]const u8 {
        return switch (language) {
            .english => "English",
            .chinese => "中文",
        };
    }
};

const TextKey = enum {
    title,
    new_game,
    black_player,
    white_player,
    credits,
    language,
    start,
    exit,
    back,
    undo,
    redo,
    reset,
    human,
    ai,
    original_author,
    programmer,
    graphics,
    font,
    black_wins,
    white_wins,
    draw,
    black_to_play,
    white_to_play,

    fn get(key: TextKey, language: Language) [:0]const u8 {
        return switch (language) {
            .english => key.english(),
            .chinese => key.chinese(),
        };
    }

    fn english(key: TextKey) [:0]const u8 {
        return switch (key) {
            .title => "Connect6",
            .new_game => "New Game",
            .black_player => "Black Player",
            .white_player => "White Player",
            .credits => "Credits",
            .language => "Language",
            .start => "Start",
            .exit => "Exit",
            .back => "Back",
            .undo => "Undo",
            .redo => "Redo",
            .reset => "Reset",
            .human => "Human",
            .ai => "AI",
            .original_author => "Original Author: I-Chen Wu",
            .programmer => "Programmer: Kangming Deng",
            .graphics => "Graphics: raylib",
            .font => "Font: Resource Han Rounded",
            .black_wins => "Black Wins!",
            .white_wins => "White Wins!",
            .draw => "Draw!",
            .black_to_play => "Black to Play",
            .white_to_play => "White to Play",
        };
    }

    fn chinese(key: TextKey) [:0]const u8 {
        return switch (key) {
            .title => "六子棋",
            .new_game => "新游戏",
            .black_player => "黑方玩家",
            .white_player => "白方玩家",
            .credits => "制作人员",
            .language => "语言",
            .start => "开始",
            .exit => "退出",
            .back => "返回",
            .undo => "悔棋",
            .redo => "重做",
            .reset => "重开",
            .human => "人类",
            .ai => "电脑",
            .original_author => "原作者：吴毅成",
            .programmer => "编程：邓康明",
            .graphics => "图形：raylib",
            .font => "字体：资源圆体",
            .black_wins => "黑方获胜！",
            .white_wins => "白方获胜！",
            .draw => "平局！",
            .black_to_play => "黑方落子",
            .white_to_play => "白方落子",
        };
    }
};

const codepoints = collecting: {
    @setEvalBranchQuota(1_112_064);

    const languages = std.enums.values(Language);
    const keys = std.enums.values(TextKey);

    var capacity: usize = 95;

    for (languages) |language| {
        capacity += language.label().len;
    }

    for (keys) |key| {
        capacity += key.english().len + key.chinese().len;
    }

    const Storage = struct {
        items: [capacity]i32 = undefined,
        length: usize = 0,

        fn add(storage: *@This(), codepoint: i32) void {
            for (storage.items[0..storage.length]) |existing| {
                if (existing == codepoint) {
                    return;
                }
            }

            storage.items[storage.length] = codepoint;
            storage.length += 1;
        }

        fn addUtf8(storage: *@This(), string: []const u8) void {
            var index: usize = 0;

            while (index < string.len) {
                const size = std.unicode.utf8ByteSequenceLength(string[index]) catch {
                    index += 1;
                    continue;
                };

                if (index + size > string.len) {
                    break;
                }

                const codepoint = std.unicode.utf8Decode(
                    string[index .. index + size],
                ) catch {
                    index += 1;
                    continue;
                };

                storage.add(@intCast(codepoint));
                index += size;
            }
        }
    };

    var result = Storage{};

    for (0x20..0x7F) |codepoint| {
        result.add(@intCast(codepoint));
    }

    for (languages) |language| {
        result.addUtf8(language.label());
    }

    for (keys) |key| {
        result.addUtf8(key.english());
        result.addUtf8(key.chinese());
    }

    break :collecting result;
};

const Fonts = struct {
    const atlas_size: i32 = 64;

    default: rl.Font,

    fn init() !Fonts {
        const default = try rl.loadFontEx(
            "resources/fonts/ResourceHanRounded/CN/Heavy.ttf",
            atlas_size,
            codepoints.items[0..codepoints.length],
        );
        errdefer rl.unloadFont(default);
        return .{ .default = default };
    }

    fn update(fonts: *Fonts) void {
        rl.setTextureFilter(fonts.default.texture, .bilinear);
    }

    fn deinit(fonts: *Fonts) void {
        rl.unloadFont(fonts.default);
    }
};

const Textures = struct {
    grid: rl.Texture2D,
    shadow: rl.Texture2D,
    black: rl.Texture2D,
    white: rl.Texture2D,

    fn init() !Textures {
        const grid = try rl.loadTexture("resources/textures/grid.png");
        errdefer rl.unloadTexture(grid);

        const shadow = try rl.loadTexture("resources/textures/shadow.png");
        errdefer rl.unloadTexture(shadow);

        const black = try rl.loadTexture("resources/textures/black.png");
        errdefer rl.unloadTexture(black);

        const white = try rl.loadTexture("resources/textures/white.png");
        errdefer rl.unloadTexture(white);

        return .{
            .grid = grid,
            .shadow = shadow,
            .black = black,
            .white = white,
        };
    }

    fn deinit(textures: *Textures) void {
        inline for (.{
            textures.grid,
            textures.shadow,
            textures.black,
            textures.white,
        }) |texture| {
            rl.unloadTexture(texture);
        }
    }

    fn update(textures: *Textures) void {
        inline for (.{
            textures.grid,
            textures.shadow,
            textures.black,
            textures.white,
        }) |texture| {
            rl.setTextureFilter(texture, .bilinear);
        }
    }

    fn stone(textures: *const Textures, piece: c6.Piece) rl.Texture2D {
        return switch (piece) {
            .black => textures.black,
            .white => textures.white,
        };
    }
};

const Pointer = struct {
    position: rl.Vector2 = .zero(),
    down: bool = false,
    pressed: bool = false,
    released: bool = false,

    fn update(pointer: *Pointer) void {
        pointer.position = rl.getMousePosition();
        pointer.down = rl.isMouseButtonDown(.left);
        pointer.pressed = rl.isMouseButtonPressed(.left);
        pointer.released = rl.isMouseButtonReleased(.left);
    }
};

const Screen = enum {
    main_menu,
    select_size,
    select_black,
    select_white,
    duel,
    credits,
    select_language,
    exit,
};

const Player = enum {
    human,
    ai,
};

const Action = union(enum) {
    go: Screen,
    choose_size: c6.Size,
    choose_black: Player,
    choose_white: Player,

    fn perform(action: Action, app: *App) void {
        switch (action) {
            .go => |screen| app.screen = screen,
            .choose_size => |size| {
                app.size = size;
                app.screen = .select_black;
            },
            .choose_black => |player| {
                app.black = player;
                app.screen = .select_white;
            },
            .choose_white => |player| {
                app.white = player;
                app.startGame() catch |err| {
                    std.log.err("StartGameError: {any}", .{err});
                    app.screen = .main_menu;
                };
            },
        }
    }
};

const AiJob = struct {
    ai: ?*Ai = null,
    future: ?std.Io.Future(void) = null,
    done: std.atomic.Value(bool) = .init(true),
    result: ?c6.Point = null,
    discard_result: bool = false,
    snapshot: ?*c6.Game = null,

    fn isActive(job: *const AiJob) bool {
        return job.snapshot != null;
    }

    fn start(job: *AiJob, io: std.Io, ai: *Ai, game: *const c6.Game) !void {
        std.debug.assert(!job.isActive());
        std.debug.assert(job.future == null);
        std.debug.assert(job.ai == null);

        const snapshot = try game.clonePointer(game.allocator);
        errdefer snapshot.deinitPointer();

        ai.resetCancel();

        job.ai = ai;
        job.snapshot = snapshot;
        job.result = null;
        job.discard_result = false;
        job.done.store(false, .release);

        if (comptime is_wasm) {
            job.future = io.async(
                dispatch,
                .{ job, ai, snapshot },
            );
        } else {
            job.future = io.concurrent(
                dispatch,
                .{ job, ai, snapshot },
            ) catch |err| {
                std.log.err("AiJobStartFutureError: {any}", .{err});
                dispatch(job, ai, snapshot);
                return;
            };
        }
    }

    fn dispatch(job: *AiJob, ai: *Ai, game: *c6.Game) void {
        job.result = ai.chooseMove(game) catch null;
        job.done.store(true, .release);
    }

    fn poll(job: *AiJob, io: std.Io) ?c6.Point {
        if (!job.isActive() or !job.done.load(.acquire)) {
            return null;
        }

        if (job.future) |*future| {
            future.await(io);
            job.future = null;
        }

        if (job.snapshot) |snapshot| {
            snapshot.deinitPointer();
            job.snapshot = null;
        }

        job.ai = null;

        const result = if (job.discard_result) null else job.result;
        job.result = null;
        job.discard_result = false;
        return result;
    }

    fn invalidate(job: *AiJob) void {
        if (job.isActive()) {
            job.discard_result = true;

            if (job.ai) |ai| {
                ai.requestCancel();
            }
        }
    }

    fn cancel(job: *AiJob, io: std.Io) void {
        if (job.ai) |ai| {
            ai.requestCancel();
        }

        if (job.future) |*future| {
            future.await(io);
            job.future = null;
        }

        if (job.snapshot) |snapshot| {
            snapshot.deinitPointer();
            job.snapshot = null;
        }

        job.ai = null;
        job.result = null;
        job.discard_result = false;
        job.done.store(true, .release);
    }
};

const App = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    colors: Colors,
    prng: std.Random.DefaultPrng,
    fonts: Fonts = undefined,
    textures: Textures = undefined,
    viewport: rl.Rectangle = .init(0, 0, 0, 0),
    frame_time: f32 = 0.0,
    pointer: Pointer = .{},
    screen: Screen = .main_menu,
    language: Language = .english,
    size: ?c6.Size = null,
    black: ?Player = null,
    white: ?Player = null,
    game: ?c6.Game = null,
    ai: ?Ai = null,
    ai_job: AiJob = .{},
    ai_pending_move: ?c6.Point = null,
    ai_move_revealed: bool = false,
    ai_reveal_timer: f32 = 0.0,
    ai_think_timer: f32 = 0.0,
    ai_hover_timer: f32 = 0.0,
    ai_hover_point: ?c6.Point = null,
    shake: ShakeAnimation = .{},
    redo_stack: std.ArrayList(c6.Point) = .empty,

    fn init(allocator: std.mem.Allocator, io: std.Io, seed: u64) App {
        return .{
            .allocator = allocator,
            .io = io,
            .colors = .init(),
            .prng = .init(seed),
        };
    }

    fn deinit(app: *App) void {
        app.ai_job.cancel(app.io);
        if (app.game) |*game| {
            game.deinit();
        }
        app.redo_stack.deinit(app.allocator);
    }

    fn main(app: *App) !void {
        rl.setConfigFlags(.{
            .msaa_4x_hint = true,
            .vsync_hint = true,
            .window_resizable = true,
        });

        rl.initWindow(1280, 720, TextKey.title.get(.english));
        defer rl.closeWindow();

        rl.setExitKey(.null);
        rl.maximizeWindow();

        app.fonts = try Fonts.init();
        defer app.fonts.deinit();
        app.fonts.update();

        app.textures = try Textures.init();
        defer app.textures.deinit();
        app.textures.update();

        while (!rl.windowShouldClose() and app.screen != .exit) {
            rl.beginDrawing();
            defer rl.endDrawing();
            app.draw();
        }
    }

    fn draw(app: *App) void {
        app.viewport.width = @floatFromInt(rl.getScreenWidth());
        app.viewport.height = @floatFromInt(rl.getScreenHeight());
        app.frame_time = rl.getFrameTime();
        app.pointer.update();

        rl.clearBackground(app.colors.background);

        switch (app.screen) {
            .main_menu => MainMenu.draw(app),
            .select_size => SelectSize.draw(app),
            .select_black => SelectBlack.draw(app),
            .select_white => SelectWhite.draw(app),
            .duel => Duel.draw(app),
            .select_language => SelectLanguage.draw(app),
            .credits => Credits.draw(app),
            .exit => unreachable,
        }
    }

    fn startGame(app: *App) !void {
        app.cancelAiTurn();

        const size = app.size orelse return c6.Error.InvalidSize;
        const new_game = try c6.Game.init(app.allocator, size);

        if (app.game) |*old_game| {
            old_game.deinit();
        }

        app.game = new_game;
        app.shake = .{};
        app.redo_stack.clearRetainingCapacity();

        const black_is_ai = if (app.black) |player| player == .ai else false;
        const white_is_ai = if (app.white) |player| player == .ai else false;

        if (black_is_ai or white_is_ai) {
            const random = app.prng.random();
            const seed = random.int(u64);
            const temperature = 0.05 + random.float(f64) * 0.15;

            const search_depth = if (comptime is_wasm)
                1
            else
                random.intRangeAtMost(usize, 1, 2);

            app.ai = .init(app.allocator, seed, temperature, search_depth);
        } else {
            app.ai = null;
        }

        app.screen = .duel;
    }

    const ThinkingRegion = enum {
        adjacent,
        nearby,
        distant,
        any,
    };

    fn beginAiThinking(app: *App, game: *const c6.Game, size: c6.Size) void {
        const random = app.prng.random();
        const count = game.piecesPlayed();

        if (count == 0) {
            app.ai_think_timer = 0.25 + random.float(f32) * 0.25;
        } else if (c6.isOdd(count)) {
            app.ai_think_timer = 0.25 + random.float(f32) * 1;

            if (random.float(f32) < 0.25) {
                app.ai_think_timer += 0.5 + random.float(f32) * 0.5;
            }
        } else {
            app.ai_think_timer = 0.25 + random.float(f32) * 0.5;
        }

        app.ai_hover_timer = 0.0;
        app.ai_hover_point = app.randomThinkingPoint(game, size, null);
    }

    fn updateAiThinking(app: *App, game: *const c6.Game, size: c6.Size) void {
        app.ai_think_timer = @max(0.0, app.ai_think_timer - app.frame_time);
        app.ai_hover_timer -= app.frame_time;

        if (app.ai_hover_timer <= 0.0) {
            app.ai_hover_point = app.randomThinkingPoint(
                game,
                size,
                app.ai_hover_point,
            );

            const random = app.prng.random();

            app.ai_hover_timer = 0.10 + random.float(f32) * 0.15;

            if (random.float(f32) < 0.15) {
                app.ai_hover_timer += 0.20 + random.float(f32) * 0.35;
            }
        }
    }

    fn randomThinkingPoint(
        app: *App,
        game: *const c6.Game,
        size: c6.Size,
        avoid: ?c6.Point,
    ) ?c6.Point {
        const random = app.prng.random();
        const roll = random.float(f32);

        const preferred: ThinkingRegion = if (roll < 0.4)
            .adjacent
        else if (roll < 0.8)
            .nearby
        else
            .distant;

        if (app.randomEmptyPointInRegion(game, size, preferred, avoid)) |point| {
            return point;
        }

        const fallbacks = [_]ThinkingRegion{ .adjacent, .nearby, .distant, .any };
        for (fallbacks) |region| {
            if (region == preferred) {
                continue;
            }
            if (app.randomEmptyPointInRegion(game, size, region, avoid)) |point| {
                return point;
            }
        }

        return app.randomEmptyPointInRegion(game, size, .any, null);
    }

    fn randomEmptyPointInRegion(
        app: *App,
        game: *const c6.Game,
        size: c6.Size,
        region: ThinkingRegion,
        avoid: ?c6.Point,
    ) ?c6.Point {
        var selected: ?c6.Point = null;
        var seen: usize = 0;
        const random = app.prng.random();

        for (0..size.height) |row| {
            for (0..size.width) |column| {
                const point = c6.Point.init(row, column);
                if ((game.pieceAt(point) catch continue) != null) {
                    continue;
                }

                if (avoid) |previous| {
                    if (point.row == previous.row and point.column == previous.column) {
                        continue;
                    }
                }

                const adjacent = hasOccupiedNeighbor(game, size, point, 1);
                const nearby = adjacent or hasOccupiedNeighbor(game, size, point, 2);

                const matches = switch (region) {
                    .adjacent => adjacent,
                    .nearby => nearby and !adjacent,
                    .distant => !nearby,
                    .any => true,
                };
                if (!matches) {
                    continue;
                }

                seen += 1;
                if (random.uintLessThan(usize, seen) == 0) {
                    selected = point;
                }
            }
        }

        return selected;
    }

    fn hasOccupiedNeighbor(
        game: *const c6.Game,
        size: c6.Size,
        point: c6.Point,
        radius: usize,
    ) bool {
        const row_start = if (point.row >= radius) point.row - radius else 0;
        const column_start = if (point.column >= radius) point.column - radius else 0;
        const row_end = @min(point.row + radius, size.height - 1);
        const column_end = @min(point.column + radius, size.width - 1);

        var row = row_start;
        while (row <= row_end) : (row += 1) {
            var column = column_start;
            while (column <= column_end) : (column += 1) {
                if (row == point.row and column == point.column) {
                    continue;
                }

                const neighbor = c6.Point.init(row, column);
                if ((game.pieceAt(neighbor) catch continue) != null) {
                    return true;
                }
            }
        }

        return false;
    }

    fn undo(app: *App, game: *c6.Game) void {
        if (game.undo()) |point| {
            app.invalidateAiTurn();
            app.redo_stack.append(app.allocator, point) catch |err| {
                std.log.err("RedoStackAppendError: {any}", .{err});
            };
        }
        app.shake = .{};
    }

    fn redo(app: *App, game: *c6.Game) void {
        app.invalidateAiTurn();
        if (app.redo_stack.getLastOrNull()) |point| {
            game.play(point) catch |err| {
                std.log.err("RedoPlayError: {any}, {any}", .{ point, err });
                return;
            };
            _ = app.redo_stack.pop();
            app.shake = .{};
        }
    }

    fn play(app: *App, game: *c6.Game, point: c6.Point) void {
        app.invalidateAiTurn();
        game.play(point) catch |err| {
            std.log.err("PlayPointError: {any}, {any}", .{ point, err });
            return;
        };
        app.redo_stack.clearRetainingCapacity();
    }

    fn reset(app: *App, game: *c6.Game) void {
        app.invalidateAiTurn();
        game.reset();
        app.redo_stack.clearRetainingCapacity();
        app.shake = .{};
    }

    fn resetAiState(app: *App) void {
        app.ai_pending_move = null;
        app.ai_move_revealed = false;
        app.ai_reveal_timer = 0.0;
        app.ai_think_timer = 0.0;
        app.ai_hover_timer = 0.0;
        app.ai_hover_point = null;
    }

    fn invalidateAiTurn(app: *App) void {
        app.ai_job.invalidate();
        app.resetAiState();
    }

    fn cancelAiTurn(app: *App) void {
        app.ai_job.cancel(app.io);
        app.resetAiState();
    }
};

const Layout = struct {
    const max_width = 360.0;
    const button_height = 56.0;
    const button_gap = 13.0;
    const menu_center = 0.55;
    const back_center = 0.88;
    const title_y = 0.12;

    fn width(app: *const App) f32 {
        return @min(max_width, app.viewport.width);
    }

    fn x(app: *const App) f32 {
        return (app.viewport.width - width(app)) * 0.5;
    }

    fn titleY(app: *const App) f32 {
        return app.viewport.height * title_y;
    }

    fn menuHeight(count: usize) f32 {
        if (count == 0) {
            return 0;
        }
        const n: f32 = @floatFromInt(count);
        return n * button_height + (n - 1) * button_gap;
    }

    fn menuGrid(app: *const App, count: usize) Grid {
        return menuGridAt(app, menu_center, count);
    }

    fn menuGridAt(app: *const App, center: f32, count: usize) Grid {
        const height = menuHeight(count);
        return Grid.init(
            .init(
                x(app),
                app.viewport.height * center - height * 0.5,
                width(app),
                height,
            ),
            count,
            1,
        ).withSpacing(.init(0, button_gap));
    }

    fn backGrid(app: *const App) Grid {
        return menuGridAt(app, back_center, 1);
    }
};

const Grid = struct {
    bounds: rl.Rectangle,
    rows: usize,
    columns: usize,
    gap: rl.Vector2 = .zero(),

    fn init(bounds: rl.Rectangle, rows: usize, columns: usize) Grid {
        std.debug.assert(rows > 0);
        std.debug.assert(columns > 0);

        return .{
            .bounds = bounds,
            .rows = rows,
            .columns = columns,
        };
    }

    fn withSpacing(grid: Grid, gap: rl.Vector2) Grid {
        var result = grid;
        result.gap = gap;
        return result;
    }

    fn cell(grid: Grid, row: usize, column: usize) rl.Rectangle {
        std.debug.assert(row < grid.rows);
        std.debug.assert(column < grid.columns);

        const rows: f32 = @floatFromInt(grid.rows);
        const columns: f32 = @floatFromInt(grid.columns);
        const row_index: f32 = @floatFromInt(row);
        const column_index: f32 = @floatFromInt(column);

        const width = (grid.bounds.width - grid.gap.x * (columns - 1)) / columns;
        const height = (grid.bounds.height - grid.gap.y * (rows - 1)) / rows;

        return .init(
            grid.bounds.x + column_index * (width + grid.gap.x),
            grid.bounds.y + row_index * (height + grid.gap.y),
            width,
            height,
        );
    }
};

const Text = struct {
    label: [:0]const u8,
    position: rl.Vector2 = .zero(),
    font_size: i32 = 22,
    tint: ?rl.Color = null,
    font: ?rl.Font = null,

    fn init(label: [:0]const u8) Text {
        return .{ .label = label };
    }

    fn withPosition(text: Text, x: f32, y: f32) Text {
        var result = text;
        result.position = .init(x, y);
        return result;
    }

    fn withY(text: Text, y: f32) Text {
        var result = text;
        result.position.y = y;
        return result;
    }

    fn withSize(text: Text, font_size: i32) Text {
        var result = text;
        result.font_size = font_size;
        return result;
    }

    fn withColor(text: Text, tint: rl.Color) Text {
        var result = text;
        result.tint = tint;
        return result;
    }

    fn withFont(text: Text, font: rl.Font) Text {
        var result = text;
        result.font = font;
        return result;
    }

    fn measure(text: Text, app: *const App) rl.Vector2 {
        const font = text.font orelse app.fonts.default;
        return rl.measureTextEx(
            font,
            text.label,
            @floatFromInt(text.font_size),
            0,
        );
    }

    fn draw(text: Text, app: *const App) void {
        const font = text.font orelse app.fonts.default;
        const resolved = text.tint orelse app.colors.heading;
        rl.drawTextEx(
            font,
            text.label,
            text.position,
            @floatFromInt(text.font_size),
            0,
            resolved,
        );
    }

    fn drawCentered(text: Text, app: *const App) void {
        const dimensions = text.measure(app);
        var result = text;
        result.position.x = (app.viewport.width - dimensions.x) * 0.5;
        result.draw(app);
    }
};

const Button = struct {
    const Variant = enum { default, primary };

    label: [:0]const u8,
    bounds: rl.Rectangle = .init(0, 0, 0, 0),
    enabled: bool = true,
    variant: Variant = .default,

    fn init(label: [:0]const u8) Button {
        return .{ .label = label };
    }

    fn withBounds(button: Button, bounds: rl.Rectangle) Button {
        var result = button;
        result.bounds = bounds;
        return result;
    }

    fn withDisabled(button: Button) Button {
        var result = button;
        result.enabled = false;
        return result;
    }

    fn withPrimary(button: Button) Button {
        var result = button;
        result.variant = .primary;
        return result;
    }

    fn hovered(button: Button, pointer: Pointer) bool {
        return button.enabled and contains(button.bounds, pointer.position);
    }

    fn pressed(button: Button, pointer: Pointer) bool {
        return button.hovered(pointer) and pointer.down;
    }

    fn clicked(button: Button, pointer: Pointer) bool {
        return button.hovered(pointer) and pointer.released;
    }

    fn fillColor(button: Button, app: *const App) rl.Color {
        const hover = button.hovered(app.pointer);
        const active = button.pressed(app.pointer);

        return switch (button.variant) {
            .default => if (active)
                app.colors.button_pressed
            else if (hover)
                app.colors.button_hover
            else
                app.colors.button,
            .primary => if (active)
                app.colors.button_primary_pressed
            else if (hover)
                app.colors.button_primary_hover
            else
                app.colors.button_primary,
        };
    }

    fn draw(button: Button, app: *const App) Button {
        const active = button.pressed(app.pointer);

        const face = rl.Rectangle.init(
            button.bounds.x,
            button.bounds.y + @as(f32, if (active) 2.0 else 0.0),
            button.bounds.width,
            button.bounds.height,
        );

        rl.drawRectangleRounded(face, 1, 8, button.fillColor(app));

        const button_font_size: i32 = 22;
        const text_dim = rl.measureTextEx(
            app.fonts.default,
            button.label,
            @floatFromInt(button_font_size),
            0,
        );

        Text.init(button.label)
            .withPosition(
                face.x + (face.width - text_dim.x) * 0.5,
                face.y + (face.height - text_dim.y) * 0.5,
            )
            .withSize(button_font_size)
            .withColor(if (button.enabled)
                app.colors.button_label
            else
                app.colors.button_label_disabled)
            .draw(app);

        return button;
    }
};

const MenuButton = struct {
    label: TextKey,
    action: Action,
    disabled: bool = false,
    primary: bool = false,
};

const MenuScreen = struct {
    title: TextKey,
    title_size: i32 = 36,
    buttons: []const MenuButton,
};

fn drawMenuScreen(app: *App, screen: MenuScreen) void {
    drawScreenTitle(app, screen.title, screen.title_size);

    const grid = Layout.menuGrid(app, screen.buttons.len);

    for (screen.buttons, 0..) |properties, index| {
        var button = Button.init(properties.label.get(app.language))
            .withBounds(grid.cell(index, 0));
        if (properties.disabled) {
            button = button.withDisabled();
        }
        if (properties.primary) {
            button = button.withPrimary();
        }
        if (button.draw(app).clicked(app.pointer)) {
            properties.action.perform(app);
        }
    }
}

fn drawScreenTitle(app: *const App, text: TextKey, size_px: i32) void {
    Text.init(text.get(app.language))
        .withY(Layout.titleY(app))
        .withSize(size_px)
        .drawCentered(app);
}

fn drawBackButton(app: *App, action: Action) void {
    if (rl.isKeyPressed(.escape)) {
        action.perform(app);
    }

    const grid = Layout.backGrid(app);

    if (Button.init(TextKey.back.get(app.language))
        .withBounds(grid.cell(0, 0))
        .draw(app)
        .clicked(app.pointer))
    {
        action.perform(app);
    }
}

const main_menu_screen = MenuScreen{
    .title = .title,
    .title_size = 58,
    .buttons = &.{
        .{ .label = .start, .action = .{ .go = .select_size }, .primary = true },
        .{ .label = .language, .action = .{ .go = .select_language } },
        .{ .label = .credits, .action = .{ .go = .credits } },
        .{ .label = .exit, .action = .{ .go = .exit }, .disabled = is_wasm },
    },
};

const MainMenu = struct {
    fn draw(app: *App) void {
        drawMenuScreen(app, main_menu_screen);
    }
};

const SelectSize = struct {
    const sizes = [_]c6.Size{
        .square(19),
        .square(15),
        .square(13),
        .square(11),
        .square(9),
    };

    const labels = [_][:0]const u8{
        "19 x 19",
        "15 x 15",
        "13 x 13",
        "11 x 11",
        "9 x 9",
    };

    fn draw(app: *App) void {
        drawScreenTitle(app, .new_game, 36);

        const grid = Layout.menuGrid(app, labels.len);
        for (labels, 0..) |label, index| {
            if (Button.init(label)
                .withBounds(grid.cell(index, 0))
                .draw(app)
                .clicked(app.pointer))
            {
                (Action{ .choose_size = sizes[index] }).perform(app);
            }
        }

        drawBackButton(app, .{ .go = .main_menu });
    }
};

const select_black_screen = MenuScreen{
    .title = .black_player,
    .buttons = &.{
        .{ .label = .human, .action = .{ .choose_black = .human } },
        .{ .label = .ai, .action = .{ .choose_black = .ai } },
        .{ .label = .back, .action = .{ .go = .select_size } },
    },
};

const SelectBlack = struct {
    fn draw(app: *App) void {
        if (rl.isKeyPressed(.escape)) {
            app.screen = .select_size;
        }

        drawMenuScreen(app, select_black_screen);
    }
};

const select_white_screen = MenuScreen{
    .title = .white_player,
    .buttons = &.{
        .{ .label = .human, .action = .{ .choose_white = .human } },
        .{ .label = .ai, .action = .{ .choose_white = .ai } },
        .{ .label = .back, .action = .{ .go = .select_black } },
    },
};

const SelectWhite = struct {
    fn draw(app: *App) void {
        if (rl.isKeyPressed(.escape)) {
            app.screen = .select_black;
        }

        drawMenuScreen(app, select_white_screen);
    }
};

const SelectLanguage = struct {
    const options = std.enums.values(Language);

    fn draw(app: *App) void {
        if (rl.isKeyPressed(.escape)) {
            app.screen = .main_menu;
        }

        drawScreenTitle(app, .language, 36);

        const grid = Layout.menuGrid(app, options.len + 1);

        for (options, 0..) |language, index| {
            var button = Button.init(language.label())
                .withBounds(grid.cell(index, 0));

            if (app.language == language) {
                button = button.withPrimary();
            }

            if (button.draw(app).clicked(app.pointer)) {
                app.language = language;
                rl.setWindowTitle(TextKey.title.get(language));
            }
        }

        if (Button.init(TextKey.back.get(app.language))
            .withBounds(grid.cell(options.len, 0))
            .draw(app)
            .clicked(app.pointer))
        {
            app.screen = .main_menu;
        }
    }
};

const Credits = struct {
    fn draw(app: *App) void {
        drawScreenTitle(app, .credits, 36);

        Text.init(TextKey.original_author.get(app.language))
            .withY(app.viewport.height * 0.42)
            .withSize(30)
            .drawCentered(app);

        Text.init(TextKey.programmer.get(app.language))
            .withY(app.viewport.height * 0.48)
            .withSize(30)
            .drawCentered(app);

        Text.init(TextKey.graphics.get(app.language))
            .withY(app.viewport.height * 0.54)
            .withSize(30)
            .withColor(app.colors.subtitle)
            .drawCentered(app);

        Text.init(TextKey.font.get(app.language))
            .withY(app.viewport.height * 0.60)
            .withSize(30)
            .withColor(app.colors.subtitle)
            .drawCentered(app);

        drawBackButton(app, .{ .go = .main_menu });
    }
};

const Duel = struct {
    const button_width: f32 = 100;
    const button_height: f32 = 48;
    const button_gap: f32 = 12;

    const back_button_width: f32 = 100;
    const back_button_height: f32 = 44;

    const corner_pad: f32 = 20;
    const status_stone_gap: f32 = 28;

    const footer_height: f32 = button_height + corner_pad * 2;

    fn draw(app: *App) void {
        const game = if (app.game) |*game_maybe| game_maybe else return;
        const size = app.size orelse return;

        app.shake.update(app);

        if (rl.isKeyPressed(.escape)) {
            app.cancelAiTurn();
            app.screen = .main_menu;
        }

        if (!app.ai_job.discard_result and
            (app.ai_job.isActive() or
                (app.ai_pending_move != null and
                    app.ai_think_timer > 0.0)))
        {
            app.updateAiThinking(game, size);
        }

        if (app.ai_job.poll(app.io)) |move| {
            app.ai_pending_move = move;
            app.ai_move_revealed = false;
            app.ai_reveal_timer = 0.0;
        }

        if (app.ai_pending_move) |move| {
            if (app.ai_think_timer <= 0.0) {
                if (!app.ai_move_revealed) {
                    app.ai_hover_point = move;
                    app.ai_move_revealed = true;
                    app.ai_reveal_timer = 0.3;
                } else {
                    app.ai_reveal_timer = @max(
                        0.0,
                        app.ai_reveal_timer - app.frame_time,
                    );

                    if (app.ai_reveal_timer == 0.0) {
                        game.play(move) catch |err| {
                            std.log.err("AiPlayError: {any}, {any}", .{ move, err });
                        };

                        app.redo_stack.clearRetainingCapacity();
                        app.ai_pending_move = null;
                        app.ai_move_revealed = false;
                        app.ai_hover_point = null;
                    }
                }
            }
        }

        const over = game.isOver();
        const ai_turn = !over and isAiTurn(app, game);

        if (ai_turn and
            !app.ai_job.isActive() and
            app.ai_pending_move == null and
            app.redo_stack.items.len == 0)
        {
            if (app.ai) |*ai| {
                app.ai_job.start(app.io, ai, game) catch |err| {
                    std.log.err("AiStartError: {any}", .{err});
                };
                if (app.ai_job.isActive()) {
                    app.beginAiThinking(game, size);
                }
            }
        }

        const busy = app.ai_job.isActive() or app.ai_pending_move != null;
        const human_turn = !over and !ai_turn and !busy;

        if (game.canUndo() and rl.isKeyPressed(.z)) {
            app.undo(game);
        }
        if (!busy and rl.isKeyPressed(.x)) {
            app.redo(game);
        }
        if (rl.isKeyPressed(.c)) {
            app.reset(game);
        }

        drawStatus(app, game);

        if (drawBackControl(app)) {
            return;
        }

        drawControls(app, game, busy);

        const geometry = calculateBoardGeometry(app, size);

        if (human_turn and app.pointer.pressed) {
            if (geometry.mouseToPoint(app.pointer.position)) |point| {
                playing: {
                    if ((game.pieceAt(point) catch break :playing) != null) {
                        app.shake.trigger(point);
                    } else {
                        app.play(game, point);
                    }
                }
            }
        }

        drawBoard(game, &app.textures, geometry, app, human_turn, app.ai_hover_point);
    }

    fn isAiTurn(app: *const App, game: *const c6.Game) bool {
        return switch (game.currentPlayer()) {
            .black => (app.black orelse .human) == .ai,
            .white => (app.white orelse .human) == .ai,
        };
    }

    fn drawBackControl(app: *App) bool {
        const bounds = rl.Rectangle.init(
            app.viewport.width - back_button_width - corner_pad,
            corner_pad,
            back_button_width,
            back_button_height,
        );

        if (Button.init(TextKey.back.get(app.language))
            .withBounds(bounds)
            .draw(app)
            .clicked(app.pointer))
        {
            app.cancelAiTurn();
            app.screen = .main_menu;
            return true;
        }

        return false;
    }

    fn statusString(game: *const c6.Game) TextKey {
        if (game.winner()) |winner| {
            return switch (winner) {
                .black => .black_wins,
                .white => .white_wins,
            };
        }
        if (game.isDraw()) {
            return .draw;
        }
        return switch (game.currentPlayer()) {
            .black => .black_to_play,
            .white => .white_to_play,
        };
    }

    fn drawStatus(app: *const App, game: *const c6.Game) void {
        const label = statusString(game).get(app.language);
        const status_font_size: i32 = 28;

        Text.init(label)
            .withPosition(corner_pad * 1.5, corner_pad)
            .withSize(status_font_size)
            .draw(app);

        if (!game.isOver()) {
            const text_dim = rl.measureTextEx(
                app.fonts.default,
                label,
                @floatFromInt(status_font_size),
                0,
            );

            drawTextureCentered(
                app.textures.stone(game.currentPlayer()),
                .init(
                    corner_pad + text_dim.x + status_stone_gap,
                    corner_pad + @as(f32, status_font_size) / 2 + 2,
                ),
                @floatFromInt(status_font_size),
                .white,
            );
        }
    }

    fn drawControls(app: *App, game: *c6.Game, busy: bool) void {
        const buttons = [_]TextKey{ .undo, .redo, .reset };

        const count: f32 = @floatFromInt(buttons.len);
        const total_width = count * button_width + (count - 1) * button_gap;

        var x = (app.viewport.width - total_width) * 0.5;
        const y = app.viewport.height - button_height - corner_pad;

        for (buttons) |key| {
            const bounds = rl.Rectangle.init(
                x,
                y,
                button_width,
                button_height,
            );

            var button = Button.init(key.get(app.language))
                .withBounds(bounds);

            if (key == .undo and !game.canUndo()) {
                button = button.withDisabled();
            }

            if (key == .redo and (busy or app.redo_stack.items.len == 0)) {
                button = button.withDisabled();
            }

            if (button.draw(app).clicked(app.pointer)) {
                switch (key) {
                    .undo => app.undo(game),
                    .redo => app.redo(game),
                    .reset => app.reset(game),
                    else => unreachable,
                }
            }

            x += button_width + button_gap;
        }
    }
};

const ShakeAnimation = struct {
    point: ?c6.Point = null,
    remaining: f32 = 0.0,

    const duration = 0.28;
    const amplitude = 5.0;
    const frequency = 95.0;

    fn trigger(shake: *ShakeAnimation, at_point: c6.Point) void {
        shake.point = at_point;
        shake.remaining = duration;
    }

    fn update(shake: *ShakeAnimation, app: *const App) void {
        if (!shake.isActive()) {
            return;
        }

        shake.remaining = @max(0.0, shake.remaining - app.frame_time);

        if (shake.remaining == 0.0) {
            shake.point = null;
        }
    }

    fn isActive(shake: *const ShakeAnimation) bool {
        return shake.point != null and shake.remaining > 0.0;
    }

    fn offset(shake: *const ShakeAnimation) rl.Vector2 {
        if (!shake.isActive()) {
            return .zero();
        }

        const progress = shake.remaining / duration;
        const fade = progress * amplitude;

        return .init(
            @sin(shake.remaining * frequency) * fade,
            @cos(shake.remaining * frequency * 1.37) * fade,
        );
    }
};

const BoardGeometry = struct {
    x: f32,
    y: f32,
    spacing: f32,
    size: c6.Size,
    padding: f32,

    fn width(geometry: BoardGeometry) f32 {
        return @as(f32, @floatFromInt(geometry.size.width - 1)) * geometry.spacing;
    }

    fn height(geometry: BoardGeometry) f32 {
        return @as(f32, @floatFromInt(geometry.size.height - 1)) * geometry.spacing;
    }

    fn bounds(geometry: BoardGeometry) rl.Rectangle {
        return .init(
            geometry.x - geometry.padding,
            geometry.y - geometry.padding,
            geometry.width() + geometry.padding * 2,
            geometry.height() + geometry.padding * 2,
        );
    }

    fn position(geometry: BoardGeometry, point: c6.Point) rl.Vector2 {
        return .init(
            geometry.x + @as(f32, @floatFromInt(point.column)) * geometry.spacing,
            geometry.y + @as(f32, @floatFromInt(point.row)) * geometry.spacing,
        );
    }

    fn mouseToPoint(geometry: BoardGeometry, mouse: rl.Vector2) ?c6.Point {
        const dx = mouse.x - geometry.x;
        const dy = mouse.y - geometry.y;

        if (dx < -geometry.spacing * 0.5 or
            dy < -geometry.spacing * 0.5 or
            dx > geometry.width() + geometry.spacing * 0.5 or
            dy > geometry.height() + geometry.spacing * 0.5)
        {
            return null;
        }

        const column: usize = @intFromFloat(@round(dx / geometry.spacing));
        const row: usize = @intFromFloat(@round(dy / geometry.spacing));

        if (row >= geometry.size.height or column >= geometry.size.width) {
            return null;
        }

        return .init(row, column);
    }
};

fn calculateBoardGeometry(app: *const App, size: c6.Size) BoardGeometry {
    const sw = app.viewport.width;
    const sh = app.viewport.height;

    const margin = @min(sw, sh) * 0.045;
    const header = 82.0;
    const footer = Duel.footer_height;

    const columns: f32 = @floatFromInt(size.width - 1);
    const rows: f32 = @floatFromInt(size.height - 1);

    const available_width = @max(1.0, sw - margin * 2);
    const available_height = @max(1.0, sh - header - footer - margin * 2);

    const spacing = @min(
        available_width / (columns + 1),
        available_height / (rows + 1),
    );

    const board_width = columns * spacing;
    const board_height = rows * spacing;

    return .{
        .x = (sw - board_width) * 0.5,
        .y = header + (sh - header - footer - board_height) * 0.5,
        .spacing = spacing,
        .size = size,
        .padding = spacing * 0.5,
    };
}

fn drawBoard(
    game: *const c6.Game,
    textures: *const Textures,
    geometry: BoardGeometry,
    app: *const App,
    match_pointer_hover: bool,
    ai_hover_point: ?c6.Point,
) void {
    drawGrid(textures.grid, geometry.bounds(), geometry);

    for (game.lines) |line_maybe| {
        const line = line_maybe orelse continue;

        rl.drawLineEx(
            geometry.position(line.start),
            geometry.position(line.end),
            geometry.spacing * 0.12,
            app.colors.line,
        );
    }

    for (game.points.items) |point| {
        const piece = (game.pieceAt(point) catch continue) orelse continue;

        var stone_position = geometry.position(point);

        if (app.shake.point) |shake_point| {
            if (shake_point.row == point.row and
                shake_point.column == point.column)
            {
                stone_position = stone_position.add(app.shake.offset());
            }
        }

        drawTextureCentered(
            textures.shadow,
            .init(
                stone_position.x - geometry.spacing * 0.025,
                stone_position.y + geometry.spacing * 0.1,
            ),
            geometry.spacing,
            .white,
        );

        drawTextureCentered(
            textures.stone(piece),
            stone_position,
            geometry.spacing,
            .white,
        );
    }

    const hover_point_maybe = if (match_pointer_hover)
        geometry.mouseToPoint(app.pointer.position)
    else
        ai_hover_point;

    if (hover_point_maybe) |hover_point| {
        drawing: {
            if ((game.pieceAt(hover_point) catch break :drawing) == null) {
                drawTextureCentered(
                    textures.stone(game.currentPlayer()),
                    geometry.position(hover_point),
                    geometry.spacing,
                    app.colors.highlight,
                );
            }
        }
    }
}

fn drawTextureCentered(
    texture: rl.Texture2D,
    center: rl.Vector2,
    size_px: f32,
    tint: rl.Color,
) void {
    const width: f32 = @floatFromInt(texture.width);
    const height: f32 = @floatFromInt(texture.height);
    const scale = size_px / @max(width, height);

    rl.drawTexturePro(
        texture,
        .init(0, 0, width, height),
        .init(
            center.x - width * scale * 0.5,
            center.y - height * scale * 0.5,
            width * scale,
            height * scale,
        ),
        .zero(),
        0,
        tint,
    );
}

fn drawGrid(
    texture: rl.Texture2D,
    bounds: rl.Rectangle,
    geometry: BoardGeometry,
) void {
    const width: f32 = @floatFromInt(texture.width);
    const height: f32 = @floatFromInt(texture.height);

    rl.drawTexturePro(
        texture,
        .init(
            0,
            0,
            bounds.width / geometry.spacing * width,
            bounds.height / geometry.spacing * height,
        ),
        bounds,
        .zero(),
        0,
        .white,
    );
}

fn contains(rectangle: rl.Rectangle, point: rl.Vector2) bool {
    return rectangle.checkCollision(.init(point.x, point.y, 1, 1));
}
