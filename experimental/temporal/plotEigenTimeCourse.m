function fig = plotEigenTimeCourse(coeffsL, coeffsR, eigenvaluesL, eigenvaluesR, sfreq, opts)
%PLOTEIGENTIMECOURSE Plot eigenmode coefficient time courses.
%
%   fig = plotEigenTimeCourse(coeffsL, coeffsR, eigenvaluesL, eigenvaluesR, sfreq)
%   fig = plotEigenTimeCourse(__, Name=Value)
%
%   Displays the temporal waveforms of selected eigenmode coefficients
%   for both hemispheres, stacked vertically with mode index labels.
%
%   Inputs:
%       coeffsL      - [nModesL × nSamples] eigenmode coefficients, left
%       coeffsR      - [nModesR × nSamples] eigenmode coefficients, right
%       eigenvaluesL - [nModesL × 1] eigenvalues, left hemisphere
%       eigenvaluesR - [nModesR × 1] eigenvalues, right hemisphere
%       sfreq        - sampling frequency (Hz)
%
%   Name-Value Options:
%       Modes       - vector of mode indices to display (default: [1 2 3 5 10 20])
%       TStartSec   - time offset for x-axis labeling  (default: 0)
%       Normalize   - normalize each trace to [-1,1]    (default: true)
%       Title       - figure title (default: "Eigenmode Time Courses")
%
%   Output:
%       fig - figure handle

arguments
    coeffsL      (:,:) double
    coeffsR      (:,:) double
    eigenvaluesL (:,1) double
    eigenvaluesR (:,1) double
    sfreq        (1,1) double {mustBePositive}
    opts.Modes     (1,:) double {mustBePositive, mustBeInteger} = [1 2 3 5 10 20]
    opts.TStartSec (1,1) double = 0
    opts.Normalize (1,1) logical = true
    opts.Title     (1,1) string = "Eigenmode Time Courses"
end

% ---- Clamp modes to available range ----
modesL = opts.Modes(opts.Modes <= size(coeffsL, 1));
modesR = opts.Modes(opts.Modes <= size(coeffsR, 1));

nSamp = size(coeffsL, 2);
t = opts.TStartSec + (0:nSamp-1) / sfreq;

fig = figure('Name', opts.Title, 'NumberTitle', 'off');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

plotHemi(t, coeffsL, eigenvaluesL, modesL, "Left hemisphere", opts.Normalize);
plotHemi(t, coeffsR, eigenvaluesR, modesR, "Right hemisphere", opts.Normalize);

applyPlotDefaults(fig);
sgtitle(opts.Title, 'FontWeight', 'bold', 'FontSize', 16);

end

% ---- Helper ----
function plotHemi(t, coeffs, eigenvalues, modes, titleStr, doNormalize)
    nModes = numel(modes);
    nexttile;
    hold on;

    spacing = 0;
    yTicks = zeros(nModes, 1);
    yLabels = strings(nModes, 1);

    for i = 1:nModes
        k = modes(i);
        trace = coeffs(k, :);
        if doNormalize && max(abs(trace)) > 0
            trace = trace / max(abs(trace));
        end
        offset = -(i-1) * 2.2;
        plot(t, trace + offset, 'LineWidth', 0.8);
        yTicks(i) = offset;
        yLabels(i) = sprintf("k=%d (\\lambda=%.1f)", k, eigenvalues(k));
    end

    hold off;
    xlabel("Time (s)");
    yticks(flip(yTicks));
    yticklabels(flip(yLabels));
    title(titleStr);
    xlim([t(1) t(end)]);
end
