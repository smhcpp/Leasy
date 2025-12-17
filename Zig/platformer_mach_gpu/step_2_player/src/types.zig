const std = @import("std");
const mach = @import("mach");
const gpu = mach.gpu;
pub fn F32U(value: u32) f32 {
    return @floatFromInt(value);
}
pub fn U32F(value: f32) u32 {
    return @intFromFloat(value);
}
pub const Vec2 = @Vector(2, f32);
pub const Rect = struct {
    pos: Vec2,
    size: Vec2,
};
pub const Globals = extern struct {
    aspect_ratio: f32,
    padding: f32 = 0.0,
    padding2: f32 = 0.0,
    padding3: f32 = 0.0,
};
pub const RectGPU = extern struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};
pub const Player = struct {
    shape: Rect,
    velocity: Vec2,
};

pub const Platform = struct {
    pub const Color: gpu.Color = .{ .r = 0.5, .g = 0.5, .b = 0.5, .a = 1.0 };
    shape: Rect,
};

pub const MapArea = struct {
    plats: [4]Platform = undefined,
    pub fn init(allocator: std.mem.Allocator) !*MapArea {
        const m = try allocator.create(MapArea);
        m.* = .{};
        try m.setup();
        return m;
    }

    pub fn deinit(map: *MapArea, allocator: std.mem.Allocator) void {
        // allocator.free(map.platforms);
        allocator.destroy(map);
    }

    fn setup(map: *MapArea) !void {
        map.plats[0] = .{
            .shape = .{ .pos = .{ -0.4, 0 }, .size = .{ 0.1, 0.1 } },
        };
        map.plats[1] = .{
            .shape = .{ .pos = .{ 0, -0.2 }, .size = .{ 0.1, 0.2 } },
        };
        map.plats[2] = .{
            .shape = .{ .pos = .{ 0, 0.2 }, .size = .{ 0.1, 0.1 } },
        };
        map.plats[3] = .{
            .shape = .{ .pos = .{ 0, -0.3 }, .size = .{ 0.1, 0.1 } },
        };
    }
};
