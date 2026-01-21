function mustBeInRange(value, minVal, maxVal)
%MUSTBEINRANGE Validate that all values are within specified range
%
% Syntax:
%   bct.manifold.schema.rules.mustBeInRange(value, minVal, maxVal)
%
% Inputs:
%   value  - Numeric array to validate
%   minVal - Minimum allowed value (inclusive)
%   maxVal - Maximum allowed value (inclusive)
%
% Examples:
%   % Validate indices in range [1, 10000]
%   bct.manifold.schema.rules.mustBeInRange(F, 1, 10000);
%
%   % Validate normalized coordinates [-1, 1]
%   bct.manifold.schema.rules.mustBeInRange(coords, -1, 1);

arguments
    value {mustBeNumeric}
    minVal (1,1) {mustBeNumeric}
    maxVal (1,1) {mustBeNumeric}
end

% Validate min <= max
if minVal > maxVal
    error('bct:schema:InvalidRange', ...
        'Invalid range: minVal (%g) > maxVal (%g).', minVal, maxVal);
end

% Check range
if any(value(:) < minVal) || any(value(:) > maxVal)
    actualMin = min(value(:));
    actualMax = max(value(:));
    error('bct:schema:OutOfRange', ...
        'Values must be in range [%g, %g]. Got range [%g, %g].', ...
        minVal, maxVal, actualMin, actualMax);
end

end
