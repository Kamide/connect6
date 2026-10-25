const std = @import("std");
const rl = @import("raylib");
const c6 = @import("connect6");

const title = "Connect6";

pub fn main(init: std.process.Init) !void {
    var app = App.init(init.gpa);
    defer app.deinit();
    try app.main();
}

const Screen = enum {
    main_menu,
    select_size,
    select_black,
    select_white,
    duel,
    credits,
    exit,
};

const Player = enum {
    human,
    ai,
};

const App = struct {
    allocator: std.mem.Allocator,
    screen: Screen = .main_menu,
    size: ?c6.Size = null,
    black: ?Player = null,
    white: ?Player = null,
    game: ?c6.Game = null,

    fn init(allocator: std.mem.Allocator) App {
        return .{ .allocator = allocator };
    }

    fn deinit(app: *App) void {
        if (app.game) |*game| {
            game.deinit();
        }
    }

    fn main(app: *App) !void {
        rl.setConfigFlags(.{
            .msaa_4x_hint = true,
            .window_maximized = true,
            .window_resizable = true,
        });

        rl.initWindow(1280, 720, title);
        defer rl.closeWindow();

        game_loop: while (!rl.windowShouldClose()) {
            switch (app.screen) {
                .main_menu => MainMenu.update(app),
                .select_size => SelectSize.update(app),
                .select_black => SelectBlack.update(app),
                .select_white => SelectWhite.update(app),
                .duel => Duel.update(app),
                .credits => Credits.update(app),
                .exit => break :game_loop,
            }

            if (app.screen == .exit) {
                break :game_loop;
            }

            rl.beginDrawing();
            defer rl.endDrawing();

            switch (app.screen) {
                .main_menu => MainMenu.render(app),
                .select_size => SelectSize.render(app),
                .select_black => SelectBlack.render(app),
                .select_white => SelectWhite.render(app),
                .duel => Duel.render(app),
                .credits => Credits.render(app),
                .exit => unreachable,
            }
        }
    }
};

const MainMenu = struct {
    fn update(app: *App) void {
        _ = app;
    }

    fn render(app: *App) void {
        _ = app;
    }
};

const SelectSize = struct {
    fn update(app: *App) void {
        _ = app;
    }

    fn render(app: *App) void {
        _ = app;
    }
};

const SelectBlack = struct {
    fn update(app: *App) void {
        _ = app;
    }

    fn render(app: *App) void {
        _ = app;
    }
};

const SelectWhite = struct {
    fn update(app: *App) void {
        _ = app;
    }

    fn render(app: *App) void {
        _ = app;
    }
};

const Duel = struct {
    fn update(app: *App) void {
        _ = app;
    }

    fn render(app: *App) void {
        _ = app;
    }
};

const Credits = struct {
    fn update(app: *App) void {
        _ = app;
    }

    fn render(app: *App) void {
        _ = app;
    }
};
