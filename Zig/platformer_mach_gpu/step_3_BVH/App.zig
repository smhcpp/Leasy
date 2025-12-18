const std = @import("std");
const print = std.debug.print;
const mach = @import("mach");
const T = @import("types.zig");
const gpu = mach.gpu;
const App = @This();

// steps for loading shader and making it work(vertex shader):
// 1. setup buffer
// 2. setup pipeline -> needs frag and vertex function's inputs
// 3. module for loading new shader file
// 4. render pass to draw it

pub const Modules = mach.Modules(.{ mach.Core, App });
pub const mach_module = .app;
pub const mach_systems = .{ .main, .init, .tick, .deinit };
pub const UniformSize = 256;

pub const main = mach.schedule(.{
    .{ mach.Core, .init },
    .{ App, .init },
    .{ mach.Core, .main },
});

window: mach.ObjectID,
map_pipeline: *gpu.RenderPipeline,
player_pipeline: *gpu.RenderPipeline,
bvh_pipeline: *gpu.RenderPipeline,
bind_group: *gpu.BindGroup,

plats_buffer: *gpu.Buffer,
bvh_buffer: *gpu.Buffer,
player_buffer: *gpu.Buffer,
globals_buffer: *gpu.Buffer,

player: T.Player,
globals: T.Globals,
map: *T.MapArea = undefined,

pub fn init(core: *mach.Core, app: *App, app_mod: mach.Mod(App)) !void {
    core.on_tick = app_mod.id.tick;
    core.on_exit = app_mod.id.deinit;
    const window = try core.windows.new(.{ .title = "Fixed Platformer" });
    app.* = .{
        .window = window,
        .map_pipeline = undefined,
        .player_pipeline = undefined,
        .bvh_pipeline = undefined,
        .bind_group = undefined,
        .bvh_buffer = undefined,
        .plats_buffer = undefined,
        .player_buffer = undefined,
        .globals_buffer = undefined,
        .player = .{ .shape = .{ .pos = .{ 0, 0 }, .size = .{ 0.1, 0.2 } }, .velocity = .{ 0, 0 } },
        .globals = .{ .aspect_ratio = 1.0 },
    };
    try app.setup();
}

fn setup(app: *App) !void {
    app.map = try T.MapArea.init(std.heap.c_allocator);
}

fn setupBuffers(app: *App, window: anytype) *gpu.BindGroupLayout {
    app.globals_buffer = window.device.createBuffer(&.{
        .label = "globals uniform",
        .usage = .{ .uniform = true, .copy_dst = true },
        .size = UniformSize,
        .mapped_at_creation = .false,
    });
    app.player_buffer = window.device.createBuffer(&.{
        .label = "player uniform",
        .usage = .{ .uniform = true, .vertex = true, .copy_dst = true },
        .size = UniformSize,
        .mapped_at_creation = .false,
    });
    const plat_size = @max(16, @sizeOf(T.RectGPU) * T.MapArea.MaxPlatformNumber);
    app.plats_buffer = window.device.createBuffer(&.{
        .label = "platforms vertex",
        .usage = .{ .vertex = true, .copy_dst = true },
        .size = plat_size,
        .mapped_at_creation = .false,
    });
    app.bvh_buffer = window.device.createBuffer(&.{
        .label = "bvh vertex",
        .usage = .{ .vertex = true, .copy_dst = true },
        .size = (T.MapArea.MaxPlatformNumber - 1) * @sizeOf(T.RectGPU),
        .mapped_at_creation = .false,
    });
    const layout = window.device.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
        .entries = &.{
            .{ .binding = 0, .visibility = .{ .vertex = true }, .buffer = .{ .type = .uniform, .min_binding_size = @sizeOf(T.Globals) } },
            .{ .binding = 1, .visibility = .{ .vertex = true }, .buffer = .{ .type = .uniform, .min_binding_size = @sizeOf(T.RectGPU) } },
        },
    }));
    app.bind_group = window.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = layout,
        .entries = &.{
            .{ .binding = 0, .buffer = app.globals_buffer, .offset = 0, .size = UniformSize },
            .{ .binding = 1, .buffer = app.player_buffer, .offset = 0, .size = UniformSize },
        },
    }));
    return layout;
}

