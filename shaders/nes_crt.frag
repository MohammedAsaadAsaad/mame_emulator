#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uOutputSize;
uniform vec2 uSourceSize;
uniform float uCrtStyle;
uniform sampler2D uTexture;

out vec4 fragColor;

vec4 sampleNearest(vec2 uv) {
  vec2 srcPos = uv * uSourceSize;
  vec2 base = floor(clamp(srcPos, vec2(0.0), uSourceSize - vec2(1.0)));
  vec2 texUv = (base + vec2(0.5)) / uSourceSize;
  return texture(uTexture, texUv);
}

vec4 sampleSrc(vec2 coord) {
  vec2 clamped = clamp(coord, vec2(0.0), uSourceSize - vec2(1.0));
  vec2 uv = (clamped + vec2(0.5)) / uSourceSize;
  return texture(uTexture, uv);
}

float colorDist(vec4 a, vec4 b) {
  vec3 d = abs(a.rgb - b.rgb);
  return d.r + d.g + d.b;
}

vec4 sampleXbr(vec2 srcPos) {
  vec2 base = floor(srcPos);
  vec2 frac = fract(srcPos);
  vec4 a = sampleSrc(base);
  vec4 b = sampleSrc(base + vec2(1.0, 0.0));
  vec4 c = sampleSrc(base + vec2(0.0, 1.0));
  vec4 d = sampleSrc(base + vec2(1.0, 1.0));
  float threshold = 0.12;
  if (colorDist(a, c) < threshold && colorDist(b, d) < threshold) {
    return a;
  }
  if (colorDist(a, b) < threshold && colorDist(c, d) < threshold) {
    return a;
  }
  if (colorDist(a, b) < threshold) {
    return mix(a, b, frac.x);
  }
  if (colorDist(a, c) < threshold) {
    return mix(a, c, frac.y);
  }
  return mix(mix(a, b, frac.x), mix(c, d, frac.x), frac.y);
}

vec2 barrelDistort(vec2 uv, float strength) {
  vec2 centered = uv - vec2(0.5);
  float r2 = dot(centered, centered);
  return centered * (1.0 + strength * r2) + vec2(0.5);
}

vec4 sampleColor(vec2 uv, float style) {
  vec2 srcPos = uv * uSourceSize;
  if (style >= 4.5) {
    return sampleXbr(srcPos);
  }
  if (style >= 1.5 && style < 2.5) {
    vec4 center = sampleNearest(uv);
    vec4 left = sampleNearest(uv + vec2(-1.0, 0.0) / uSourceSize);
    vec4 right = sampleNearest(uv + vec2(1.0, 0.0) / uSourceSize);
    vec4 bleed = (left + right) * 0.5;
    float edge = colorDist(center, bleed);
    vec4 ntsc = mix(center, bleed, clamp(edge * 0.35, 0.0, 0.45));
    ntsc.r += sin(uv.x * uSourceSize.x * 6.283) * 0.012;
    ntsc.b -= sin(uv.x * uSourceSize.x * 6.283) * 0.012;
    return ntsc;
  }
  return sampleNearest(uv);
}

void main() {
  vec2 outPos = FlutterFragCoord().xy;
  vec2 uv = outPos / uOutputSize;
  float style = uCrtStyle;

  float barrelStrength = 0.12;
  float scanMin = 0.82;
  float scanAmp = 0.18;
  float vignetteStrength = 1.6;
  float rgbStrength = 1.04;
  float brightness = 1.0;

  if (style >= 0.5 && style < 1.5) {
    barrelStrength = 0.06;
    scanMin = 0.65;
    scanAmp = 0.35;
    vignetteStrength = 1.0;
    brightness = 0.92;
  } else if (style >= 1.5 && style < 2.5) {
    barrelStrength = 0.08;
    scanMin = 0.9;
    scanAmp = 0.1;
    vignetteStrength = 1.2;
    rgbStrength = 1.02;
  } else if (style >= 2.5 && style < 3.5) {
    barrelStrength = 0.04;
    scanMin = 0.92;
    scanAmp = 0.08;
    vignetteStrength = 0.6;
    rgbStrength = 1.0;
  } else if (style >= 3.5 && style < 4.5) {
    barrelStrength = 0.05;
    scanMin = 0.78;
    scanAmp = 0.22;
    vignetteStrength = 1.3;
    rgbStrength = 1.06;
  } else if (style >= 4.5) {
    barrelStrength = 0.1;
    scanMin = 0.8;
    scanAmp = 0.2;
    vignetteStrength = 1.4;
    rgbStrength = 1.03;
  }

  vec2 distorted = barrelDistort(uv, barrelStrength);

  if (distorted.x < 0.0 || distorted.x > 1.0 ||
      distorted.y < 0.0 || distorted.y > 1.0) {
    fragColor = vec4(0.02, 0.02, 0.03, 1.0);
    return;
  }

  vec4 color = sampleColor(distorted, style);
  color.rgb *= brightness;

  float scanY = distorted.y * uSourceSize.y;
  float scanline = scanMin + scanAmp * sin(scanY * 3.14159265);
  color.rgb *= scanline;

  if (style >= 3.5 && style < 4.5) {
    float slot = mod(floor(outPos.x * 0.5), 3.0);
    if (slot < 1.0) {
      color.r *= rgbStrength;
      color.gb *= 0.97;
    } else if (slot < 2.0) {
      color.g *= rgbStrength;
      color.rb *= 0.97;
    } else {
      color.b *= rgbStrength;
      color.rg *= 0.97;
    }
  } else {
    float mask = mod(floor(outPos.x), 3.0);
    if (mask < 1.0) {
      color.r *= rgbStrength;
    } else if (mask < 2.0) {
      color.g *= rgbStrength;
    } else {
      color.b *= rgbStrength;
    }
  }

  vec2 vignetteUv = uv - vec2(0.5);
  float vignette = 1.0 - dot(vignetteUv, vignetteUv) * vignetteStrength;
  color.rgb *= clamp(vignette, 0.55, 1.0);

  fragColor = color;
}
