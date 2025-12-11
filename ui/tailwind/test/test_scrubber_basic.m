% test_scrubber_basic.m
% Quick basic test for BaseScrubber functionality

% Initialize bioctree
bioctree_start;

%% Create BaseScrubber
fprintf('Creating BaseScrubber...\n');
scrubber = BaseScrubber();

%% Configure axis
fprintf('Configuring axis (0 to 100)...\n');
scrubber.setAxis(0, 100, 'Test Axis', 'generic', ...
                @(x) sprintf('%.2f', x), @(x) x);

%% Set callback
fprintf('Setting onChange callback...\n');
scrubber.OnChange = @(src, evt) fprintf('  → Changed: center=%.2f, width=%.2f, kernel=%s\n', ...
                                        evt.center, evt.width, evt.kernelShape);

%% Test manual controls
fprintf('\nTesting manual controls:\n');

fprintf('Setting center to 50...\n');
scrubber.setCenter(50);

fprintf('Setting width to 20...\n');
scrubber.setWidth(20);

fprintf('Setting kernel shape to gaussian...\n');
scrubber.setKernelShape('gaussian');

%% Get current state
fprintf('\nCurrent window state:\n');
[center, width] = scrubber.getWindow();
fprintf('  Center: %.2f\n', center);
fprintf('  Width: %.2f\n', width);

spec = scrubber.toWindowSpec();
fprintf('  Domain: %s\n', spec.domain);
fprintf('  Kernel: %s\n', spec.kernel);
fprintf('  Symmetric: %d\n', spec.isSymmetric);

%% Test kernel shapes
fprintf('\nTesting all kernel shapes:\n');
shapes = {'gaussian', 'rectangular', 'triangular', 'hamming', 'hann', 'tukey'};
for i = 1:length(shapes)
    fprintf('  %d. %s\n', i, shapes{i});
    scrubber.setKernelShape(shapes{i});
    pause(0.5);
end

%% Create interactive figure
fprintf('\nCreating interactive figure...\n');
fig = uifigure('Name', 'BaseScrubber Test', 'Position', [100 100 800 400]);

% Panel for scrubber
pnl = uipanel(fig, 'Position', [20 20 760 360], 'Title', 'Base Scrubber');

% Add scrubber to panel
scrubber.Parent = pnl;

% Control panel
ctrlPanel = uipanel(fig, 'Position', [20 250 760 130], 'Title', 'Controls', 'Visible', 'off');

% Center control
uilabel(ctrlPanel, 'Position', [10 80 100 22], 'Text', 'Center:');
centerSlider = uislider(ctrlPanel, 'Position', [120 90 300 3], 'Limits', [0 100], 'Value', 50);
centerSlider.ValueChangedFcn = @(src, ~) scrubber.setCenter(src.Value);

% Width control
uilabel(ctrlPanel, 'Position', [10 50 100 22], 'Text', 'Width:');
widthSlider = uislider(ctrlPanel, 'Position', [120 60 300 3], 'Limits', [1 50], 'Value', 20);
widthSlider.ValueChangedFcn = @(src, ~) scrubber.setWidth(src.Value);

% Kernel shape dropdown
uilabel(ctrlPanel, 'Position', [10 20 100 22], 'Text', 'Kernel Shape:');
kernelDropdown = uidropdown(ctrlPanel, 'Position', [120 20 150 22], ...
                            'Items', shapes, 'Value', 'gaussian');
kernelDropdown.ValueChangedFcn = @(src, ~) scrubber.setKernelShape(src.Value);

% Reset button
btnReset = uibutton(ctrlPanel, 'Position', [450 20 80 30], 'Text', 'Reset');
btnReset.ButtonPushedFcn = @(~, ~) scrubber.reset();

% Toggle asymmetric
btnAsym = uibutton(ctrlPanel, 'Position', [540 20 120 30], 'Text', 'Toggle Asymmetric');
btnAsym.ButtonPushedFcn = @(~, ~) scrubber.enableAsymmetricMode(~scrubber.toWindowSpec().isSymmetric);

fprintf('\nBaseScrubber test complete!\n');
fprintf('Interact with the scrubber in the figure.\n');
fprintf('Use the controls above to test programmatic API.\n');