fn setupPipeline(core: *mach.Core, app: *App, window_id: mach.ObjectID) !void {
    var window = core.windows.getValue(window_id);
    defer core.windows.setValueRaw(window_id, window);
    var bind_group_layout = setupBuffers(app, &window);
    defer bind_group_layout.release();
    const pipeline_layout = window.device.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{
        .bind_group_layouts = &.{bind_group_layout},
    }));
    defer pipeline_layout.release();
    const player_module = window.device.createShaderModuleWGSL("player.wgsl", @embedFile("shaders/player.wgsl"));
    defer player_module.release();
    const map_module = window.device.createShaderModuleWGSL("map.wgsl", @embedFile("shaders/map.wgsl"));
    defer map_module.release();
    const bvh_module = window.device.createShaderModuleWGSL("bvh.wgsl", @embedFile("shaders/bvh.wgsl"));
    defer bvh_module.release();
    const blend = gpu.BlendState{};
    const color_target = gpu.ColorTargetState{
        .format = window.framebuffer_format,
        .blend = &blend,
    };

    const vertex_layouts = [_]gpu.VertexBufferLayout{
        .{
            .array_stride = @sizeOf(T.RectGPU),
            .step_mode = .instance,
            .attribute_count = 1,
            .attributes = &[_]gpu.VertexAttribute{
                .{ .format = .float32x4, .offset = 0, .shader_location = 0 },
            },
        },
    };

    const frag_map = gpu.FragmentState.init(.{ .module = map_module, .entry_point = "frag_main", .targets = &.{color_target} });
    const frag_bvh = gpu.FragmentState.init(.{ .module = bvh_module, .entry_point = "frag_main", .targets = &.{color_target} });
    const frag_player = gpu.FragmentState.init(.{ .module = player_module, .entry_point = "frag_main", .targets = &.{color_target} });

    app.map_pipeline = window.device.createRenderPipeline(&gpu.RenderPipeline.Descriptor{
        .fragment = &frag_map,
        .layout = pipeline_layout,
        .vertex = gpu.VertexState{
            .module = map_module,
            .entry_point = "vertex_main",
            .buffers = &vertex_layouts,
            .buffer_count = 1,
        },
    });
    app.bvh_pipeline = window.device.createRenderPipeline(&gpu.RenderPipeline.Descriptor{
        .fragment = &frag_bvh,
        .layout = pipeline_layout,
        .vertex = gpu.VertexState{
            .module = bvh_module,
            .entry_point = "vertex_main",
            .buffers = &vertex_layouts,
            .buffer_count = 1,
        },
        .primitive = gpu.PrimitiveState{
            .topology = .line_list,
            // .cull_mode = .none,
        },
    });
    app.player_pipeline = window.device.createRenderPipeline(&gpu.RenderPipeline.Descriptor{
        .fragment = &frag_player,
        .layout = pipeline_layout,
        .vertex = gpu.VertexState{
            .module = player_module,
            .entry_point = "vertex_main",
            .buffers = &vertex_layouts,
            .buffer_count = 1,
        },
    });
}

pub fn updateSystems(app: *App, core: *mach.Core) void {
    app.player.shape.pos += app.player.velocity;
    const window = core.windows.getValue(app.window);
    app.globals.aspect_ratio = @as(f32, @floatFromInt(window.width)) / @as(f32, @floatFromInt(window.height));
}

