const Offset = @This();
row: i2,
column: i2,

pub fn init(row: i2, column: i2) Offset {
    return .{
        .row = row,
        .column = column,
    };
}

pub fn reversed(offset: Offset) Offset {
    return .{
        .row = -offset.row,
        .column = -offset.column,
    };
}

pub fn add(left: usize, right: i2, limit: usize) ?usize {
    return switch (right) {
        -2 => if (left < 2) null else left - 2,
        -1 => if (left < 1) null else left - 1,
        0 => if (left < limit) left else null,
        1 => if (limit == 0 or left >= limit - 1) null else left + 1,
    };
}

pub const toEnd = [_]Offset{
    .init(0, 1),
    .init(1, 0),
    .init(1, 1),
    .init(1, -1),
};

pub const toStart = reversing: {
    var offsets: [toEnd.len]Offset = undefined;

    for (toEnd, 0..) |end, index| {
        offsets[index] = end.reversed();
    }

    break :reversing offsets;
};
