const std = @import("std");
const Random = std.Random;
const DefaultPrng = Random.DefaultPrng;

const Size = @This();
width: usize,
height: usize,

pub fn init(width: usize, height: usize) Size {
    return .{
        .width = width,
        .height = height,
    };
}

pub fn square(size: usize) Size {
    return init(size, size);
}

pub fn area(size: Size) usize {
    return size.width * size.height;
}

const testing = std.testing;
const expectEqual = testing.expectEqual;

test "area" {
    var prng = DefaultPrng.init(0);
    const random = prng.random();

    // commutative property
    for (0..255) |_| {
        const width = random.int(u8);
        const height = random.int(u8);
        const ltr = Size.init(width, height).area();
        const rtl = Size.init(height, width).area();
        try expectEqual(ltr, rtl);
    }

    // zero product property
    for (0..255) |_| {
        const zero_width = random.boolean();
        const zero_height = !zero_width;
        const width = if (zero_width) 0 else random.int(u8);
        const height = if (zero_height) 0 else random.int(u8);
        const product = Size.init(width, height).area();
        try expectEqual(0, product);
    }
}
