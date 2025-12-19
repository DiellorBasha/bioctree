function fig = eigenspectrum(signal, options)
%BCT.SHOW.EIGENSPECTRUM  Visualize Manifold Fourier Transform spectrum
%
%   bct.show.eigenspectrum(signal)
%   bct.show.eigenspectrum(signal, Name, Value, ...)
%   fig = bct.show.eigenspectrum(...)
%
% Inputs:
%   signal - bct.Signal object on Manifold domain
%
% Name-Value Parameters:
%   Type - Plot type (default: 'power')
%          'power'       - Power spectrum |x̂|² vs eigenvalue λ
%          'index'       - Power spectrum vs mode index
%          'loglog'      - Log-log plot (power law analysis)
%          'normalized'  - Energy-normalized spectrum (fraction of total)
%          'bands'       - Band-aggregated spectrum (binned)
%          'all'         - All plots in subplots
%
%   Scale - Y-axis scale (default: 'linear')
%          'linear'  - Linear scale
%          'log'     - Logarithmic scale (semilogy)
%
%   XAxisUnits - X-axis units (default: 'eigenvalue')
%          'eigenvalue'     - Eigenvalue λ (spatial frequency²)
%          'wavenumber'     - Wavenumber k = sqrt(λ)
%          'wavelength'     - Wavelength = 2π/sqrt(λ)
%          'halfwavelength' - Half-wavelength = π/sqrt(λ)
%
%   NumBands - Number of frequency bands for 'bands' type (default: 30)
%
%   TopModes - Number of top modes to show in mode visualization (default: 0)
%              If > 0, creates additional figure showing spatial patterns
%
%   ShowThreshold - If true, marks modes contributing to X% of energy (default: false)
%   ThresholdValue - Energy threshold percentage (default: 90)
%
%   Color - Plot color (default: 'k')
%   LineWidth - Line width (default: 1.5)
%   MarkerSize - Marker size (default: 6)
%
% Outputs:
%   fig - Figure handle(s)
%
% Examples:
%   % Basic power spectrum
%   bct.show.eigenspectrum(sig);
%
%   % Log-scale index plot
%   bct.show.eigenspectrum(sig, 'Type', 'index', 'Scale', 'log');
%
%   % Band-aggregated with 20 bands
%   bct.show.eigenspectrum(sig, 'Type', 'bands', 'NumBands', 20);
%
%   % Show top 5 spatial modes
%   bct.show.eigenspectrum(sig, 'TopModes', 5);
%
%   % All plots + energy threshold
%   bct.show.eigenspectrum(sig, 'Type', 'all', 'ShowThreshold', true);
%
%   % Normalized energy with threshold
%   bct.show.eigenspectrum(sig, 'Type', 'normalized', ...
%       'ShowThreshold', true, 'ThresholdValue', 95);
%
%   % Plot in wavenumber units
%   bct.show.eigenspectrum(sig, 'XAxisUnits', 'wavenumber');
%
%   % Plot in wavelength units
%   bct.show.eigenspectrum(sig, 'XAxisUnits', 'wavelength');
%
%   % Plot in half-wavelength units
%   bct.show.eigenspectrum(sig, 'XAxisUnits', 'halfwavelength');
%
% See also: bct.Signal.mft, bct.operator.transform.mft

arguments
    signal (1,1) bct.Signal
    options.Type {mustBeMember(options.Type, ...
        {'power', 'index', 'loglog', 'normalized', 'bands', 'all'})} = 'power'
    options.Scale {mustBeMember(options.Scale, {'linear', 'log'})} = 'linear'
    options.XAxisUnits {mustBeMember(options.XAxisUnits, ...
        {'eigenvalue', 'wavenumber', 'wavelength', 'halfwavelength'})} = 'eigenvalue'
    options.NumBands (1,1) double {mustBePositive, mustBeInteger} = 30
    options.TopModes (1,1) double {mustBeNonnegative, mustBeInteger} = 0
    options.ShowThreshold (1,1) logical = false
    options.ThresholdValue (1,1) double {mustBeInRange(options.ThresholdValue, 0, 100)} = 90
    options.Color = 'k'
    options.LineWidth (1,1) double {mustBePositive} = 1.5
    options.MarkerSize (1,1) double {mustBePositive} = 6
