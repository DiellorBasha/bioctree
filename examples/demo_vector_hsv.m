%DEMO_VECTOR_HSV  Demonstrate 2D vector field colormap using HSV encoding
%
%   This example shows how to use bct.color.vector_hsv to visualize
%   2D vector fields where:
%     - Hue encodes direction (phase/angle)
%     - Value encodes magnitude (amplitude)
%     - Saturation is optional (confidence/reliability)

%% Example 1: Simple vector field (vortex)
fprintf('Example 1: Vortex field\n');

% Create 2D grid
[X, Y] = meshgrid(linspace(-2, 2, 50), linspace(-2, 2, 50));

% Define vortex field: v = (-y, x)
Vx = -Y;
Vy = X;

% Convert to amplitude and phase
amplitude = sqrt(Vx.^2 + Vy.^2);
phase = atan2(Vy, Vx);

% Generate RGB using vector_hsv
RGB = bct.color.vector_hsv(amplitude, phase);

fprintf('  RGB output size: %dx%dx%d\n', size(RGB,1), size(RGB,2), size(RGB,3));
fprintf('  Amplitude range: [%.2f, %.2f]\n', min(amplitude(:)), max(amplitude(:)));
fprintf('  Phase range: [%.2f, %.2f]\n', min(phase(:)), max(phase(:)));

%% Example 2: Radial field with custom amplitude scaling
fprintf('\nExample 2: Radial field with custom scaling\n');

% Radial field: v = (x, y)
Vx = X;
Vy = Y;

amplitude = sqrt(Vx.^2 + Vy.^2);
phase = atan2(Vy, Vx);

% Custom max amplitude for better contrast
RGB_custom = bct.color.vector_hsv(amplitude, phase, ...
    'maxAmplitude', 3.0);

fprintf('  Custom max amplitude set to 3.0\n');

%% Example 3: Vector field with confidence/saturation
fprintf('\nExample 3: Vector field with spatially-varying confidence\n');

% Create confidence mask (higher near center)
confidence = exp(-0.5 * (X.^2 + Y.^2));

% Use confidence as saturation
RGB_conf = bct.color.vector_hsv(amplitude, phase, ...
    'saturation', confidence);

fprintf('  Confidence range: [%.2f, %.2f]\n', min(confidence(:)), max(confidence(:)));
fprintf('  Low confidence areas will appear desaturated\n');

%% Example 4: Access via registry
fprintf('\nExample 4: Accessing vectorHSV via colormap registry\n');

reg = bct.color.ColormapRegistry.instance();
def = reg.get('vectorHSV');

fprintf('  Colormap name: %s\n', def.Name);
fprintf('  Category: %s\n', char(def.Category));
fprintf('  Dimensionality: %dD\n', def.dimensionality());
fprintf('  Domain: Phase [%.2f, %.2f], Amplitude [%.2f, %.2f]\n', ...
    def.Domain(1,1), def.Domain(1,2), def.Domain(2,1), def.Domain(2,2));

%% Example 5: Color wheel visualization
fprintf('\nExample 5: Generate HSV color wheel\n');

% Generate color wheel showing all hue/value combinations
colorWheel = def.sample(64);  % Returns 64x64 flattened color wheel

fprintf('  Color wheel generated: %d colors\n', size(colorWheel, 1));
fprintf('  Useful for legends and color reference\n');

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('bct.color.vector_hsv is a 2D colormap that encodes:\n');
fprintf('  - Direction via HUE (cyclic, 0-360°)\n');
fprintf('  - Magnitude via VALUE (0-1 intensity)\n');
fprintf('  - Optional confidence via SATURATION\n');
fprintf('\nUsage:\n');
fprintf('  RGB = bct.color.vector_hsv(amplitude, phase)\n');
fprintf('  RGB = bct.color.vector_hsv(amp, phase, ''maxAmplitude'', 2.0)\n');
fprintf('  RGB = bct.color.vector_hsv(amp, phase, ''saturation'', confidence)\n');
