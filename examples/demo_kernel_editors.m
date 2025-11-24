%% KernelEditor Examples - Interactive Filter Parameter Control
%
% This script demonstrates the KernelEditor framework for interactive
% filter manipulation in the Bct system. KernelEditors provide a clean
% interface between GUI controls (sliders, buttons) and Filter objects.
%
% Use Cases:
%   1. Time scrubber for temporal signals
%   2. Spectral band selector for Lambda domain (eigenvalue bands)
%   3. Frequency band selector for spectral analysis
%   4. Joint kernel editor for spatiotemporal filtering (separable/nonseparable)
%
% The abstract KernelEditor class provides:
%   - Navigation (shiftForward/shiftBackward)
%   - Scaling (expand/contract)
%   - Direct parameter setting (setCenter/setWidth)
%   - Automatic filter updates
%   - Event notification for GUI synchronization

%% Setup
clear; close all;

% Initialize Bct system
B = bct.bct();

%% Example 1: Time Window Editor (Time Scrubber)
% Use case: Navigate through temporal signal with moving window

fprintf('=== Example 1: Time Window Editor ===\n');

% Create time domain: 2 seconds at 1 kHz
B.Time = bct.Time(0:0.001:2, 1000);
B.Omega = B.Time.dual;

% Create Gaussian time window filter
timeFilt = bct.filters.Filter(B.Time, 'gaussian', ...
    'center', 1.0, ...  % Start at t=1s
    'sigma', 0.05);     % 50ms window

% Create time window editor
timeEditor = bct.ui.TimeWindowEditor(B.Time, timeFilt, 1.0, 0.05);

% Simulate time scrubber navigation
fprintf('  Initial center: %.3f s\n', timeEditor.Center);

timeEditor.shiftForward(10);  % Move forward 10 steps (10ms)
fprintf('  After shift forward: %.3f s\n', timeEditor.Center);

timeEditor.setCenter(0.5);    % Jump to t=0.5s
fprintf('  Jump to t=0.5s: %.3f s\n', timeEditor.Center);

timeEditor.expand();          % Widen window
fprintf('  After expand: width = %.4f s\n', timeEditor.Width);

% Get current window kernel
window = timeEditor.computeKernel();
fprintf('  Window kernel computed: %d samples, max = %.4f\n', ...
    length(window), max(window));

%% Example 2: Lambda Band Editor (Lambda Domain)
% Use case: Select spectral frequency bands on eigenvalue spectrum

fprintf('\n=== Example 2: Lambda Band Editor ===\n');

% Load mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

% Compute eigenbasis
fprintf('  Computing eigenbasis...\n');
B.Lambda = B.Lambda.eigenbasis(B.Manifold.MassMatrix, ...
                                 B.Manifold.CotangentMatrix, 300);

% Create spatial filter
spatialFilt = bct.filters.Filter(B.Lambda, 'gaussian', ...
    'center', 50, ...   % Eigenmode 50
    'sigma', 10);       % Bandwidth of 10 modes

% Create spectral band editor
spatialEditor = bct.ui.LambdaBandEditor(B.Lambda, spatialFilt, 50, 10);

% Navigate spatial frequencies
fprintf('  Initial center eigenmode: %.1f\n', spatialEditor.Center);

% Select low frequencies (smooth spatial patterns)
spatialEditor.setLowPass(30);
fprintf('  Low-pass (smooth): center=%.1f, width=%.1f\n', ...
    spatialEditor.Center, spatialEditor.Width);

% Select band-pass (medium spatial frequencies)
spatialEditor.setBandPass(50, 150);
fprintf('  Band-pass (50-150): center=%.1f, width=%.1f\n', ...
    spatialEditor.Center, spatialEditor.Width);

% Select high frequencies (detailed spatial patterns)
spatialEditor.setHighPass(200);
fprintf('  High-pass (detailed): center=%.1f, width=%.1f\n', ...
    spatialEditor.Center, spatialEditor.Width);

% Get spatial kernel
spatialKernel = spatialEditor.computeKernel();
fprintf('  Spatial kernel: %d modes, energy = %.4f\n', ...
    length(spatialKernel), sum(spatialKernel.^2));

%% Example 3: Frequency Band Editor (Omega Domain)
% Use case: Interactive frequency band selection for spectral analysis

fprintf('\n=== Example 3: Frequency Band Editor ===\n');

% Ensure Omega domain exists
if isempty(B.Omega)
    B.Time = bct.Time(0:0.001:10, 1000);  % 10s at 1kHz
    B.Omega = B.Time.dual;
end

% Create frequency filter
freqFilt = bct.filters.Filter(B.Omega, 'gaussian', ...
    'center', 10, ...   % 10 Hz
    'sigma', 2);        % 2 Hz bandwidth

