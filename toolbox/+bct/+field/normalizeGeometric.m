function result = normalizeGeometric(M, vectors, varargin)
%NORMALIZEGEOMETRIC Normalize vectors to fit within mesh geometry
%
% Syntax:
%   result = bct.field.normalizeGeometric(M, vectors)
%   result = bct.field.normalizeGeometric(M, vectors, Name, Value)
%
% Description:
%   Geometrically normalizes vectors so the largest magnitude vector fits
%   within a typical mesh element (triangle edge), with all others scaled
%   proportionally. This creates a clean visualization where vector lengths
%   are comparable to local mesh scale.
%
% Inputs:
%   M       - bct.Manifold object
%   vectors - [N×3] array of 3D vectors (face or vertex support)
%
% Name-Value Parameters:
%   TargetLength - Target length for largest vector (default: 'auto')
%                  'auto' - Use mean edge length
%                  scalar - Explicit target length in mesh units
%   ScaleFactor  - Multiplicative scale factor applied after normalization (default: 0.5)
%                  0.5 means largest vector is half the target length
%   MaskPercentile - Keep only top N% by magnitude (default: 100, no masking)
%   MinMagnitude   - Absolute minimum magnitude threshold (default: 0)
%
% Outputs:
%   result - Structure with fields:
%     .vectors         - [N×3] normalized vectors
%     .magnitude       - [N×1] original magnitudes
%     .normalizedMag   - [N×1] normalized magnitudes
%     .mask            - [N×1] logical mask of kept vectors
%     .maxOriginal     - Scalar, maximum original magnitude
%     .targetLength    - Scalar, target length used
%     .scaleFactor     - Scalar, final scale factor applied
%
% Examples:
%   % Auto-scale to mean edge length, largest vector is 50% of mean edge
%   result = bct.field.normalizeGeometric(M, vectorField);
%   viewer.setVector(result.vectors, ...);
%
%   % Largest vector should be exactly 1.5x mean edge length
%   result = bct.field.normalizeGeometric(M, vectorField, ...
%       'TargetLength', 'auto', 'ScaleFactor', 1.5);
%
%   % Explicit target length of 10mm, keep top 50% by magnitude
%   result = bct.field.normalizeGeometric(M, vectorField, ...
%       'TargetLength', 10, 'ScaleFactor', 1.0, 'MaskPercentile', 50);
%
%   % Remove very small vectors (< 1% of max)
%   result = bct.field.normalizeGeometric(M, vectorField, ...
%       'MinMagnitude', 0.01);  % Relative to max=1.0 after normalization
%
% See also: bct.field.generate.vectorHeat, bct.field.toTangent

% ----------------------------
% Parse inputs
% ----------------------------
p = inputParser;
p.addRequired('M', @(x) isa(x, 'bct.Manifold'));
p.addRequired('vectors', @(x) isnumeric(x) && size(x, 2) == 3);
p.addParameter('TargetLength', 'auto', @(x) (ischar(x) && strcmp(x, 'auto')) || (isnumeric(x) && isscalar(x) && x > 0));
p.addParameter('ScaleFactor', 0.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('MaskPercentile', 100, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 100);
p.addParameter('MinMagnitude', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.parse(M, vectors, varargin{:});

targetLength = p.Results.TargetLength;
scaleFactor = p.Results.ScaleFactor;
maskPercentile = p.Results.MaskPercentile;
minMagnitude = p.Results.MinMagnitude;

% ----------------------------
% Compute magnitudes
% ----------------------------
mag = sqrt(sum(vectors.^2, 2));  % [N×1]
maxMag = max(mag);

if maxMag == 0
    warning('bct:field:normalizeGeometric:ZeroField', ...
        'All vectors have zero magnitude. Returning zeros.');
    result = struct();
    result.vectors = vectors;
    result.magnitude = mag;
    result.normalizedMag = mag;
    result.mask = false(size(mag));
    result.maxOriginal = 0;
    result.targetLength = 0;
    result.scaleFactor = scaleFactor;
    return;
end

% ----------------------------
% Determine target length
% ----------------------------
if ischar(targetLength) && strcmp(targetLength, 'auto')
    % Use mean edge length from geometry
    geom = M.geometry();
    edgeLengths = geom.edge.lengths.value;
    targetLength = mean(edgeLengths);
end

% ----------------------------
% Normalize to [0, 1], then scale to target
% ----------------------------
% First normalize so max magnitude = 1.0
normVectors = vectors ./ maxMag;
normMag = mag ./ maxMag;  % Now in [0, 1]

% Then scale so max = targetLength * scaleFactor
finalScale = targetLength * scaleFactor;
scaledVectors = normVectors * finalScale;
scaledMag = normMag * finalScale;

% ----------------------------
% Apply masking
% ----------------------------
mask = true(size(mag));

% Percentile-based masking
if maskPercentile < 100
    threshold = prctile(normMag, 100 - maskPercentile);
    mask = mask & (normMag >= threshold);
end

% Absolute minimum threshold (relative to normalized max=1.0)
if minMagnitude > 0
    mask = mask & (normMag >= minMagnitude);
end

% Zero out masked vectors
maskedVectors = scaledVectors;
maskedVectors(~mask, :) = 0;

% ----------------------------
% Build output
% ----------------------------
result = struct();
result.vectors = maskedVectors;
result.magnitude = mag;
result.normalizedMag = scaledMag;
result.mask = mask;
result.maxOriginal = maxMag;
result.targetLength = targetLength;
result.scaleFactor = scaleFactor;
result.numKept = sum(mask);
result.numTotal = numel(mask);
result.percentKept = 100 * sum(mask) / numel(mask);

end
