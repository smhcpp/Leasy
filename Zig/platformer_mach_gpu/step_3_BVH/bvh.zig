const std = @import("std");
const T = @import("types.zig");
const Vec2 = T.Vec2;

pub const BVH = struct {
    // pub const MaxNumberOfBranches = 1000;
    root: ?*TreeNode,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, platforms: []T.Platform) !*BVH {
        const bvh = try allocator.create(BVH);
        bvh.* = .{
            .root = null,
            .allocator = allocator,
        };
        var indices = try allocator.alloc(usize, platforms.len);
        defer allocator.free(indices);
        for (0..platforms.len) |i| indices[i] = i;
        bvh.root = try bvh.buildRecursive(platforms, indices);
        return bvh;
    }

    pub fn deinit(bvh: *BVH, allocator: std.mem.Allocator) void {
        if (bvh.root) |root| {
            root.deinit(allocator);
        }
        allocator.destroy(bvh);
    }

    pub fn buildRecursive(bvh: *BVH, all_platforms: []T.Platform, indices: []usize) std.mem.Allocator.Error!*TreeNode {
        if (indices.len == 1) {
            return bvh.createNode(all_platforms[indices[0]], null);
        }
        var group_aabb = all_platforms[indices[0]].aabb;
        for (indices[1..]) |idx| {
            group_aabb = getMergedAABB(group_aabb, all_platforms[idx].aabb);
        }
        const is_horizontal = group_aabb.size[0] > group_aabb.size[1];
        const Context = struct {
            plats: []T.Platform,
            axis: usize,
            pub fn less(ctx: @This(), a: usize, b: usize) bool {
                const ca = ctx.plats[a].aabb.center();
                const cb = ctx.plats[b].aabb.center();
                return ca[ctx.axis] < cb[ctx.axis];
            }
        };
        std.sort.block(usize, indices, Context{ .plats = all_platforms, .axis = if (is_horizontal) 0 else 1 }, Context.less);
        const mid = indices.len / 2;
        const left_indices = indices[0..mid];
        const right_indices = indices[mid..];
        const node = try bvh.allocator.create(TreeNode);
        node.left = try bvh.buildRecursive(all_platforms, left_indices);
        node.right = try bvh.buildRecursive(all_platforms, right_indices);
        node.left.?.parent = node;
        node.right.?.parent = node;
        node.aabb = group_aabb;
        node.data = null;
        node.parent = null;
        return node;
    }

    fn createNode(bvh: *BVH, platform: T.Platform, parent: ?*TreeNode) !*TreeNode {
        const node = try bvh.allocator.create(TreeNode);
        node.* = .{
            .left = null,
            .right = null,
            .aabb = platform.aabb,
            .data = platform,
            .parent = parent,
        };
        return node;
    }

    pub fn printBVH(bvh: *BVH) void {
        std.debug.print("BVH Tree Structure:\n", .{});
        if (bvh.root) |root| {
            printNode(root, "", true, 0, 10);
        } else {
            std.debug.print("  (empty)\n", .{});
        }
    }

    pub fn getPlatforms(bvh: *BVH) ![]const T.Platform {
        var platforms = std.ArrayList(T.Platform).init(bvh.allocator);
        defer platforms.deinit();
        if (bvh.root) |root| {
            try getPlatformsRecursive(root, &platforms);
        }
        return platforms.toOwnedSlice();
    }

    pub fn getAABBs(bvh: *BVH) ![]const T.RectGPU {
        var aabbs = std.ArrayList(T.RectGPU).init(bvh.allocator);
        defer aabbs.deinit();
        if (bvh.root) |root| {
            try getAABBsRecursive(root, &aabbs);
        }
        return aabbs.toOwnedSlice();
    }
};