% Create frequency band editor
freqEditor = bct.ui.FrequencyBandEditor(B.Omega, freqFilt, 10, 2);

% Use standard frequency band presets
fprintf('  Standard EEG bands:\n');

freqEditor.setDelta();
fprintf('    Delta: %.1f ± %.1f Hz\n', freqEditor.Center, freqEditor.Width);

freqEditor.setTheta();
fprintf('    Theta: %.1f ± %.1f Hz\n', freqEditor.Center, freqEditor.Width);

freqEditor.setAlpha();
fprintf('    Alpha: %.1f ± %.1f Hz\n', freqEditor.Center, freqEditor.Width);

freqEditor.setBeta();
fprintf('    Beta: %.1f ± %.1f Hz\n', freqEditor.Center, freqEditor.Width);

freqEditor.setGamma();
fprintf('    Gamma: %.1f ± %.1f Hz\n', freqEditor.Center, freqEditor.Width);

% Custom band
freqEditor.setBand(40, 60);
fprintf('    Custom (40-60 Hz): %.1f ± %.1f Hz\n', ...
    freqEditor.Center, freqEditor.Width);

% Get frequency kernel
freqKernel = freqEditor.computeKernel();
fprintf('  Frequency kernel: %d points, peak = %.4f\n', ...
    length(freqKernel), max(freqKernel));

%% Example 4: Joint Kernel Editor - Separable
% Use case: Independent control of spatial and temporal filtering

fprintf('\n=== Example 4a: Joint Kernel Editor (Separable) ===\n');

% Ensure we have Lambda and Omega domains
if isempty(B.Lambda) || B.Lambda.K < 100
    fprintf('  Skipping (eigenbasis not computed)\n');
elseif isempty(B.Omega)
    fprintf('  Skipping (Omega domain not initialized)\n');
else
    % Create joint domain
    joint = B.createJoint('Lambda', 'Omega');
    
    % Create separable Gabor filter
    jointFilt = bct.filters.Filter(joint, 'gabor', ...
        'center_x', 50, 'center_y', 10, ...
        'sigma_x', 10, 'sigma_y', 2);
    
    % Create joint kernel editor (separable)
    jointEditor = bct.ui.JointKernelEditor(joint, jointFilt, 50, 10, ...
        'KernelType', 'separable', 'Center_B', 10, 'Width_B', 2);
    
    fprintf('  Separable joint kernel:\n');
    fprintf('    Domain A (Lambda): center=%.1f, width=%.1f\n', ...
        jointEditor.Center, jointEditor.Width);
    fprintf('    Domain B (Omega): center=%.1f, width=%.1f\n', ...
        jointEditor.Center_B, jointEditor.Width_B);
    
    % Independent navigation
    jointEditor.shiftForward();      % Shift in Lambda
    jointEditor.shiftForward_B();    % Shift in Omega
    fprintf('  After independent shifts: Lambda center=%.1f, Omega center=%.1f\n', ...
        jointEditor.Center, jointEditor.Center_B);
end

%% Example 4b: Joint Kernel Editor - Non-separable (Velocity + Dispersion)
% Use case: Control coupling parameters for traveling wave packets

fprintf('\n=== Example 4b: Joint Kernel Editor (Non-separable) ===\n');

if isempty(B.Lambda) || B.Lambda.K < 100
    fprintf('  Skipping (eigenbasis not computed)\n');
elseif isempty(B.Omega)
    fprintf('  Skipping (Omega domain not initialized)\n');
else
    % Create velocity-tuned Gabor filter
    velocityFilt = bct.filters.Filter(joint, 'velocity_gabor', ...
        'v', 0.5, 'sigma_w', 10, 'lambda0', 50, 'sigma_l', 20, 'D', 0);
    
    % Create joint kernel editor (nonseparable)
    velocityEditor = bct.ui.JointKernelEditor(joint, velocityFilt, 50, 20, ...
        'KernelType', 'nonseparable', 'Velocity', 0.5, 'Dispersion', 0);
    
    fprintf('  Non-separable velocity kernel:\n');
    fprintf('    Spatial center (lambda0): %.1f\n', velocityEditor.Center);
    fprintf('    Spatial width (sigma_l): %.1f\n', velocityEditor.Width);
    fprintf('    Velocity (v): %.2f rad/mm/s\n', velocityEditor.Velocity);
    fprintf('    Dispersion (D): %.4f\n', velocityEditor.Dispersion);
    
    % Adjust velocity (changes ridge tilt)
    velocityEditor.setVelocity(0.7);
    fprintf('  After velocity increase: v = %.2f\n', velocityEditor.Velocity);
    
    % Add dispersion (creates curved ridge)
    velocityEditor.setDispersion(0.01);
    fprintf('  After adding dispersion: D = %.4f\n', velocityEditor.Dispersion);
    
    % Adjust spatial center
    velocityEditor.setCenter(60);
    fprintf('  After spatial shift: lambda0 = %.1f\n', velocityEditor.Center);
