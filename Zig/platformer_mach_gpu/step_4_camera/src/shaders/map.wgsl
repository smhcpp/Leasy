struct Globals { aspect_ratio: f32 }
@group(0) @binding(0) var<uniform> globals: Globals;

struct VertexOut {
    @builtin(position) pos: vec4<f32>,
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
    return out;
}

@fragment fn frag_main() -> @location(0) vec4<f32> {
    return vec4<f32>(0.5, 0.5, 0.5, 1.0);
}
