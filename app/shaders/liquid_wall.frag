// Liquid theme "living wallpaper" (concept 16 `.wall`): three huge, heavily blurred colour
// blobs that drift slowly (22 s, alternating, staggered), a dark base, and a light shade on
// top. Per pixel on the GPU, one draw call. `uGray` 1 = offline (concept: grayscale .8).
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec4 uC1;
uniform vec4 uC2;
uniform vec4 uC3;
uniform vec4 uBase;
uniform float uShade;
uniform float uGray;

out vec4 fragColor;

// CSS `animation: drift 22s ease-in-out infinite alternate` → translate(6%, 5%) scale(1.08).
float drift(float t, float delay) {
  float x = fract((t + delay) / 44.0) * 2.0;   // 0..2 over a there-and-back cycle
  float k = x < 1.0 ? x : 2.0 - x;               // triangle 0..1..0
  return k * k * (3.0 - 2.0 * k);                // ease-in-out
}

// One blurred ellipse: centre c, radii r (fractions of the screen), blur in fractions.
float blob(vec2 p, vec2 c, vec2 r, float k) {
  vec2 cc = c + vec2(0.06, 0.05) * k * 2.0 * r;  // translate(6%, 5%) of its own size
  vec2 rr = r * (1.0 + 0.08 * k);
  float d = length((p - cc) / rr);
  return 1.0 - smoothstep(0.62, 1.18, d);        // `filter: blur(46px)` at the design size
}

void main() {
  vec2 p = FlutterFragCoord().xy / uSize;
  float t = uTime;
  vec3 col = uBase.rgb;
  // .wall i:nth-child(1..3), positions from the concept's CSS (width/height % → radii).
  col = mix(col, uC1.rgb, 0.95 * blob(p, vec2(0.19, 0.30), vec2(0.31, 0.60), drift(t, 0.0)));
  col = mix(col, uC2.rgb, 0.95 * blob(p, vec2(0.865, 0.45), vec2(0.275, 0.55), drift(t, 7.0)));
  col = mix(col, uC3.rgb, 0.95 * blob(p, vec2(0.53, 1.0), vec2(0.25, 0.45), drift(t, 13.0)));
  // .wall::after { background: var(--shade) }
  col = mix(col, vec3(8.0, 10.0, 20.0) / 255.0, uShade);
  float g = dot(col, vec3(0.299, 0.587, 0.114));
  col = mix(col, vec3(g), 0.8 * uGray);
  fragColor = vec4(col, 1.0);
}
