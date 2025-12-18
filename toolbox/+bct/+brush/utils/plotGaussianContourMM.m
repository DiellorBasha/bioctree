function plotGaussianContourMM(sigma, L, dx, levels)
% plotGaussianContourMM
%
% Plot an analytic 2D Gaussian kernel using contourf, with
% contour labels expressed in millimeters via LabelFormat.
% Only the smallest and largest contour levels are labeled.
%
% Inputs
% ------
% sigma  : Gaussian standard deviation (mm)
% L      : half-size of plotting domain
% dx     : spatial resolution
% levels : contour levels (e.g. [0.8 0.6 0.5 0.4 0.2])

    arguments
        sigma  (1,1) double {mustBePositive}
        L      (1,1) double {mustBePositive}
        dx     (1,1) double {mustBePositive}
        levels (1,:) double {mustBeGreaterThan(levels,0), mustBeLessThanOrEqual(levels,1)}
    end

    % --- Coordinate grid ---
    x = -L:dx:L;
    y = -L:dx:L;
    [X,Y] = meshgrid(x,y);

    % --- Analytic Gaussian ---
    w = exp(-(X.^2 + Y.^2) / (2*sigma^2));

    % --- Levels to label ---
    labelLevels = [min(levels), max(levels)];

    % --- Plot ---
    figure
    contourf(X, Y, w, levels, ...
        "ShowText", true, ...
        "LabelFormat", @(vals) gaussianLabelMM(vals, sigma, labelLevels), ...
        "FaceAlpha", 0.25);

    axis equal tight
    colormap(turbo)
    colorbar

    % --- Title with FWHM ---
    FWHM = 2*sqrt(2*log(2))*sigma;
    title(sprintf('Gaussian kernel (\\sigma = %.1f mm, FWHM = %.1f mm)', ...
                  sigma, FWHM));

    xlabel('x')
    ylabel('y')
end
