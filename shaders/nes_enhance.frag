#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uOutputSize;
uniform vec2 uSourceSize;
uniform sampler2D uTexture;

out vec4 fragColor;

vec4 sampleSrc(vec2 coord) {
  vec2 clamped = clamp(coord, vec2(0.0), uSourceSize - vec2(1.0));
  vec2 uv = (clamped + vec2(0.5)) / uSourceSize;
  return texture(uTexture, uv);
}

float colorDist(vec4 a, vec4 b) {
  vec3 d = abs(a.rgb - b.rgb);
  return d.r + d.g + d.b;
}

void main() {
  vec2 outPos = FlutterFragCoord().xy;
  vec2 srcPos = outPos * uSourceSize / uOutputSize;
  vec2 base = floor(srcPos);
  vec2 frac = fract(srcPos);

  vec4 a = sampleSrc(base);
  vec4 b = sampleSrc(base + vec2(1.0, 0.0));
  vec4 c = sampleSrc(base + vec2(0.0, 1.0));
  vec4 d = sampleSrc(base + vec2(1.0, 1.0));

  vec4 result = a;
  float threshold = 0.12;

  if (colorDist(a, c) < threshold && colorDist(b, d) < threshold) {
    result = a;
  } else if (colorDist(a, b) < threshold && colorDist(c, d) < threshold) {
    result = a;
  } else if (colorDist(a, b) < threshold) {
    result = mix(a, b, frac.x);
  } else if (colorDist(a, c) < threshold) {
    result = mix(a, c, frac.y);
  } else if (colorDist(b, d) < threshold) {
    result = mix(b, d, frac.x);
  } else if (colorDist(c, d) < threshold) {
    result = mix(c, d, frac.x);
  } else {
    result = mix(mix(a, b, frac.x), mix(c, d, frac.x), frac.y);
  }

  fragColor = result;
}
