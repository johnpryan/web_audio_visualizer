#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec4 uColor;
uniform float intensity;

out vec4 FragColor;

void main() {
  vec2 pixel = FlutterFragCoord() / uSize;
  vec2 center = uSize * 0.5 / uSize;
  float fromCenter = distance(center, pixel);
  float outputIntensity = 1.0 / fromCenter * intensity;
  vec4 color = vec4(outputIntensity, outputIntensity, outputIntensity, 1.0);
  FragColor = mix(color, uColor, 0.9);
}
