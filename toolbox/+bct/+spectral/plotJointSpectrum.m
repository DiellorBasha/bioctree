function fig = plotJointSpectrum(spectrum, options)
%PLOTJOINTSPECTRUM Visualize joint lambda-omega spectrum
%
%   fig = bct.spectral.plotJointSpectrum(spectrum)
%   fig = bct.spectral.plotJointSpectrum(spectrum, Name, Value)
%
% Purpose
%   Creates a comprehensive visualization of the joint time-vertex Fourier
%   transform, showing the 2D spectrum and marginal distributions.
%
% Inputs
%   spectrum - Struct from bct.spectral.jointSpectrum
%
% Name-Value Arguments
%   FreqRange      - [fmin fmax] frequency range to display (Hz, default: all)
%   EigenRange     - [kmin kmax] eigenmode range to display (default: all)
%   Scale          - 'linear' | 'log' | 'db' (default: 'log')
%   ColorLimits    - [cmin cmax] color axis limits (default: auto)
%   Colormap       - Colormap name (default: 'parula')
%   MarkPeaks      - Plot top peaks (default: false)
%   NumPeaks       - Number of peaks to mark (default: 5)
%   Layout         - 'full' | 'simple' (default: 'full')
%                    'full': 4-panel with marginals
%                    'simple': single spectrum panel
%   FFTShift       - Apply fftshift to center DC (default: true)
%
% Output
%   fig - Figure handle
%
% Examples
%   % Basic plot
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   eigen = M.eigenmodes(500);
%   % ... create time-varying field F ...
%   spec = bct.spectral.jointSpectrum(M, F);
%   bct.spectral.plotJointSpectrum(spec);
%
%   % Custom visualization
%   bct.spectral.plotJointSpectrum(spec, 'Scale', 'db', ...
%                                  'FreqRange', [0 50], ...
%                                  'EigenRange', [1 300], ...
%                                  'MarkPeaks', true);
%
% See also: bct.spectral.jointSpectrum

arguments
    spectrum struct
    options.FreqRange (1,2) double = [0 0]
    options.EigenRange (1,2) double = [0 0]
    options.Scale (1,1) string {mustBeMember(options.Scale, ["linear", "log", "db"])} = "log"
    options.ColorLimits (1,2) double = [0 0]
    options.Colormap (1,1) string = "parula"
    options.MarkPeaks (1,1) logical = false
    options.NumPeaks (1,1) {mustBeInteger, mustBePositive} = 5
    options.Layout (1,1) string {mustBeMember(options.Layout, ["full", "simple"])} = "full"
    options.FFTShift (1,1) logical = true
end

%% Validate Input

required_fields = {'magnitude', 'eigenvalues', 'frequencies', 'eigenmodeAxis'};
for i = 1:length(required_fields)
    if ~isfield(spectrum, required_fields{i})
        error('bct:spectral:InvalidSpectrum', ...
            'spectrum struct missing field: %s', required_fields{i});
    end
end

%% Extract Data

mag = spectrum.magnitude;       % [K × F]
freqs = spectrum.frequencies;   % [1 × F]
eigenmodes = spectrum.eigenmodeAxis;  % [K × 1]
lambda = spectrum.eigenvalues;  % [K × 1]

[K, F] = size(mag);

% Apply fftshift if requested
if options.FFTShift
    mag = fftshift(mag, 2);
    freqs_shifted = freqs - max(freqs)/2;
    freqs_display = freqs_shifted;
else
    freqs_display = freqs;
end

% Apply scaling
switch options.Scale
    case 'linear'
        mag_display = mag;
        scale_label = '';
    case 'log'
        mag_display = log10(mag + eps);
        scale_label = 'log_{10}';
    case 'db'
        mag_display = 20*log10(mag + eps);
        scale_label = 'dB';
end

%% Determine Display Ranges

% Frequency range
if all(options.FreqRange == 0)
    freq_mask = true(1, F);
    freq_range_actual = [min(freqs_display), max(freqs_display)];
else
    freq_mask = freqs_display >= options.FreqRange(1) & freqs_display <= options.FreqRange(2);
    freq_range_actual = options.FreqRange;
end

% Eigenmode range
if all(options.EigenRange == 0)
    eigen_mask = true(K, 1);
    eigen_range_actual = [1, K];
else
    eigen_mask = eigenmodes >= options.EigenRange(1) & eigenmodes <= options.EigenRange(2);
    eigen_range_actual = options.EigenRange;
end

% Extract display window
mag_window = mag_display(eigen_mask, freq_mask);
freqs_window = freqs_display(freq_mask);
eigenmodes_window = eigenmodes(eigen_mask);

%% Create Figure

if strcmp(options.Layout, 'full')
    fig = figure('Position', [100 100 1400 900], 'Color', 'w');
else
    fig = figure('Position', [100 100 800 600], 'Color', 'w');
end

%% Plot Based on Layout