end

% Validate signal is on Manifold domain
if ~isa(signal.Domain, 'bct.Manifold')
    error('eigenspectrum:InvalidDomain', ...
        'Signal must be on Manifold domain');
end

% Validate signal is static (not joint)
if signal.IsJoint
    error('eigenspectrum:JointSignal', ...
        'Eigenspectrum not implemented for joint signals');
end

% Compute MFT
sig_spectral = signal.mft();
x_hat = sig_spectral.Data;

% Get eigenvalues from Lambda domain
lambda = sig_spectral.Domain.lambda;

% Compute power spectrum
P = abs(x_hat).^2;

% Convert lambda to desired units
[x_axis, x_label, x_unit] = convert_lambda_units(lambda, options.XAxisUnits);

% Create plots based on type
switch lower(options.Type)
    case 'power'
        fig = plot_power_spectrum(x_axis, P, x_label, x_unit, options);
        
    case 'index'
        fig = plot_index_spectrum(P, lambda, options);
        
    case 'loglog'
        fig = plot_loglog_spectrum(x_axis, P, x_label, x_unit, options);
        
    case 'normalized'
        fig = plot_normalized_spectrum(x_axis, P, x_label, x_unit, options);
        
    case 'bands'
        fig = plot_band_spectrum(x_axis, P, x_label, x_unit, options);
        
    case 'all'
        fig = plot_all_spectra(x_axis, P, x_label, x_unit, options);
end

% Visualize top modes if requested
if options.TopModes > 0
    fig_modes = visualize_top_modes(signal, sig_spectral, P, lambda, options.TopModes);
    fig = [fig; fig_modes];
end

end

%% ========================================================================
%  PLOTTING FUNCTIONS
%  ========================================================================

function fig = plot_power_spectrum(x_axis, P, x_label, x_unit, opts)
%PLOT_POWER_SPECTRUM Standard power spectrum vs eigenvalue

fig = figure('Name', 'Eigenspectrum - Power');

if strcmp(opts.Scale, 'log')
    semilogy(x_axis, P, '.-', 'Color', opts.Color, ...
        'LineWidth', opts.LineWidth, 'MarkerSize', opts.MarkerSize);
else
    plot(x_axis, P, '.-', 'Color', opts.Color, ...
        'LineWidth', opts.LineWidth, 'MarkerSize', opts.MarkerSize);
end

grid on;
xlabel(x_label);
ylabel('Power |x̂|²');
title('Mesh Fourier Power Spectrum');

% Add threshold line if requested
if opts.ShowThreshold
    add_energy_threshold(x_axis, P, opts.ThresholdValue);
end

end

function fig = plot_index_spectrum(P, lambda, opts)
%PLOT_INDEX_SPECTRUM Power vs mode index (clearer for non-uniform spacing)

fig = figure('Name', 'Eigenspectrum - Index');

mode_idx = 1:length(P);

if strcmp(opts.Scale, 'log')
    semilogy(mode_idx, P, 'Color', opts.Color, ...
        'LineWidth', opts.LineWidth);
else
    plot(mode_idx, P, 'Color', opts.Color, ...
        'LineWidth', opts.LineWidth);
end

grid on;
xlabel('Eigenmode Index k');
ylabel('Power |x̂_k|²');
title('Eigenmode Power Spectrum');

% Add interpretation text
text(0.98, 0.98, sprintf(['Early modes → large-scale\n' ...
                          'Later modes → fine detail']), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'HorizontalAlignment', 'right', 'FontSize', 9, ...
    'BackgroundColor', 'w', 'EdgeColor', 'k');

% Add threshold line if requested
if opts.ShowThreshold
    add_energy_threshold(mode_idx, P, opts.ThresholdValue);
