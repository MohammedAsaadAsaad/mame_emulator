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

float colorEq(vec4 a, vec4 b) {
  vec3 d = abs(a.rgb - b.rgb);
  return step(d.r + d.g + d.b, 0.18);
}

void main() {
  vec2 outPos = FlutterFragCoord().xy;
  vec2 srcPos = outPos * uSourceSize / uOutputSize;
  vec2 base = floor(srcPos);
  vec2 frac = fract(srcPos);

  vec4 e = sampleSrc(base);
  vec4 a = sampleSrc(base + vec2(-1.0, 0.0));
  vec4 b = sampleSrc(base + vec2(0.0, -1.0));
  vec4 c = sampleSrc(base + vec2(1.0, 0.0));
  vec4 d = sampleSrc(base + vec2(0.0, 1.0));
  vec4 f = sampleSrc(base + vec2(1.0, 1.0));

  float eqEA = colorEq(e, a);
  float eqEB = colorEq(e, b);
  float eqEC = colorEq(e, c);
  float eqED = colorEq(e, d);
  float eqEF = colorEq(e, f);

  vec4 result = e;

  if (eqEA > 0.5 && eqEC > 0.5 && eqEB < 0.5 && eqED < 0.5) {
    result = mix(e, c, frac.x);
  } else if (eqEB > 0.5 && eqED > 0.5 && eqEA < 0.5 && eqEC < 0.5) {
    result = mix(e, d, frac.y);
  } else if (eqEA > 0.5 && eqEB > 0.5) {
    result = mix(mix(a, e, 0.5), mix(b, e, 0.5), max(frac.x, frac.y));
  } else if (eqEC > 0.5 && eqED > 0.5) {
    result = mix(mix(c, e, 0.5), mix(d, e, 0.5), max(frac.x, frac.y));
  } else if (eqEF > 0.5 && eqEC > 0.5 && eqED > 0.5) {
    result = mix(e, f, frac.x * frac.y);
  } else {
    result = mix(
      mix(e, c, frac.x),
      mix(b, f, frac.x),
      frac.y
    );
  }

  fragColor = result;
}