if strcmp(options.Layout, 'full')
    %% Full Layout: 4-panel with marginals
    
    % Panel 1: Full Spectrum
    subplot(2,2,1);
    imagesc(freqs_window, eigenmodes_window, mag_window);
    axis xy;
    cb1 = colorbar;
    xlabel('Frequency (Hz)');
    ylabel('Eigenmode Index');
    title(sprintf('Joint \\lambda-\\omega Spectrum (%s scale)', scale_label));
    colormap(gca, options.Colormap);
    
    if all(options.ColorLimits ~= 0)
        clim(options.ColorLimits);
    end
    
    % Panel 2: Zoomed spectrum (if full range)
    subplot(2,2,2);
    K_zoom = min(ceil(K/2), K);  % Show first half or less
    mag_zoom = mag_display(1:K_zoom, freq_mask);
    eigenmodes_zoom = eigenmodes(1:K_zoom);
    
    imagesc(freqs_window, eigenmodes_zoom, mag_zoom);
    axis xy;
    cb2 = colorbar;
    xlabel('Frequency (Hz)');
    ylabel('Eigenmode Index');
    title(sprintf('Zoomed View (first %d modes)', K_zoom));
    colormap(gca, options.Colormap);
    
    % Mark peaks if requested
    if options.MarkPeaks
        hold on;
        [peaks_val, peaks_idx] = maxk(mag(:), options.NumPeaks);
        for i = 1:options.NumPeaks
            [k_idx, f_idx] = ind2sub(size(mag), peaks_idx(i));
            if k_idx <= K_zoom && freq_mask(f_idx)
                plot(freqs_display(f_idx), k_idx, 'r*', ...
                    'MarkerSize', 12, 'LineWidth', 2);
            end
        end
        hold off;
    end
    
    % Panel 3: Marginal Eigenmode Power
    subplot(2,2,3);
    if isfield(spectrum, 'powerEigen')
        powerEigen = spectrum.powerEigen(eigen_mask);
        plot(eigenmodes_window, powerEigen, 'b-', 'LineWidth', 1.5);
        xlabel('Eigenmode Index');
        ylabel('Total Power');
        title('Marginal Eigenmode Spectrum');
        grid on;
        xlim(eigen_range_actual);
        
        % Mark peaks
        if options.MarkPeaks
            hold on;
            [peak_vals, peak_locs] = maxk(powerEigen, min(options.NumPeaks, length(powerEigen)));
            plot(eigenmodes_window(peak_locs), peak_vals, 'ro', ...
                'MarkerSize', 8, 'MarkerFaceColor', 'r');
            hold off;
        end
    else
        text(0.5, 0.5, 'Marginal not available', ...
            'HorizontalAlignment', 'center');
    end
    
    % Panel 4: Marginal Temporal Power
    subplot(2,2,4);
    if isfield(spectrum, 'powerFreq')
        powerFreq = spectrum.powerFreq(freq_mask);
        
        if options.FFTShift
            powerFreq = fftshift(powerFreq);
        end
        
        plot(freqs_window, powerFreq, 'r-', 'LineWidth', 1.5);
        xlabel('Frequency (Hz)');
        ylabel('Total Power');
        title('Marginal Temporal Spectrum');
        grid on;
        xlim(freq_range_actual);
        
        % Mark peaks
        if options.MarkPeaks
            hold on;
            [peak_vals, peak_locs] = maxk(powerFreq, min(options.NumPeaks, length(powerFreq)));
            plot(freqs_window(peak_locs), peak_vals, 'bo', ...
                'MarkerSize', 8, 'MarkerFaceColor', 'b');
            hold off;
        end
    else
        text(0.5, 0.5, 'Marginal not available', ...
            'HorizontalAlignment', 'center');
    end
    
    % Super title
    sgtitle('Joint Lambda-Omega Spectrum Analysis', ...
        'FontSize', 14, 'FontWeight', 'bold');
    
else
    %% Simple Layout: Single panel
    
    imagesc(freqs_window, eigenmodes_window, mag_window);
    axis xy;
    colorbar;
    xlabel('Frequency (Hz)', 'FontSize', 12);
    ylabel('Eigenmode Index', 'FontSize', 12);
    title(sprintf('Joint \\lambda-\\omega Spectrum (%s scale)', scale_label), ...
        'FontSize', 14);
    colormap(gca, options.Colormap);
    
    if all(options.ColorLimits ~= 0)
        clim(options.ColorLimits);
    end
    
    % Mark peaks if requested
    if options.MarkPeaks
        hold on;
        [peaks_val, peaks_idx] = maxk(mag_window(:), options.NumPeaks);
        for i = 1:options.NumPeaks
            [k_idx, f_idx] = ind2sub(size(mag_window), peaks_idx(i));
            plot(freqs_window(f_idx), eigenmodes_window(k_idx), 'r*', ...
                'MarkerSize', 14, 'LineWidth', 2);
        end
        hold off;
        legend('Peaks', 'Location', 'best');
    end
end

end