end

end

function fig = plot_loglog_spectrum(x_axis, P, x_label, x_unit, opts)
%PLOT_LOGLOG_SPECTRUM Log-log plot for power law analysis

fig = figure('Name', 'Eigenspectrum - Log-Log');

% Remove zeros for log-log plot
valid_idx = (x_axis > 0) & (P > 0);
x_valid = x_axis(valid_idx);
P_valid = P(valid_idx);

loglog(x_valid, P_valid, '.', 'Color', opts.Color, ...
    'MarkerSize', opts.MarkerSize);

grid on;
xlabel(x_label);
ylabel('|x̂|²');
title('Log-Log Spatial Spectrum');

% Fit power law and display
if length(x_valid) > 2
    % Fit in log space: log(P) = a*log(x) + b
    coeffs = polyfit(log10(x_valid), log10(P_valid), 1);
    exponent = coeffs(1);
    
    % Plot fit
    hold on;
    x_fit = logspace(log10(min(x_valid)), log10(max(x_valid)), 100);
    P_fit = 10^coeffs(2) * x_fit.^exponent;
    plot(x_fit, P_fit, 'r--', 'LineWidth', 2);
    
    legend('Data', sprintf('P ∝ %s^{%.2f}', x_unit, exponent), ...
        'Location', 'best');
    
    % Add interpretation
    if exponent < 0
        interp_text = sprintf('Power law: %s^{%.2f}\n(High-freq attenuation)', x_unit, exponent);
    else
        interp_text = sprintf('Power law: %s^{%.2f}\n(Low-freq attenuation)', x_unit, exponent);
    end
    
    text(0.05, 0.05, interp_text, 'Units', 'normalized', ...
        'FontSize', 10, 'BackgroundColor', 'w', 'EdgeColor', 'k');
end

end

function fig = plot_normalized_spectrum(x_axis, P, x_label, x_unit, opts)
%PLOT_NORMALIZED_SPECTRUM Energy-normalized spectrum (DEC-correct)

fig = figure('Name', 'Eigenspectrum - Normalized');

% Normalize to fractional energy (Parseval)
P_norm = P / sum(P);

if strcmp(opts.Scale, 'log')
    semilogy(x_axis, P_norm, '.-', 'Color', opts.Color, ...
        'LineWidth', opts.LineWidth, 'MarkerSize', opts.MarkerSize);
else
    plot(x_axis, P_norm, '.-', 'Color', opts.Color, ...
        'LineWidth', opts.LineWidth, 'MarkerSize', opts.MarkerSize);
end

grid on;
xlabel(x_label);
ylabel('Fraction of Energy');
title('Energy-Normalized Spectrum (Parseval)');

% Add cumulative energy curve
hold on;
yyaxis right;
cumulative = cumsum(P_norm);
plot(x_axis, cumulative, 'b--', 'LineWidth', 1.5);
ylabel('Cumulative Energy Fraction');

% Add threshold line if requested
if opts.ShowThreshold
    threshold_frac = opts.ThresholdValue / 100;
    idx_threshold = find(cumulative >= threshold_frac, 1);
    
    if ~isempty(idx_threshold)
        x_threshold = x_axis(idx_threshold);
        
        xline(x_threshold, 'r--', 'LineWidth', 2, ...
            'Label', sprintf('%.0f%% energy\n%s=%.2f', ...
            opts.ThresholdValue, x_unit, x_threshold));
        
        fprintf('%.0f%% of energy in first %d modes (%s < %.4f)\n', ...
            opts.ThresholdValue, idx_threshold, x_unit, x_threshold);
    end
end

legend('Fractional Power', 'Cumulative Energy', 'Location', 'best');

end

function fig = plot_band_spectrum(x_axis, P, x_label, x_unit, opts)
%PLOT_BAND_SPECTRUM Band-aggregated spectrum (binned frequencies)

fig = figure('Name', 'Eigenspectrum - Bands');

