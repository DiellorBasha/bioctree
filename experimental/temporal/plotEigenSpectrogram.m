function fig = plotEigenSpectrogram(coeffsL, coeffsR, eigenvaluesL, eigenvaluesR, sfreq, opts)
%PLOTEIGENSPECTROGRAM Plot eigenmode power as a 2-D image (mode × time).
%
%   fig = plotEigenSpectrogram(coeffsL, coeffsR, eigenvaluesL, eigenvaluesR, sfreq)
%   fig = plotEigenSpectrogram(__, Name=Value)
%
%   Displays a spectrogram-like image where the y-axis is eigenmode index
%   (or eigenvalue) and the x-axis is time, with color encoding
%   instantaneous squared coefficient magnitude.
%
%   Inputs:
%       coeffsL      - [nModesL × nSamples] eigenmode coefficients, left
%       coeffsR      - [nModesR × nSamples] eigenmode coefficients, right
%       eigenvaluesL - [nModesL × 1] eigenvalues, left hemisphere
%       eigenvaluesR - [nModesR × 1] eigenvalues, right hemisphere
%       sfreq        - sampling frequency (Hz)
%
%   Name-Value Options:
%       YAxis       - 'index' (default) or 'eigenvalue'
%       LogColor    - use log10 color scale (default: true)
%       MaxModes    - max modes on y-axis   (default: all)
%       Decimate    - temporal decimation factor (default: 1, no decimation)
%       TStartSec   - time offset for x-axis (default: 0)
%       Colormap    - colormap name (default: "parula")
%       CLim        - [lo hi] color limits, or [] for auto (default: [])
%       Title       - figure title (default: "Eigenmode Spectrogram")
%
%   Output:
%       fig - figure handle

arguments
    coeffsL      (:,:) double
    coeffsR      (:,:) double
    eigenvaluesL (:,1) double
    eigenvaluesR (:,1) double
    sfreq        (1,1) double {mustBePositive}
    opts.YAxis    (1,1) string {mustBeMember(opts.YAxis, ["index","eigenvalue"])} = "index"
    opts.LogColor (1,1) logical = true
    opts.MaxModes (1,1) double {mustBePositive} = Inf
    opts.Decimate (1,1) double {mustBePositive, mustBeInteger} = 1
    opts.TStartSec(1,1) double = 0
    opts.Colormap (1,1) string = "parula"
    opts.CLim     (1,:) double = []
    opts.Title    (1,1) string = "Eigenmode Spectrogram"
end

fig = figure('Name', opts.Title, 'NumberTitle', 'off');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

plotHemiSpectrogram(coeffsL, eigenvaluesL, sfreq, "Left hemisphere", opts);
plotHemiSpectrogram(coeffsR, eigenvaluesR, sfreq, "Right hemisphere", opts);

applyPlotDefaults(fig);
sgtitle(opts.Title, 'FontWeight', 'bold', 'FontSize', 16);

end

% ---- Helper ----
function plotHemiSpectrogram(coeffs, eigenvalues, sfreq, titleStr, opts)
    nModes = min(size(coeffs, 1), opts.MaxModes);
    coeffs = coeffs(1:nModes, :);
    eigenvalues = eigenvalues(1:nModes);

    % Instantaneous power
    P = coeffs.^2;

    % Temporal decimation (average pooling)
    if opts.Decimate > 1
        nSamp = size(P, 2);
        nBlocks = floor(nSamp / opts.Decimate);
        P = P(:, 1:nBlocks*opts.Decimate);
        P = squeeze(mean(reshape(P, nModes, opts.Decimate, nBlocks), 2));
        dt = opts.Decimate / sfreq;
    else
        nBlocks = size(P, 2);
        dt = 1 / sfreq;
    end

    tVec = opts.TStartSec + (0:nBlocks-1) * dt;

    if opts.LogColor
        P = log10(P + eps);
    end

    % Y-axis
    if opts.YAxis == "eigenvalue"
        yVec = eigenvalues;
        yLabel = "Eigenvalue \lambda";
    else
        yVec = (1:nModes)';
        yLabel = "Mode index";
    end

    nexttile;
    imagesc(tVec, yVec, P);
    axis xy;
    xlabel("Time (s)");
    ylabel(yLabel);
    title(titleStr);
    colormap(gca, opts.Colormap);

    if ~isempty(opts.CLim)
        clim(opts.CLim);
    end

    cb = colorbar;
    if opts.LogColor
        cb.Label.String = "log_{10} power";
    else
        cb.Label.String = "power  c_k^2(t)";
    end
end
