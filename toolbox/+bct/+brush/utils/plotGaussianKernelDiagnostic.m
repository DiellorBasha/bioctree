function plotGaussianKernelDiagnostic(sigma)
% plotGaussianKernelDiagnostic
%
% Fast diagnostic visualization of a Gaussian kernel.
% - Smooth filled kernel
% - Sparse automatically-chosen contour lines
% - Labels in mm via LabelFormat
% - Optimized for responsiveness

    arguments
        sigma (1,1) double {mustBePositive}
    end

    % -------------------------------
    % Hard-coded for responsiveness
    % -------------------------------
    L  = 2.5 * sigma;   % domain extent
    dx = 1;             % mm resolution (fast)

    % -------------------------------
    % Grid
    % -------------------------------
    x = -L:dx:L;
    y = -L:dx:L;
    [X,Y] = meshgrid(x,y);

    % -------------------------------
    % Gaussian kernel
    % -------------------------------
    w = exp(-(X.^2 + Y.^2) / (2*sigma^2));

    % -------------------------------
    % Number of contour levels (sparse!)
    % -------------------------------
    nLevels = 6;   % 4–8 works well for diagnostics

    % -------------------------------
    % Plot
    % -------------------------------
    [M,c]=contourf(X, Y, w, nLevels, ...
        "ShowText", true, ...
        "LabelFormat", @(vals) gaussianLabelMM(vals, sigma), ...
        "LabelSpacing", 10000);   % fewer labels

    axis equal tight
   

    % -------------------------------
    % Title
    % -------------------------------
    FWHM = 2*sqrt(2*log(2))*sigma;
    title(sprintf('Gaussian kernel (\\sigma = %.1f mm, FWHM = %.1f mm)', ...
                  sigma, FWHM));

    xlabel('x (mm)')
    ylabel('y (mm)')
end
