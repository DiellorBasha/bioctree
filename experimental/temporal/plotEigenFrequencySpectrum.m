function fig = plotEigenFrequencySpectrum(psdL, psdR, freqs, eigenvaluesL, eigenvaluesR, opts)
%PLOTEIGENFREQUENCYSPECTRUM Plot PSD curves for selected eigenmodes.
%
%   fig = plotEigenFrequencySpectrum(psdL, psdR, freqs, eigenvaluesL, eigenvaluesR)
%   fig = plotEigenFrequencySpectrum(__, Name=Value)
%
%   Overlays the frequency power spectrum of selected eigenmode
%   coefficients for both hemispheres side-by-side.
%
%   Inputs:
%       psdL         - [nModesL × nFreqs] power spectral density, left
%       psdR         - [nModesR × nFreqs] power spectral density, right
%       freqs        - [1 × nFreqs] frequency axis (Hz)
%       eigenvaluesL - [nModesL × 1] eigenvalues, left hemisphere
%       eigenvaluesR - [nModesR × 1] eigenvalues, right hemisphere
%
%   Name-Value Options:
%       Modes       - mode indices to plot (default: [1 2 3 5 10 20])
%       FreqRange   - [fLow fHigh] Hz display range (default: [0.5 100])
%       LogY        - log scale on y-axis (default: true)
%       LogX        - log scale on x-axis (default: false)
%       Title       - figure title (default: "Eigenmode Frequency Spectra")
%       BandLines   - show canonical band boundaries (default: true)
%
%   Output:
%       fig - figure handle

arguments
    psdL         (:,:) double
    psdR         (:,:) double
    freqs        (1,:) double
    eigenvaluesL (:,1) double
    eigenvaluesR (:,1) double
    opts.Modes     (1,:) double {mustBePositive, mustBeInteger} = [1 2 3 5 10 20]
    opts.FreqRange (1,2) double = [0.5 100]
    opts.LogY      (1,1) logical = true
    opts.LogX      (1,1) logical = false
    opts.Title     (1,1) string = "Eigenmode Frequency Spectra"
    opts.BandLines (1,1) logical = true
end

% ---- Frequency mask ----
fMask = freqs >= opts.FreqRange(1) & freqs <= opts.FreqRange(2);
fPlot = freqs(fMask);

% ---- Clamp modes ----
modesL = opts.Modes(opts.Modes <= size(psdL, 1));
modesR = opts.Modes(opts.Modes <= size(psdR, 1));

fig = figure('Name', opts.Title, 'NumberTitle', 'off');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

plotHemi(fPlot, psdL(modesL, fMask), eigenvaluesL, modesL, ...
    "Left hemisphere", opts);
plotHemi(fPlot, psdR(modesR, fMask), eigenvaluesR, modesR, ...
    "Right hemisphere", opts);

applyPlotDefaults(fig);
sgtitle(opts.Title, 'FontWeight', 'bold', 'FontSize', 16);

end

% ---- Helpers ----
function plotHemi(f, psdSel, eigenvalues, modes, titleStr, opts)
    nexttile; hold on;

    nModes = numel(modes);
    cmap = lines(nModes);
    legendStrs = strings(1, nModes);

    for i = 1:nModes
        k = modes(i);
        plot(f, psdSel(i,:), 'Color', cmap(i,:), 'LineWidth', 1.2);
        legendStrs(i) = sprintf("k=%d (\\lambda=%.1f)", k, eigenvalues(k));
    end

    if opts.BandLines
        addBandLines();
    end

    hold off;
    xlabel("Frequency (Hz)");
    ylabel("PSD");
    title(titleStr);
    legend(legendStrs, 'Location', 'northeast', 'FontSize', 14);

    if opts.LogY
        set(gca, 'YScale', 'log');
    end
    if opts.LogX
        set(gca, 'XScale', 'log');
    end
    xlim([f(1) f(end)]);
end

function addBandLines()
    % Canonical EEG/MEG frequency band boundaries
    bands = [4 8 12 30 59];
    labels = {"\delta|\theta", "\theta|\alpha", "\alpha|\beta", "\beta|\gamma", "\gamma"};
    yl = ylim;
    for i = 1:numel(bands)
        xline(bands(i), ':', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.8, ...
            'Label', labels{i}, 'LabelVerticalAlignment', 'top', ...
            'FontSize', 14, 'LabelColor', [0.5 0.5 0.5]);
    end
    ylim(yl);
end
