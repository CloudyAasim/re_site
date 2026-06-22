shader_type canvas_item;

// ⭐ 修复 Godot 4 兼容性：显式声明屏幕纹理采样器
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// 控制模糊的强度
uniform float blur_amount : hint_range(0.0, 5.0) = 2.0; 

void fragment() {
    // 获取屏幕像素大小，用于计算采样偏移
    vec2 pixel_size = SCREEN_PIXEL_SIZE * blur_amount;
    
    // 简单的 9 宫格盒式模糊采样屏幕背后的图像
    vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);
    color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-pixel_size.x, -pixel_size.y));
    color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2( pixel_size.x, -pixel_size.y));
    color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-pixel_size.x,  pixel_size.y));
    color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2( pixel_size.x,  pixel_size.y));
    color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2( 0.0, -pixel_size.y));
    color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2( 0.0,  pixel_size.y));
    color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(-pixel_size.x,  0.0));
    color += texture(SCREEN_TEXTURE, SCREEN_UV + vec2( pixel_size.x,  0.0));
    
    // 将 9 个采样点平均化，得出模糊颜色
    color /= 9.0;

    // 将模糊后的背景色 与 你面板的半透明颜色混合
    // 【调色区】修改 vec4(1.0, 1.0, 1.0, 0.7) 可以改变毛玻璃的底色和透光度 (R, G, B, 透明度)
    COLOR = mix(color, vec4(1.0, 1.0, 1.0, 0.7), 0.7);
}
