function mustHaveSize(value, expectedSize)
%MUSTHAVESIZE Validate that value has expected size
%
% Syntax:
%   bct.manifold.schema.rules.mustHaveSize(value, expectedSize)
%
% Inputs:
%   value        - Value to validate
%   expectedSize - Expected size vector, use NaN for any dimension
%
% Examples:
%   % Validate [N×3] matrix (any N, exactly 3 columns)
%   bct.manifold.schema.rules.mustHaveSize(V, [NaN, 3]);
%
%   % Validate exact size [100×3]
%   bct.manifold.schema.rules.mustHaveSize(F, [100, 3]);

arguments
    value
    expectedSize (1,:) {mustBeNumeric}
end

actualSize = size(value);

% Pad shorter dimension if needed
if numel(actualSize) < numel(expectedSize)
    actualSize = [actualSize, ones(1, numel(expectedSize) - numel(actualSize))];
elseif numel(expectedSize) < numel(actualSize)
    expectedSize = [expectedSize, ones(1, numel(actualSize) - numel(expectedSize))];
end

% Check each dimension (skip NaN = any)
for i = 1:numel(expectedSize)
    if ~isnan(expectedSize(i)) && actualSize(i) ~= expectedSize(i)
        error('bct:schema:WrongSize', ...
            'Expected size [%s], got [%s] (dimension %d mismatch).', ...
            num2str(expectedSize), num2str(actualSize), i);
    end
end

end
