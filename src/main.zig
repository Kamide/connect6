const std = @import("std");
const process = std.process;
const Init = process.Init;

const c6 = @import("connect6");

pub fn main(init: Init) !void {
    var game = try c6.Game.init(init.gpa, .square(19));
    defer game.deinit();
}
