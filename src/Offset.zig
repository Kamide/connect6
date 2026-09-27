const std = @import("std");

const data = @import("data.zig");
const Trit = data.Trit;

const Offset = @This();
row: Trit,
column: Trit,

pub fn init(row: Trit, column: Trit) Offset {
    return .{
        .row = row,
        .column = column,
    };
}

pub fn reversed(offset: Offset) Offset {
    return init(offset.row.negate(), offset.column.negate());
}

pub const toEnd = [_]Offset{
    .init(.zero, .positive),
    .init(.positive, .zero),
    .init(.positive, .positive),
    .init(.positive, .negative),
};

pub const toStart = reversing: {
    var offsets: [toEnd.len]Offset = undefined;

    for (toEnd, 0..) |end, index| {
        offsets[index] = end.reversed();
    }

    break :reversing offsets;
};

const testing = std.testing;
const expectEqual = testing.expectEqual;

test "Offset" {
    const fields = @typeInfo(Trit).@"enum".fields;

    inline for (fields) |row_field| {
        inline for (fields) |column_field| {
            const row = @field(Trit, row_field.name);
            const column = @field(Trit, column_field.name);
            const offset = init(row, column);
            try expectEqual(offset, offset.reversed().reversed());
        }
    }
}
