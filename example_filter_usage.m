% example_filter_usage.m
% Example usage patterns for the new filter architecture
%
% This demonstrates how to use filters with GUI applications
% where parameters are updated dynamically via sliders.

%% Example 1: Basic Filter Creation and Parameter Updates
fprintf('Example 1: Basic Usage\n');
fprintf('======================\n\n');

% Setup BCT object
B = bct();
B.Time = bct.Time(0:0.001:1, 1000);  % 1 second at 1000 Hz
B.Omega = B.Time.dual;

% Create a Gaussian filter on frequency domain
filt = bct.filters.Filter(B.Omega, 'gaussian', ...
    'center', 10, 'sigma', 2, 'label', 'alpha_band');

% Evaluate filter
H = filt.evaluate();
fprintf('Created Gaussian filter: center=%.1f Hz, sigma=%.1f\n', ...
    filt.center, filt.sigma);

% Simulate GUI slider update
fprintf('\nSimulating slider update...\n');
filt.center = 12;  % User moved center slider
filt.sigma = 3;    % User moved sigma slider
fprintf('Updated: center=%.1f Hz, sigma=%.1f\n', filt.center, filt.sigma);

% Re-evaluate with new parameters
H_new = filt.evaluate();
fprintf('Filter re-evaluated with new parameters\n\n');

%% Example 2: Using FilterDesigner (Recommended Approach)
fprintf('Example 2: Using FilterDesigner\n');
fprintf('================================\n\n');

% Create designer
designer = bct.filters.FilterDesigner(B);

% Create multiple filters easily
alpha_filt = designer.temporal('gaussian', 'center', 10, 'sigma', 2, 'label', 'alpha');
beta_filt = designer.temporal('gaussian', 'center', 25, 'sigma', 4, 'label', 'beta');
theta_filt = designer.temporal('gaussian', 'center', 6, 'sigma', 1, 'label', 'theta');

fprintf('Created 3 filters using FilterDesigner\n');
fprintf('  - Alpha: %.1f Hz\n', alpha_filt.center);
fprintf('  - Beta: %.1f Hz\n', beta_filt.center);
fprintf('  - Theta: %.1f Hz\n\n', theta_filt.center);

%% Example 3: Event Listeners for GUI Updates
fprintf('Example 3: Event Listeners\n');
fprintf('==========================\n\n');

% Create filter
filt_gui = designer.temporal('gaussian', 'center', 10, 'sigma', 2);

% Add listener that would trigger GUI plot update
% In a real GUI, this would call a function to refresh the plot
listener = addlistener(filt_gui, 'ParametersChanged', ...
    @(src, evt) fprintf('  [Event] Parameters changed - GUI would update here\n'));

% Simulate multiple parameter changes
fprintf('Simulating GUI interaction:\n');
filt_gui.center = 12;  % Triggers event
filt_gui.sigma = 3;    % Triggers event
filt_gui.setParameters('center', 15, 'sigma', 2.5);  % Triggers event once

fprintf('\n');

%% Example 4: FilterBank for Multi-Band Analysis
fprintf('Example 4: FilterBank\n');
fprintf('=====================\n\n');

% Create filter bank
bank = bct.filters.FilterBank();

% Add standard EEG frequency bands
bank.add(designer.temporal('gaussian', 'center', 4, 'sigma', 1, 'label', 'delta'));
bank.add(designer.temporal('gaussian', 'center', 6, 'sigma', 1, 'label', 'theta'));
bank.add(designer.temporal('gaussian', 'center', 10, 'sigma', 2, 'label', 'alpha'));
bank.add(designer.temporal('gaussian', 'center', 20, 'sigma', 3, 'label', 'beta'));
bank.add(designer.temporal('gaussian', 'center', 40, 'sigma', 5, 'label', 'gamma'));

fprintf('Created EEG frequency band filters:\n');
bank.list();

% Evaluate all filters
responses = bank.evaluateAll();
fprintf('Evaluated all %d filters\n', bank.length());

% Access individual filter
alpha_filter = bank.get('alpha');
fprintf('Retrieved alpha filter: center=%.1f Hz\n\n', alpha_filter.center);