end

%% Example 5: Event Listeners (GUI Integration)
% Demonstrate how to connect KernelEditor to GUI callbacks

fprintf('\n=== Example 5: Event Listener Integration ===\n');

% Create a simple callback that responds to kernel changes
callbackCount = 0;
callbackFunction = @(src, evt) handleKernelChanged(src, evt);

function handleKernelChanged(src, ~)
    persistent count;
    if isempty(count), count = 0; end
    count = count + 1;
    fprintf('  [Callback %d] Kernel changed: center=%.3f, width=%.4f\n', ...
        count, src.Center, src.Width);
end

% Add listener to time editor
addlistener(timeEditor, 'KernelChanged', callbackFunction);

% Trigger events
fprintf('  Triggering kernel changes...\n');
timeEditor.setCenter(1.5);
timeEditor.expand();
timeEditor.shiftForward(5);

%% Example 6: Different Window Types (TimeWindowEditor)
% Demonstrate various window functions

fprintf('\n=== Example 5: Window Type Comparison ===\n');

t_window = linspace(-0.1, 0.1, 201)';
B_window = bct.bct();
B_window.Time = bct.Time(t_window, 100);

windowTypes = {'gaussian', 'hann', 'hamming', 'tukey'};
figure('Name', 'Window Type Comparison');

for i = 1:length(windowTypes)
    wType = windowTypes{i};
    
    % Create filter and editor for this window type
    filt = bct.filters.Filter(B_window.Time, 'gaussian', ...
        'center', 0, 'sigma', 0.02);
    editor = bct.ui.TimeWindowEditor(B_window.Time, filt, 0, 0.02, ...
        'WindowType', wType);
    
    % Compute window
    w = editor.computeKernel();
    
    % Plot
    subplot(2, 2, i);
    plot(t_window, w, 'LineWidth', 2);
    grid on;
    title(sprintf('%s Window', upper(wType)));
    xlabel('Time (s)');
    ylabel('Amplitude');
    ylim([0, max(w)*1.1]);
end

fprintf('  Window types displayed: gaussian, hann, hamming, tukey\n');

%% Example 7: Lambda Kernel Types (LambdaBandEditor)
% Demonstrate different spectral kernels

fprintf('\n=== Example 6: Lambda Kernel Type Comparison ===\n');

% Ensure Lambda domain exists
if isempty(B.Lambda) || B.Lambda.K < 100
    fprintf('  Skipping (eigenbasis not computed)\n');
else
    kernelTypes = {'gaussian', 'heat', 'mexican_hat'};
    figure('Name', 'Spatial Kernel Comparison');
    
    for i = 1:length(kernelTypes)
        kType = kernelTypes{i};
        
        % Create filter and editor
        if strcmp(kType, 'heat')
            filt = bct.filters.Filter(B.Lambda, 'heat', 'tau', 0.01);
            editor = bct.ui.LambdaBandEditor(B.Lambda, filt, 0, 0.01, ...
                'KernelType', kType);
        else
            filt = bct.filters.Filter(B.Lambda, 'gaussian', ...
                'center', 50, 'sigma', 15);
            editor = bct.ui.LambdaBandEditor(B.Lambda, filt, 50, 15, ...
                'KernelType', kType);
        end
        
        % Compute kernel
        k = editor.computeKernel();
        
        % Plot
        subplot(3, 1, i);
        plot(B.Lambda.axis, k, 'LineWidth', 2);
        grid on;
        title(sprintf('%s Kernel', upper(kType)));
        xlabel('Eigenvalue \lambda');
        ylabel('Kernel Value');
    end
    
    fprintf('  Spatial kernels displayed: gaussian, heat, mexican_hat\n');
end

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('KernelEditor provides:\n');
fprintf('  ✓ Abstract base class for filter parameter control\n');
fprintf('  ✓ Domain-specific implementations (Time, Lambda, Omega)\n');
fprintf('  ✓ Navigation methods (shift, expand, contract)\n');
fprintf('  ✓ Event system for GUI integration\n');
fprintf('  ✓ Multiple kernel types per domain\n');
fprintf('  ✓ Preset configurations (frequency bands, spatial modes)\n');
fprintf('  ✓ Joint kernel support (separable and nonseparable)\n');
fprintf('  ✓ Coupling parameter control (velocity, dispersion)\n');
fprintf('\nUse cases:\n');
fprintf('  • Time scrubbers for signal navigation\n');
fprintf('  • Spectral band selection on Lambda domain (eigenvalue spectrum)\n');
fprintf('  • Frequency band analysis (delta, theta, alpha, etc.)\n');
fprintf('  • Interactive filter design in GUIs\n');
fprintf('  • Spatiotemporal filtering with velocity/dispersion control\n');
