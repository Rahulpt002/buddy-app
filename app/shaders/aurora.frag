// Northern lights for the Mosaic music tiles: soft glows drifting on slow Lissajous paths
// plus three wavy curtains of rays, in the album's colours over a dark base. Computed per
// pixel on the GPU (one draw call, no offscreen images), so it's smooth at any size.
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec4 uC0;
uniform vec4 uC1;
uniform vec4 uC2;
uniform vec4 uC3;
uniform vec4 uBase;

out vec4 fragColor;

vec3 pick(int i) {
  if (i == 0) return uC0.rgb;
  if (i == 1) return uC1.rgb;
  if (i == 2) return uC2.rgb;
  return uC3.rgb;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = frag / uSize;
  float aspect = uSize.x / uSize.y;
  float t = uTime;
  vec3 col = vec3(0.0);

  // Glows.
  for (int i = 0; i < 4; i++) {
    float fi = float(i);
    float ph = fi * 1.7;
    vec2 c = vec2(0.5 + 0.42 * sin(t * (0.07 + fi * 0.013) + ph),
                  0.55 + 0.38 * cos(t * (0.05 + fi * 0.011) + ph * 1.3));
    vec2 d = (p - c) * vec2(aspect, 1.0);
    float r = 0.55 + 0.1 * sin(t * 0.09 + ph);
    col += pick(i) * 0.3 * exp(-dot(d, d) / (r * r) * 2.2);
  }

  // Curtains: brightest just under a wavy top line, fading downwards, with soft rays.
  for (int k = 0; k < 3; k++) {
    float fk = float(k);
    float top = 0.18 + 0.14 * fk + 0.1 * sin(p.x * 3.14159 * (1.6 + fk * 0.5) + t * (0.35 + fk * 0.12) + fk * 2.1);
    float v = p.y - top;
    float body = smoothstep(-0.04, 0.04, v) * exp(-max(v, 0.0) * (2.6 + fk * 0.8));
    float rays = 0.55 + 0.45 * sin(p.x * (34.0 + fk * 9.0) + t * 0.7 + fk * 2.0 + 1.8 * sin(p.x * 7.0 + t * 0.4 + fk));
    float breathe = 0.6 + 0.4 * sin(t * 0.5 + p.x * 4.0 + fk * 1.3);
    col += pick(int(mod(fk + 1.0, 4.0))) * body * rays * breathe * 0.62;
  }

  // Glow without clipping: a soft tone curve, then the dark base under it.
  col = 1.0 - exp(-col * 1.35);
  col = uBase.rgb + col * (1.0 - uBase.rgb * 0.5);
  // A faint shade towards the bottom keeps white text readable.
  col *= mix(1.0, 0.72, smoothstep(0.45, 1.0, p.y));
  fragColor = vec4(col, 1.0);
}
