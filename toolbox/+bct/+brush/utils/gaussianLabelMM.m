function labels = gaussianLabelMM(vals, sigma)
% gaussianLabelMM
% Convert Gaussian contour values to distance in mm

    d = sigma * sqrt(-2*log(vals));
    labels = compose('%.1f mm', d);
end