% Create logarithmic band edges
x_min = max(min(x_axis(x_axis > 0)), 1e-6);
x_max = max(x_axis);
edges = logspace(log10(x_min), log10(x_max), opts.NumBands + 1);

% Aggregate power in each band
Pb = zeros(opts.NumBands, 1);
band_centers = zeros(opts.NumBands, 1);

for b = 1:opts.NumBands
    idx = (x_axis >= edges(b)) & (x_axis < edges(b+1));
    Pb(b) = sum(P(idx));
    band_centers(b) = sqrt(edges(b) * edges(b+1));  % Geometric mean
end

% Plot
bar(1:opts.NumBands, Pb, 'FaceColor', opts.Color, 'EdgeColor', 'k');
grid on;
xlabel('Spatial Frequency Band');
ylabel('Aggregated Power');
title(sprintf('Band-Aggregated Spectrum (%d bands)', opts.NumBands));

% Add custom x-tick labels
num_labels = min(6, opts.NumBands);
label_idx = round(linspace(1, opts.NumBands, num_labels));
xticks(label_idx);
xticklabels(arrayfun(@(i) sprintf('%.2f', band_centers(i)), label_idx, 'UniformOutput', false));
xlabel(sprintf('Spatial Frequency Band (%s)', x_unit));

% Add interpretation text
text(0.98, 0.98, 'Analogue of EEG frequency bands', ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'HorizontalAlignment', 'right', 'FontSize', 9, ...
    'BackgroundColor', 'w', 'EdgeColor', 'k');

end

function fig = plot_all_spectra(x_axis, P, x_label, x_unit, opts)
%PLOT_ALL_SPECTRA All spectrum types in subplots

fig = figure('Name', 'Eigenspectrum - All', 'Position', [100 100 1200 800]);

% 1. Power spectrum
subplot(2, 3, 1);
plot(x_axis, P, '.-', 'Color', opts.Color, 'LineWidth', 1.2);
grid on;
xlabel(x_label); ylabel('Power');
title('Power Spectrum');

% 2. Index spectrum (log scale)
subplot(2, 3, 2);
semilogy(1:length(P), P, 'Color', opts.Color, 'LineWidth', 1.2);
grid on;
xlabel('Mode Index'); ylabel('Power (log)');
title('Index Spectrum');

% 3. Log-log
subplot(2, 3, 3);
valid_idx = (x_axis > 0) & (P > 0);
loglog(x_axis(valid_idx), P(valid_idx), '.', 'Color', opts.Color);
grid on;
xlabel(sprintf('%s (log)', x_unit)); ylabel('Power (log)');
title('Log-Log Spectrum');

% 4. Normalized with cumulative
subplot(2, 3, 4);
P_norm = P / sum(P);
plot(x_axis, P_norm, '.-', 'Color', opts.Color, 'LineWidth', 1.2);
hold on;
yyaxis right;
plot(x_axis, cumsum(P_norm), 'b--', 'LineWidth', 1.5);
grid on;
xlabel(x_label); ylabel('Fraction');
title('Normalized Energy');

% 5. Band-aggregated
subplot(2, 3, 5);
x_min = max(min(x_axis(x_axis > 0)), 1e-6);
x_max = max(x_axis);
edges = logspace(log10(x_min), log10(x_max), opts.NumBands + 1);
Pb = zeros(opts.NumBands, 1);
for b = 1:opts.NumBands
    idx = (x_axis >= edges(b)) & (x_axis < edges(b+1));
    Pb(b) = sum(P(idx));
end
bar(Pb, 'FaceColor', opts.Color);
grid on;
xlabel('Band'); ylabel('Power');
title(sprintf('%d Bands', opts.NumBands));

% 6. Top modes bar chart
subplot(2, 3, 6);
[P_sorted, sort_idx] = sort(P, 'descend');
num_top = min(15, length(P));
bar(1:num_top, P_sorted(1:num_top), 'FaceColor', opts.Color);
grid on;
xlabel('Rank'); ylabel('Power');
title('Top Modes');
xticks(1:num_top);
xticklabels(arrayfun(@(i) sprintf('%d', sort_idx(i)), 1:num_top, 'UniformOutput', false));

