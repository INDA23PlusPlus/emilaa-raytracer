#version 460

layout(location = 0) in vec2 i_uv;

layout(location = 0) out vec4 f_col;

uniform sampler2D tex;

void main() {
    vec3 texture_color = texture(tex, i_uv).rgb;
    f_col = vec4(texture_color, 1.0);
}