pub fn updateBuffers(app: *App, core: *mach.Core) !void {
    const window = core.windows.getValue(app.window);
    const platforms = try app.map.bvh.getPlatforms();
    const aabbs = try app.map.bvh.getAABBs();
    defer app.map.bvh.allocator.free(aabbs);
    // print("aabbs: {any}\n", .{aabbs});
    window.queue.writeBuffer(app.plats_buffer, 0, platforms[0..platforms.len]);
    window.queue.writeBuffer(app.bvh_buffer, 0, aabbs[0..aabbs.len]);
    window.queue.writeBuffer(app.globals_buffer, 0, &[_]T.Globals{app.globals});
    window.queue.writeBuffer(app.player_buffer, 0, &[_]T.RectGPU{.{
        .x = app.player.shape.pos[0],
        .y = app.player.shape.pos[1],
        .w = app.player.shape.size[0],
        .h = app.player.shape.size[1],
    }});
}

pub fn handleEvents(app: *App, core: *mach.Core) void {
    const speed = 0.02;
    while (core.nextEvent()) |event| {
        switch (event) {
            .window_open => |ev| try setupPipeline(core, app, ev.window_id),
            .close => core.exit(),
            .key_press => |ev| {
                switch (ev.key) {
                    .left => app.player.velocity[0] = -speed,
                    .right => app.player.velocity[0] = speed,
                    .up => app.player.velocity[1] = speed,
                    .down => app.player.velocity[1] = -speed,
                    else => {},
                }
            },
            .key_release => |ev| {
                switch (ev.key) {
                    .left => app.player.velocity[0] = 0,
                    .right => app.player.velocity[0] = 0,
                    .up => app.player.velocity[1] = 0,
                    .down => app.player.velocity[1] = 0,
                    else => {},
                }
            },
            else => {},
        }
    }
}

pub fn tick(app: *App, core: *mach.Core) void {
    handleEvents(app, core);
    app.updateSystems(core);
    app.updateBuffers(core) catch |e| {
        print("Error: {any}\n", .{e});
    };
    const window = core.windows.getValue(app.window);
    const back_buffer_view = window.swap_chain.getCurrentTextureView().?;
    defer back_buffer_view.release();
    const encoder = window.device.createCommandEncoder(&.{});
    defer encoder.release();
    const render_pass = encoder.beginRenderPass(&gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{gpu.RenderPassColorAttachment{
            .view = back_buffer_view,
            .clear_value = gpu.Color{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 1.0 },
            .load_op = .clear,
            .store_op = .store,
        }},
    }));
    defer render_pass.release();

    render_pass.setPipeline(app.map_pipeline);
    render_pass.setBindGroup(0, app.bind_group, &.{});
    render_pass.setVertexBuffer(0, app.plats_buffer, 0, @sizeOf(T.RectGPU) * T.MapArea.MaxPlatformNumber);
    render_pass.draw(6, @intCast(T.MapArea.MaxPlatformNumber), 0, 0);

    render_pass.setPipeline(app.bvh_pipeline);
    render_pass.setBindGroup(0, app.bind_group, &.{});
    render_pass.setVertexBuffer(0, app.bvh_buffer, 0, (T.MapArea.MaxPlatformNumber - 1) * @sizeOf(T.RectGPU));
    render_pass.draw(8, T.MapArea.MaxPlatformNumber - 1, 0, 0);

    render_pass.setPipeline(app.player_pipeline);
    render_pass.setBindGroup(0, app.bind_group, &.{});
    render_pass.setVertexBuffer(0, app.player_buffer, 0, @sizeOf(T.RectGPU));
    render_pass.draw(6, 1, 0, 0);

    render_pass.end();
    var command = encoder.finish(&.{});
    defer command.release();
    window.queue.submit(&[_]*gpu.CommandBuffer{command});
}

pub fn deinit(app: *App) void {
    app.map_pipeline.release();
    app.player_pipeline.release();
    app.bind_group.release();
    app.plats_buffer.release();
    app.globals_buffer.release();
    app.map.deinit(std.heap.c_allocator);
}
