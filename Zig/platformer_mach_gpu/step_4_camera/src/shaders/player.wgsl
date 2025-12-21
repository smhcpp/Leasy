struct Globals { aspect_ratio: f32 }
@group(0) @binding(0) var<uniform> globals: Globals;

struct VertexOut {
    @builtin(position) pos: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) rect: vec4<f32>,
}

@vertex fn vertex_main(
    @builtin(vertex_index) v_idx: u32,
    @location(0) rect_data: vec4<f32>
) -> VertexOut {
    let x = rect_data.x;
    let y = rect_data.y;
    let w = rect_data.z;
    let h = rect_data.w;

    var positions = array<vec2<f32>, 6>(
        vec2(x, y),
        vec2(x, y+h),
        vec2(x+w, y),
        vec2(x+w, y),
        vec2(x, y+h),
        vec2(x+w, y+h)
    );

    var out: VertexOut;
    out.pos = vec4<f32>(positions[v_idx].x / globals.aspect_ratio, positions[v_idx].y, 0.0, 1.0);
    out.uv = positions[v_idx];
    out.rect = rect_data;
    return out;
}

@fragment fn frag_main(in: VertexOut) -> @location(0) vec4<f32> {
    let x = in.rect.x;
    let y = in.rect.y;
    let w = in.rect.z;
    let h = in.rect.w;

    let radius = w * 0.5;
    let center_x = x + w * 0.5;
    let spine_bot = y + radius;
    let spine_top = y + h - radius;
    let clamped_y = clamp(in.uv.y, spine_bot, spine_top);
    let closest = vec2<f32>(center_x, clamped_y);

    let dx = (in.uv.x - closest.x);
    let dy = in.uv.y - closest.y;
    let dist2 = dx * dx + dy * dy;

    if (dist2 > radius * radius) { discard; }
    return vec4<f32>(0, 0, 1, 1);
}
