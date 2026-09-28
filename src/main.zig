const std = @import("std");
const process = std.process;
const Init = process.Init;

const c6 = @import("connect6");
const rl = @import("raylib");

const title = "Connect6";

pub fn main(init: Init) !void {
    var game = try c6.Game.init(init.gpa, .square(19));
    defer game.deinit();

    rl.initWindow(800, 600, title);
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);
        rl.drawText(title, 36, 30, 24, .black);
    }
}