pub const TreeNode = struct {
    right: ?*TreeNode,
    left: ?*TreeNode,
    aabb: T.Rect,
    data: ?T.Platform,
    parent: ?*TreeNode,

    pub fn isLeaf(node: *const TreeNode) bool {
        return node.data != null;
    }

    pub fn deinit(node: *TreeNode, allocator: std.mem.Allocator) void {
        if (node.right) |tr| tr.deinit(allocator);
        if (node.left) |bl| bl.deinit(allocator);
        // if (node.parent) |parent| allocator.destroy(parent);
        allocator.destroy(node);
    }
};

pub fn isAABBCollision(rect1: T.Rect, rect2: T.Rect) bool {
    const min1 = rect1.pos;
    const max1 = rect1.pos + rect1.size;
    const min2 = rect2.pos;
    const max2 = rect2.pos + rect2.size;
    return !(max1[0] < min2[0] or max1[1] < min2[1] or max2[0] < min1[0] or max2[1] < min1[1]);
}

pub fn getMergedAABB(rect1: T.Rect, rect2: T.Rect) T.Rect {
    const minx = @min(rect1.pos[0], rect2.pos[0]);
    const miny = @min(rect1.pos[1], rect2.pos[1]);
    const maxx = @max(rect1.pos[0] + rect1.size[0], rect2.pos[0] + rect2.size[0]);
    const maxy = @max(rect1.pos[1] + rect1.size[1], rect2.pos[1] + rect2.size[1]);
    return T.Rect{ .pos = .{ minx, miny }, .size = .{ maxx - minx, maxy - miny } };
}

pub fn getAABBCost(rect: T.Rect) f32 {
    return rect.size[0] + rect.size[1];
}

fn getPlatformsRecursive(node: *const TreeNode, platforms: *std.ArrayList(T.Platform)) std.mem.Allocator.Error!void {
    if (node.data) |plat| {
        try platforms.append(plat);
    }
    if (node.right) |tr| {
        try getPlatformsRecursive(tr, platforms);
    }
    if (node.left) |bl| {
        try getPlatformsRecursive(bl, platforms);
    }
}

fn getAABBsRecursive(node: *const TreeNode, aabbs: *std.ArrayList(T.RectGPU)) std.mem.Allocator.Error!void {
    if (node.isLeaf()) return;
    if (node.parent != null) {
        try aabbs.append(.{
            .x = node.aabb.pos[0],
            .y = node.aabb.pos[1],
            .w = node.aabb.size[0],
            .h = node.aabb.size[1],
        });
    }
    if (node.right) |tr| {
        try getAABBsRecursive(tr, aabbs);
    }
    if (node.left) |bl| {
        try getAABBsRecursive(bl, aabbs);
    }
}

fn printNode(node: *const TreeNode, prefix: []const u8, is_last: bool, depth: usize, max_depth: usize) void {
    if (depth >= max_depth) {
        std.debug.print("{s}{s}...(max depth reached)\n", .{ prefix, if (is_last) "--- " else "|---" });
        return;
    }
    const connector = if (is_last) "--- " else "|---";
    if (node.data) |plat| {
        std.debug.print("{s}{s}LEAF: pos=({d:.2},{d:.2}) size=({d:.2},{d:.2})\n", .{
            prefix,            connector,
            plat.aabb.pos[0],  plat.aabb.pos[1],
            plat.aabb.size[0], plat.aabb.size[1],
        });
    } else {
        std.debug.print("{s}{s}BRANCH: aabb pos=({d:.2},{d:.2}) size=({d:.2},{d:.2})\n", .{
            prefix,            connector,
            node.aabb.pos[0],  node.aabb.pos[1],
            node.aabb.size[0], node.aabb.size[1],
        });
        const extension = if (is_last) "    " else "|   ";
        var new_prefix_buf: [1024]u8 = undefined;
        const new_prefix = std.fmt.bufPrint(&new_prefix_buf, "{s}{s}", .{ prefix, extension }) catch prefix;
        const has_bl = node.left != null;
        const has_tr = node.right != null;
        if (has_tr) {
            printNode(node.right.?, new_prefix, !has_bl, depth + 1, max_depth);
        }
        if (has_bl) {
            printNode(node.left.?, new_prefix, true, depth + 1, max_depth);
        }
    }
}
