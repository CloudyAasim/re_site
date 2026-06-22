shader_type canvas_item;

// 你可以在检查器里直接调整这两个颜色
uniform vec4 color1 : source_color = vec4(0.8, 0.8, 1, 1.0); // 深色1
uniform vec4 color2 : source_color = vec4(0.8, 1, 0.8, 1.0); // 深色2
uniform float speed : hint_range(0.1, 2.0) = 0.3; // 流动速度

void fragment() {
    vec2 uv = UV;
    uv.x += sin(uv.y * 3.0 + TIME * speed) * 0.1;
    uv.y += cos(uv.x * 3.0 + TIME * speed * 0.8) * 0.1;
    
    float mixer = sin(uv.x * 2.0 + uv.y * 2.0 + TIME * speed) * 0.5 + 0.5;
    COLOR = mix(color1, color2, mixer);
}
