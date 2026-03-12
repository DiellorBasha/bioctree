function fig = plotEigenSpectrum(coeffsL, coeffsR, eigenvaluesL, eigenvaluesR, opts)
%PLOTEIGENSPECTRUM Plot eigenmode power spectrum for both hemispheres.
%
%   fig = plotEigenSpectrum(coeffsL, coeffsR, eigenvaluesL, eigenvaluesR)
%   fig = plotEigenSpectrum(__, Name=Value)
%
%   Displays the time-averaged eigenmode power (mean of squared
%   coefficients) against eigenvalue index or eigenvalue magnitude,
%   with left and right hemispheres side-by-side.
%
%   Inputs:
%       coeffsL      - [nModesL × nSamples] eigenmode coefficients, left
%       coeffsR      - [nModesR × nSamples] eigenmode coefficients, right
%       eigenvaluesL - [nModesL × 1] eigenvalues, left hemisphere
%       eigenvaluesR - [nModesR × 1] eigenvalues, right hemisphere
%
%   Name-Value Options:
%       XAxis       - 'index' (default) or 'eigenvalue'
%       Scale       - 'linear' (default), 'log', or 'semilogy'
%       Normalize   - logical, normalize power to max=1 (default: false)
%       Title       - figure title (default: "Eigenmode Power Spectrum")
%       MaxModes    - max modes to display (default: all)
%
%   Output:
%       fig - figure handle

arguments
    coeffsL      (:,:) double
    coeffsR      (:,:) double
    eigenvaluesL (:,1) double
    eigenvaluesR (:,1) double
    opts.XAxis     (1,1) string {mustBeMember(opts.XAxis, ["index","eigenvalue"])} = "index"
    opts.Scale     (1,1) string {mustBeMember(opts.Scale, ["linear","log","semilogy"])} = "linear"
    opts.Normalize (1,1) logical = false
    opts.Title     (1,1) string = "Eigenmode Power Spectrum"
    opts.MaxModes  (1,1) double {mustBePositive} = Inf
end

% ---- Compute power ----
powerL = mean(coeffsL.^2, 2);
powerR = mean(coeffsR.^2, 2);

% ---- Truncate if requested ----
nL = min(numel(powerL), opts.MaxModes);
nR = min(numel(powerR), opts.MaxModes);
powerL = powerL(1:nL);
powerR = powerR(1:nR);
eigenvaluesL = eigenvaluesL(1:nL);
eigenvaluesR = eigenvaluesR(1:nR);

% ---- Normalize ----
if opts.Normalize
    powerL = powerL / max(powerL);
    powerR = powerR / max(powerR);
end

% ---- X-axis values ----
if opts.XAxis == "eigenvalue"
    xL = eigenvaluesL;
    xR = eigenvaluesR;
    xLabel = "Eigenvalue \lambda";
else
    xL = (1:nL)';
    xR = (1:nR)';
    xLabel = "Mode index";
end

% ---- Plot ----
fig = figure('Name', opts.Title, 'NumberTitle', 'off');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

hemis = {"Left hemisphere", "Right hemisphere"};
powers = {powerL, powerR};
xs = {xL, xR};

for h = 1:2
    nexttile;
    plotFn(xs{h}, powers{h}, opts.Scale);
    xlabel(xLabel);
    ylabel(yLabelStr(opts.Normalize));
    title(hemis{h});

    % Annotate peak
    [pk, idx] = max(powers{h});
    hold on;
    plot(xs{h}(idx), pk, 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    text(xs{h}(idx), pk, sprintf('  mode %d', idx), ...
        'FontSize', 14, 'Color', 'r', 'VerticalAlignment', 'bottom');
    hold off;
end

applyPlotDefaults(fig);
sgtitle(opts.Title, 'FontWeight', 'bold', 'FontSize', 16);

end

% ---- Helpers ----
function plotFn(x, y, scale)
    switch scale
        case "log"
            loglog(x, y, '-', 'LineWidth', 1.2);
        case "semilogy"
            semilogy(x, y, '-', 'LineWidth', 1.2);
        otherwise
            plot(x, y, '-', 'LineWidth', 1.2);
    end
end

function s = yLabelStr(normalized)
    if normalized
        s = "Normalized power";
    else
        s = "Mean power  \langle c_k^2 \rangle";
    end
end
