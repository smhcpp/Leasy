const std = @import("std");
const print = std.debug.print;
const T = @import("types.zig");
const Vec2 = T.Vec2;

pub const BVH = struct {
    // pub const MaxNumberOfBranches = 1000;
    root: ?*TreeNode,
    allocator: std.mem.Allocator,
    platforms: [9]T.Platform = [_]T.Platform{
        .{ .aabb = .{ .pos = .{ -0.8, 0.3 }, .size = .{ 0.3, 0.2 } } },
        .{ .aabb = .{ .pos = .{ 0, -0.5 }, .size = .{ 0.3, 0.2 } } },
        .{ .aabb = .{ .pos = .{ 0, 0.3 }, .size = .{ 0.4, 0.1 } } },
        .{ .aabb = .{ .pos = .{ 0.5, -0.3 }, .size = .{ 0.1, 0.2 } } },
        .{ .aabb = .{ .pos = .{ -0.5, -0.7 }, .size = .{ 0.2, 0.3 } } },
        .{ .aabb = .{ .pos = .{ -0.3, -0.3 }, .size = .{ 0.1, 0.2 } } },
        .{ .aabb = .{ .pos = .{ -0.5, 0.6 }, .size = .{ 0.1, 0.2 } } },
        .{ .aabb = .{ .pos = .{ 0.5, 0.8 }, .size = .{ 0.1, 0.1 } } },
        .{ .aabb = .{ .pos = .{ -1.5, -1 }, .size = .{ 3.0, 0.1 } } },
    },

    pub fn init(allocator: std.mem.Allocator) !*BVH {
        const bvh = try allocator.create(BVH);
        bvh.* = .{
            .root = null,
            .allocator = allocator,
        };
        var indices = try bvh.allocator.alloc(usize, bvh.platforms.len);
        defer bvh.allocator.free(indices);
        for (0..bvh.platforms.len) |i| indices[i] = i;
        bvh.root = try bvh.buildRecursive(indices);
        return bvh;
    }

    pub fn deinit(bvh: *BVH, allocator: std.mem.Allocator) void {
        if (bvh.root) |root| {
            root.deinit(allocator);
        }
        allocator.destroy(bvh);
    }

    /// uses Surface Area Heuristic (SAH) Sweep
    fn buildRecursive(bvh: *BVH, indices: []usize) std.mem.Allocator.Error!*TreeNode {
        if (indices.len == 1) {
            return bvh.createNode(indices[0], null);
        }
        var best_axis: usize = 0;
        var best_split_idx: usize = indices.len / 2;
        var min_cost: f32 = std.math.inf(f32);
        const SortContext = struct {
            plats: []const T.Platform,
            axis: usize,
            pub fn less(ctx: @This(), a: usize, b: usize) bool {
                return ctx.plats[a].aabb.center()[ctx.axis] < ctx.plats[b].aabb.center()[ctx.axis];
            }
        };
        inline for (0..2) |axis| {
            std.sort.block(usize, indices, SortContext{ .plats = &bvh.platforms, .axis = axis }, SortContext.less);
            for (1..indices.len) |i| {
                const left = indices[0..i];
                const right = indices[i..];
                const aabb_l = computeGroupAABB(&bvh.platforms, left);
                const aabb_r = computeGroupAABB(&bvh.platforms, right);
                const cost = getAABBCost(aabb_l) * @as(f32, @floatFromInt(left.len)) +
                    getAABBCost(aabb_r) * @as(f32, @floatFromInt(right.len));
                if (cost < min_cost) {
                    min_cost = cost;
                    best_axis = axis;
                    best_split_idx = i;
                }
            }
        }
        std.sort.block(usize, indices, SortContext{ .plats = &bvh.platforms, .axis = best_axis }, SortContext.less);
        const left_indices = indices[0..best_split_idx];
        const right_indices = indices[best_split_idx..];
        const node = try bvh.allocator.create(TreeNode);
        node.left = try bvh.buildRecursive(left_indices);
        node.right = try bvh.buildRecursive(right_indices);
        node.left.?.parent = node;
        node.right.?.parent = node;
        node.aabb = getMergedAABB(node.left.?.aabb, node.right.?.aabb);
        node.pid = null;
        node.parent = null;
        return node;
    }

    fn createNode(bvh: *BVH, pid: usize, parent: ?*TreeNode) !*TreeNode {
        const node = try bvh.allocator.create(TreeNode);
        node.* = .{
            .left = null,
            .right = null,
            .aabb = bvh.platforms[pid].aabb,
            .pid = pid,
            .parent = parent,
        };
        return node;
    }

    // pub fn getPidsOverlappingRay(bvh: *BVH, ray: T.Ray) ![]usize {
    //     var overlapping_pids = std.ArrayList(usize).init();
    //     defer overlapping_pids.deinit();
    //     if (bvh.root) |root| {
    //         try getPidsOverlappingAABBRecursive(root, ray, &bvh.platforms, &overlapping_pids);
    //     }
    //     return overlapping_pids.toOwnedSlice();
    // }
    pub fn getPidsOverlappingAABB(bvh: *BVH, aabb: T.Rect) ![]usize {
        var overlapping_aabbs = std.ArrayList(usize).init(bvh.allocator);
        defer overlapping_aabbs.deinit();
        if (bvh.root) |root| {
            try getPidsOverlappingAABBRecursive(root, aabb, &bvh.platforms, &overlapping_aabbs);
        }
        return overlapping_aabbs.toOwnedSlice();
    }

    pub fn printBVH(bvh: *BVH) void {
        std.debug.print("BVH Tree Structure:\n", .{});
        if (bvh.root) |root| {
            printNode(root, "", true, 0, 10);
        } else {
            std.debug.print("  (empty)\n", .{});
        }
    }

    pub fn getAABBs(bvh: *BVH) ![]T.RectGPU {
        var aabbs = std.ArrayList(T.RectGPU).init(bvh.allocator);
        defer aabbs.deinit();
        if (bvh.root) |root| {
            try getAABBsRecursive(root, &aabbs);
        }
        const aabbs_ = try aabbs.toOwnedSlice();
        return aabbs_;
    }
};

