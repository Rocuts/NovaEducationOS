#include <metal_stdlib>
using namespace metal;

/// A subtle, moving aurora gradient effect.
/// - Parameters:
///   - position: The scren position of the pixel.
///   - color: The base color (unused, but required for layer effects).
///   - size: The size of the view.
///   - time: The current time in seconds.
///   - primaryColor: The dominant color of the aurora.
///   - secondaryColor: The secondary accent color.
[[ stitchable ]] half4 auroraGradient(
    float2 position,
    half4 color,
    float2 size,
    float time,
    half4 primaryColor,
    half4 secondaryColor
) {
    // Normalize position (0.0 to 1.0)
    float2 uv = position / size;
    
    // Create slow moving waves
    // We use time * 0.2 for slow movement
    float t = time * 0.2;
    
    // Distort UVs to create "liquid" feel
    uv.y += 0.1 * sin(uv.x * 3.0 + t);
    uv.x += 0.1 * cos(uv.y * 3.0 + t * 0.5);
    
    // Calculate distance from moving centers
    float2 center1 = float2(0.5 + 0.4 * sin(t), 0.5 + 0.3 * cos(t * 1.2));
    float2 center2 = float2(0.3 + 0.4 * cos(t * 0.8), 0.6 + 0.3 * sin(t * 1.1));
    float2 center3 = float2(0.8 + 0.2 * sin(t * 1.5), 0.3 + 0.4 * cos(t * 0.9));
    
    float d1 = distance(uv, center1);
    float d2 = distance(uv, center2);
    float d3 = distance(uv, center3);
    
    // Soft blobs
    float blob1 = smoothstep(0.8, 0.0, d1);
    float blob2 = smoothstep(0.8, 0.0, d2);
    float blob3 = smoothstep(0.8, 0.0, d3);
    
    // Mix colors
    // Base is a very deep, dark variant of the primary set (almost black/night sky)
    half4 baseColor = half4(0.05, 0.05, 0.08, 1.0);
    
    half4 finalColor = baseColor;
    
    // Add primary blob
    finalColor = mix(finalColor, primaryColor, half(blob1 * 0.6));
    
    // Add secondary blob
    finalColor = mix(finalColor, secondaryColor, half(blob2 * 0.5));
    
    // Add a third accent (mix of both)
    half4 tertiary = (primaryColor + secondaryColor) * 0.5;
    finalColor = mix(finalColor, tertiary, half(blob3 * 0.4));
    
    // Add subtle noise/grain (optional, simple hash)
    // float noise = fract(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
    // finalColor += (half(noise) - 0.5) * 0.02;

    return finalColor;
}
