pub fn by(comptime T: type, comptime field: []const u8) type {
    return struct {
        pub fn ascending(_: void, left: T, right: T) bool {
            return @field(left, field) < @field(right, field);
        }

        pub fn descending(_: void, left: T, right: T) bool {
            return @field(left, field) > @field(right, field);
        }
    };
}
