struct Globals { aspect_ratio: f32 }
@group(0) @binding(0) var<uniform> globals: Globals;
@vertex fn vertex_main(
    @builtin(vertex_index) vidx: u32,
    @location(0) rect_data: vec4<f32>
) -> @builtin(position) vec4<f32> {
    let x = rect_data.x;
    let y = rect_data.y;
    let w = rect_data.z;
    let h = rect_data.w;

    let bl = vec2<f32>(x,y);
    let br = vec2<f32>(x+w,y);
    let tl = vec2<f32>(x,y+h);
    let tr = vec2<f32>(x+w,y+h);

    var points = array<vec2<f32>, 8>(
        tl, tr,
        tr, br,
        br, bl,
        bl, tl,
    );

    let p = points[vidx];
    return vec4<f32>(p[0]/globals.aspect_ratio, p[1], 0, 1);
}

@fragment fn frag_main() -> @location(0) vec4<f32> {
    return vec4<f32>(0, 0.8, 0, 1.0);
}
