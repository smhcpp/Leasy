const std = @import("std");
const print = std.debug.print;
const BVH = @import("bvh.zig").BVH;
const bvh_ = @import("bvh.zig");
const mach = @import("mach");
const gpu = mach.gpu;
pub const Vec2 = @Vector(2, f32);

pub fn F32U(value: u32) f32 {
    return @floatFromInt(value);
}

pub fn U32F(value: f32) u32 {
    return @intFromFloat(value);
}

pub const Rect = struct {
    pos: Vec2,
    size: Vec2,
    pub fn center(rect: Rect) Vec2 {
        return rect.pos + rect.size / Vec2{ 2, 2 };
    }
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
    vision_radius: f32 = 0.4,
};

pub const Platform = struct {
    pub const Color: gpu.Color = .{ .r = 0.5, .g = 0.5, .b = 0.5, .a = 1.0 };
    aabb: Rect,
};

pub const MapArea = struct {
    pub const MaxPlatformNumber = 8;
    bvh: *BVH = undefined,
    pub fn init(allocator: std.mem.Allocator) !*MapArea {
        const m = try allocator.create(MapArea);
        m.* = .{};
        try m.setup(allocator);
        return m;
    }

    pub fn deinit(map: *MapArea, allocator: std.mem.Allocator) void {
        map.bvh.deinit(allocator);
        allocator.destroy(map);
    }

    fn setup(map: *MapArea, allocator: std.mem.Allocator) !void {
        // map.bvh = try BVH.init(allocator);
        var plats = std.ArrayList(Platform).init(allocator);
        defer plats.deinit();
        try plats.append(.{
            .aabb = .{ .pos = .{ -0.8, 0.3 }, .size = .{ 0.3, 0.2 } },
        });
        try plats.append(.{
            .aabb = .{ .pos = .{ 0, -0.5 }, .size = .{ 0.3, 0.2 } },
        });
        try plats.append(.{
            .aabb = .{ .pos = .{ 0, 0.3 }, .size = .{ 0.4, 0.1 } },
        });
        try plats.append(.{
            .aabb = .{ .pos = .{ 0.5, -0.3 }, .size = .{ 0.1, 0.2 } },
        });
        try plats.append(.{
            .aabb = .{ .pos = .{ -0.5, -0.7 }, .size = .{ 0.2, 0.3 } },
        });
        try plats.append(.{
            .aabb = .{ .pos = .{ -0.3, -0.3 }, .size = .{ 0.1, 0.2 } },
        });
        try plats.append(.{
            .aabb = .{ .pos = .{ -0.5, 0.6 }, .size = .{ 0.1, 0.2 } },
        });
        try plats.append(.{
            .aabb = .{ .pos = .{ 0.5, 0.8 }, .size = .{ 0.1, 0.1 } },
        });
        const plat_list = try plats.toOwnedSlice();
        map.bvh = try BVH.init(allocator, plat_list);
    }
};
