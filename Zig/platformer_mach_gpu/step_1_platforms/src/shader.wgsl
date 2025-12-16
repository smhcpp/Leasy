struct Globals { aspect_ratio: f32, pad1: f32, pad2: f32, pad3: f32 }

@group(0) @binding(0) var<uniform> globals: Globals;

@vertex fn vertex_map(
    @builtin(vertex_index) v_idx: u32,
    @location(0) rect_data: vec4<f32>
) -> @builtin(position) vec4<f32> {
    let x = rect_data.x;
    let y = rect_data.y;
    let w = rect_data.z;
    let h = rect_data.w;
    var pos = array<vec2<f32>, 6>(
        vec2<f32>(x, y), vec2<f32>(x, y+h), vec2<f32>(x+w, y),
        vec2<f32>(x+w, y), vec2<f32>(x, y+h), vec2<f32>(x+w, y+h)
    );
    return vec4<f32>(pos[v_idx].x / globals.aspect_ratio, pos[v_idx].y, 0.0, 1.0);
}

@fragment fn frag_map() -> @location(0) vec4<f32> {
    return vec4<f32>(0.5, 0.5, 0.5, 1.0);
}
