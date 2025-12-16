const std = @import("std");
const mach = @import("mach");
const T = @import("types.zig");
const gpu = mach.gpu;
const App = @This();

pub const Modules = mach.Modules(.{ mach.Core, App });
pub const mach_module = .app;
pub const mach_systems = .{ .main, .init, .tick, .deinit };
pub const main = mach.schedule(.{
    .{ mach.Core, .init },
    .{ App, .init },
    .{ mach.Core, .main },
});

window: mach.ObjectID,
map_pipeline: *gpu.RenderPipeline,
bind_group: *gpu.BindGroup, // For Globals

plats_buffer: *gpu.Buffer,   // Vertex Buffer (Instance Data)
globals_buffer: *gpu.Buffer, // Uniform Buffer

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
        .bind_group = undefined,
        .plats_buffer = undefined,
        .globals_buffer = undefined,
        .player = .{ .shape = .{ .pos = .{ 0,  0 }, .size = .{ 0.1, 0.2 } }, .velocity = .{ 0, 0 } },
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
        .size = 256,
        .mapped_at_creation = .false,
    });
    const plat_size = @max(16, @sizeOf(T.RectGPU) * app.map.plats.len);
    app.plats_buffer = window.device.createBuffer(&.{
        .label = "platforms vertex",
        .usage = .{ .vertex = true, .copy_dst = true }, // <--- VERTEX
        .size = plat_size,
        .mapped_at_creation = .false,
    });
    const layout = window.device.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
        .entries = &.{
            .{
                .binding = 0,
                .visibility = .{ .vertex = true },
                .buffer = .{ .type = .uniform, .min_binding_size = @sizeOf(T.Globals) }
            },
        },
    }));
    app.bind_group = window.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = layout,
        .entries = &.{
            .{ .binding = 0, .buffer = app.globals_buffer, .offset = 0, .size = 256 },
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
    const shader_module = window.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
    defer shader_module.release();
    const blend = gpu.BlendState{};
    const color_target = gpu.ColorTargetState{
        .format = window.framebuffer_format,
        .blend = &blend,
    };

    const vertex_layouts = [_]gpu.VertexBufferLayout{
        .{
            .array_stride = @sizeOf(T.RectGPU),
            .step_mode = .instance, // <--- IMPORTANT
            .attribute_count = 1,
            .attributes = &[_]gpu.VertexAttribute{
                .{ .format = .float32x4, .offset = 0, .shader_location = 0 },
            },
        },
    };

    const frag_map = gpu.FragmentState.init(.{ .module = shader_module, .entry_point = "frag_map", .targets = &.{color_target} });

    app.map_pipeline = window.device.createRenderPipeline(&gpu.RenderPipeline.Descriptor{
        .fragment = &frag_map,
        .layout = pipeline_layout,
        .vertex = gpu.VertexState{
            .module = shader_module,
            .entry_point = "vertex_map",
            .buffers = &vertex_layouts, // <--- Attach Layout
            .buffer_count = 1,
        },
    });
}

pub fn updateSystems(app: *App, core: *mach.Core) void {
    const window = core.windows.getValue(app.window);
    app.globals.aspect_ratio = @as(f32, @floatFromInt(window.width)) / @as(f32, @floatFromInt(window.height));
}

pub fn updateBuffers(app: *App, core: *mach.Core) void {
    const window = core.windows.getValue(app.window);
    var platforms: [4]T.RectGPU = undefined;
    var count: usize = 0;
    for (app.map.plats) |plat| {
        platforms[count] = .{
            .x = plat.shape.pos[0],
            .y = plat.shape.pos[1],
            .w = plat.shape.size[0],
            .h = plat.shape.size[1],
        };
        count += 1;
    }
    window.queue.writeBuffer(app.plats_buffer, 0, platforms[0..count]);
    window.queue.writeBuffer(app.globals_buffer, 0, &[_]T.Globals{app.globals});
}

pub fn handleEvents(app: *App, core: *mach.Core) void {
    while (core.nextEvent()) |event| {
        switch (event) {
            .window_open => |ev| try setupPipeline(core, app, ev.window_id),
            .close => core.exit(),
            else => {},
        }
    }
}

pub fn tick(app: *App, core: *mach.Core) void {
    handleEvents(app, core);
    app.updateSystems(core);
    app.updateBuffers(core);
    const window = core.windows.getValue(app.window);
    const back_buffer_view = window.swap_chain.getCurrentTextureView().?;
    defer back_buffer_view.release();
    const encoder = window.device.createCommandEncoder(&.{});
    defer encoder.release();
    const render_pass = encoder.beginRenderPass(&gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{gpu.RenderPassColorAttachment{
            .view = back_buffer_view,
            .clear_value = gpu.Color{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 1.0 },
            .load_op = .clear, .store_op = .store,
        }},
    }));
    defer render_pass.release();

    render_pass.setPipeline(app.map_pipeline);
    render_pass.setBindGroup(0, app.bind_group, &.{});
    render_pass.setVertexBuffer(0, app.plats_buffer, 0, @sizeOf(T.RectGPU) * app.map.plats.len);
    render_pass.draw(6, @intCast(app.map.plats.len), 0, 0);

    render_pass.end();
    var command = encoder.finish(&.{});
    defer command.release();
    window.queue.submit(&[_]*gpu.CommandBuffer{command});
}

pub fn deinit(app: *App) void {
    app.map_pipeline.release();
    app.bind_group.release();
    app.plats_buffer.release();
    app.globals_buffer.release();
    app.map.deinit(std.heap.c_allocator);
}