pub const TreeNode = struct {
    right: ?*TreeNode,
    left: ?*TreeNode,
    aabb: T.Rect,
    pid: ?usize,
    parent: ?*TreeNode,

    pub fn isLeaf(node: *const TreeNode) bool {
        return node.pid != null;
    }

    pub fn deinit(node: *TreeNode, allocator: std.mem.Allocator) void {
        if (node.right) |tr| tr.deinit(allocator);
        if (node.left) |bl| bl.deinit(allocator);
        allocator.destroy(node);
    }
};

pub fn getPidsOverlappingAABBRecursive(
    node: *const TreeNode,
    aabb: T.Rect,
    platforms: []const T.Platform,
    overlapping_aabbs: *std.ArrayList(usize),
) std.mem.Allocator.Error!void {
    if (!isAABBCollision(aabb, node.aabb)) return;
    if (node.pid) |pid| {
        try overlapping_aabbs.append(pid);
        return;
    }
    if (node.right) |r| try getPidsOverlappingAABBRecursive(r, aabb, platforms, overlapping_aabbs);
    if (node.left) |l| try getPidsOverlappingAABBRecursive(l, aabb, platforms, overlapping_aabbs);
}

pub fn getAABBOverlap(rect1: T.Rect, rect2: T.Rect) ?T.Rect {
    const overlapping_threshold = 0.00001;
    const colposx = @max(rect1.pos[0], rect2.pos[0]);
    const colposy = @max(rect1.pos[1], rect2.pos[1]);
    const colsizex = @min(rect1.pos[0] + rect1.size[0], rect2.pos[0] + rect2.size[0]) - colposx;
    const colsizey = @min(rect1.pos[1] + rect1.size[1], rect2.pos[1] + rect2.size[1]) - colposy;
    if (colsizex <= overlapping_threshold or colsizey <= overlapping_threshold) return null;
    return T.Rect{ .pos = .{ colposx, colposy }, .size = .{ colsizex, colsizey } };
}

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
    if (node.right) |r| {
        try getAABBsRecursive(r, aabbs);
    }
    if (node.left) |l| {
        try getAABBsRecursive(l, aabbs);
    }
}

fn printNode(bvh: *BVH, node: *const TreeNode, prefix: []const u8, is_last: bool, depth: usize, max_depth: usize) void {
    if (depth >= max_depth) {
        std.debug.print("{s}{s}...(max depth reached)\n", .{ prefix, if (is_last) "--- " else "|---" });
        return;
    }
    const connector = if (is_last) "--- " else "|---";
    if (node.pid) |pid| {
        std.debug.print("{s}{s}LEAF: pos=({d:.2},{d:.2}) size=({d:.2},{d:.2})\n", .{
            prefix,                          connector,
            bvh.platforms[pid].aabb.pos[0],  bvh.platforms[pid].aabb.pos[1],
            bvh.platforms[pid].aabb.size[0], bvh.platforms[pid].aabb.size[1],
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
fn computeGroupAABB(platforms: []const T.Platform, indices: []usize) T.Rect {
    var res = platforms[indices[0]].aabb;
    for (indices[1..]) |idx| {
        res = getMergedAABB(res, platforms[idx].aabb);
    }
    return res;
}
