const std = @import("std");
const rl = @import("raylib");
const c6 = @import("connect6");

const title = "Connect6";

pub fn main(init: std.process.Init) !void {
    var app = App.init(init.gpa);
    defer app.deinit();
    try app.main();
}

const Colors = struct {
    background: rl.Color,

    fn init() Colors {
        return .{
            .background = .fromInt(0x48c4ccff),
        };
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
};

const Frame = struct {
    delta_time: f32 = 0.0,

    fn update(frame: *Frame) void {
        frame.delta_time = rl.getFrameTime();
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
    exit,
};

const Player = enum {
    human,
    ai,
};

const App = struct {
    allocator: std.mem.Allocator,
    colors: Colors,
    frame: Frame = .{},
    pointer: Pointer = .{},
    screen: Screen = .main_menu,
    size: ?c6.Size = null,
    black: ?Player = null,
    white: ?Player = null,
    game: ?c6.Game = null,

    fn init(allocator: std.mem.Allocator) App {
        return .{
            .allocator = allocator,
            .colors = .init(),
        };
    }

    fn deinit(app: *App) void {
        if (app.game) |*game| {
            game.deinit();
        }
    }

    fn main(app: *App) !void {
        rl.setConfigFlags(.{
            .msaa_4x_hint = true,
            .window_resizable = true,
        });

        rl.initWindow(1280, 720, title);
        defer rl.closeWindow();

        rl.maximizeWindow();
        rl.setExitKey(.null);

        var textures = try Textures.init();
        defer textures.deinit();
        textures.update();

        while (!rl.windowShouldClose()) {
            const screen = app.screen;

            if (screen == .exit) {
                break;
            }

            app.update();

            if (app.screen != screen) {
                continue;
            }

            rl.beginDrawing();
            defer rl.endDrawing();

            app.render();
        }
    }

    fn update(app: *App) void {
        app.frame.update();
        app.pointer.update();

        switch (app.screen) {
            .main_menu => MainMenu.update(app),
            .select_size => SelectSize.update(app),
            .select_black => SelectBlack.update(app),
            .select_white => SelectWhite.update(app),
            .duel => Duel.update(app),
            .credits => Credits.update(app),
            .exit => unreachable,
        }
    }

    fn render(app: *App) void {
        rl.clearBackground(app.colors.background);

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