%% Example 5: Spatial Filtering on Manifold
fprintf('Example 5: Spatial Filtering\n');
fprintf('============================\n\n');

% Setup manifold (simple for demo)
[x, y] = meshgrid(linspace(0, 1, 20));
V = [x(:), y(:), zeros(400, 1)];
F = delaunay(x(:), y(:));
B.Manifold = bct.Manifold(V, F);
B.Lambda = B.Manifold.dual;
B.Lambda.computeEigendecomposition(50);

% Create spatial filter
heat_filt = designer.spatial('heat', 'tau', 0.1, 'label', 'spatial_lowpass');
H_spatial = heat_filt.evaluate();

fprintf('Created heat diffusion filter\n');
fprintf('  Tau: %.2f\n', heat_filt.tau);
fprintf('  Evaluated on %d eigenvalues\n\n', length(H_spatial));

% Update tau parameter (simulate GUI slider)
heat_filt.tau = 0.2;
fprintf('Updated tau to %.2f\n\n', heat_filt.tau);

%% Example 6: Joint Domain Filtering
fprintf('Example 6: Joint Domain Filtering\n');
fprintf('==================================\n\n');

% Create joint filter for spatiotemporal analysis
gabor_filt = designer.joint('gabor', ...
    'domains', {'Lambda', 'Omega'}, ...
    'center_x', 25, 'center_y', 10, ...
    'sigma_x', 5, 'sigma_y', 2, ...
    'label', 'spatiotemporal');

H_joint = gabor_filt.evaluate();
fprintf('Created Gabor filter on Lambda×Omega domain\n');
fprintf('  Center: (λ=%.1f, ω=%.1f)\n', ...
    gabor_filt.Parameters.center_x, gabor_filt.Parameters.center_y);
fprintf('  Sigma: (σ_λ=%.1f, σ_ω=%.1f)\n', ...
    gabor_filt.Parameters.sigma_x, gabor_filt.Parameters.sigma_y);
fprintf('  Response size: %d × %d\n\n', size(H_joint, 1), size(H_joint, 2));

%% Example 7: GUI Integration Pattern
fprintf('Example 7: GUI Integration Pattern\n');
fprintf('===================================\n\n');

fprintf('In your GUI application:\n\n');
fprintf('1. Create filter in app startup:\n');
fprintf('   app.Filter = bct.filters.Filter(B.Omega, ''gaussian'', ...\n');
fprintf('       ''center'', 10, ''sigma'', 2);\n\n');

fprintf('2. Add listener to update plot:\n');
fprintf('   addlistener(app.Filter, ''ParametersChanged'', ...\n');
fprintf('       @(src,evt) updatePlot(app));\n\n');

fprintf('3. Connect sliders to filter parameters:\n');
fprintf('   function centerSliderCallback(app, value)\n');
fprintf('       app.Filter.center = value;  %% Automatic plot update via listener\n');
fprintf('   end\n\n');

fprintf('   function sigmaSliderCallback(app, value)\n');
fprintf('       app.Filter.sigma = value;  %% Automatic plot update via listener\n');
fprintf('   end\n\n');

fprintf('4. Plot filter response:\n');
fprintf('   function updatePlot(app)\n');
fprintf('       H = app.Filter.evaluate();\n');
fprintf('       plot(app.UIAxes, app.Filter.Domain.axis, abs(H));\n');
fprintf('       title(app.UIAxes, sprintf(''Center=%%g, Sigma=%%g'', ...\n');
fprintf('           app.Filter.center, app.Filter.sigma));\n');
fprintf('   end\n\n');

%% Summary
fprintf('Summary\n');
fprintf('=======\n\n');
fprintf('Key features for GUI integration:\n');
fprintf('  ✓ Direct parameter access: filt.center = value\n');
fprintf('  ✓ Event-driven updates: ParametersChanged event\n');
fprintf('  ✓ Automatic cache invalidation\n');
fprintf('  ✓ Batch parameter updates: setParameters(...)\n');
fprintf('  ✓ FilterBank for multi-filter management\n');
fprintf('  ✓ FilterDesigner for easy filter creation\n\n');

fprintf('Your filter parameters can be updated directly from GUI sliders!\n');
fprintf('The event system ensures plots/calculations update automatically.\n');