end

%% ========================================================================
%  HELPER FUNCTIONS
%  ========================================================================

function add_energy_threshold(x_axis, P, threshold_pct)
%ADD_ENERGY_THRESHOLD Add vertical line at energy threshold

P_norm = P / sum(P);
cumulative = cumsum(P_norm);
threshold_frac = threshold_pct / 100;

idx_threshold = find(cumulative >= threshold_frac, 1);

if ~isempty(idx_threshold)
    x_threshold = x_axis(idx_threshold);
    
    hold on;
    xline(x_threshold, 'r--', 'LineWidth', 2, ...
        'Label', sprintf('%.0f%% energy', threshold_pct));
    
    fprintf('%.0f%% of energy in first %d modes\n', threshold_pct, idx_threshold);
end

end

function fig = visualize_top_modes(signal, sig_spectral, P, lambda, num_modes)
%VISUALIZE_TOP_MODES Show spatial patterns of dominant modes

% Sort by power
[P_sorted, sort_idx] = sort(P, 'descend');
top_modes = sort_idx(1:min(num_modes, length(P)));

% Get eigenvectors (spatial patterns)
Phi = sig_spectral.Domain.U;  % [N × K]

% Get manifold for plotting
manifold = signal.Domain;

% Create figure
num_cols = ceil(sqrt(num_modes));
num_rows = ceil(num_modes / num_cols);
fig = figure('Name', 'Top Eigenmodes', ...
    'Position', [100 100 300*num_cols 300*num_rows]);

for i = 1:num_modes
    k = top_modes(i);
    mode_pattern = Phi(:, k);
    
    subplot(num_rows, num_cols, i);
    
    % Plot spatial pattern
    trisurf(manifold.Faces, manifold.Vertices(:,1), manifold.Vertices(:,2), manifold.Vertices(:,3), ...
        mode_pattern, 'EdgeColor', 'none');
    
    shading interp;
    colormap(jet);
    colorbar;
    axis equal tight off;
    view([0 90]);
    
    title(sprintf('Mode %d\n\\lambda=%.2f, P=%.2e', ...
        k, lambda(k), P_sorted(i)));
end

sgtitle(fig, sprintf('Top %d Eigenmodes (sorted by power)', num_modes));

end

function [x_axis, x_label, x_unit] = convert_lambda_units(lambda, units)
%CONVERT_LAMBDA_UNITS Convert eigenvalue to desired units
%
%   [x_axis, x_label, x_unit] = convert_lambda_units(lambda, units)
%
% Inputs:
%   lambda - Eigenvalue array
%   units  - 'eigenvalue', 'wavenumber', or 'wavelength'
%
% Outputs:
%   x_axis  - Converted values
%   x_label - X-axis label string
%   x_unit  - Unit symbol string

switch lower(units)
    case 'eigenvalue'
        x_axis = lambda;
        x_label = 'Eigenvalue \lambda (spatial frequency²)';
        x_unit = '\lambda';
        
    case 'wavenumber'
        x_axis = sqrt(lambda);
        x_label = 'Wavenumber k = sqrt(\lambda)';
        x_unit = 'k';
        
    case 'wavelength'
        x_axis = 2*pi ./ sqrt(lambda);
        x_label = 'Wavelength = 2\pi/sqrt(\lambda)';
        x_unit = '\lambda_{wave}';
        
    case 'halfwavelength'
        x_axis = pi ./ sqrt(lambda);
        x_label = 'Half-wavelength = \pi/sqrt(\lambda)';
        x_unit = '\lambda_{1/2}';
        
    otherwise
        error('convert_lambda_units:InvalidUnits', ...
            'Units must be eigenvalue, wavenumber, wavelength, or halfwavelength');
end

end
