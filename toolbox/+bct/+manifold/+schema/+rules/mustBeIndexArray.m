function mustBeIndexArray(value, indexBase)
%MUSTBEINDEXARRAY Validate that value is a valid index array
%
% Checks:
%   - Value is numeric
%   - Contains integer values
%   - Values >= indexBase (1 for MATLAB, 0 for export)
%
% Syntax:
%   bct.manifold.schema.rules.mustBeIndexArray(value, indexBase)
%
% Inputs:
%   value     - Array to validate
%   indexBase - Expected index base (0 or 1)
%
% Examples:
%   % Validate 1-based indices (MATLAB convention)
%   bct.manifold.schema.rules.mustBeIndexArray(F, 1);
%
%   % Validate 0-based indices (export convention)
%   bct.manifold.schema.rules.mustBeIndexArray(F_export, 0);

arguments
    value
    indexBase (1,1) {mustBeMember(indexBase, [0, 1])} = 1
end

% Check numeric
if ~isnumeric(value)
    error('bct:schema:NotNumeric', 'Index array must be numeric, got %s.', class(value));
end

% Check empty (valid)
if isempty(value)
    return;
end

% Check integer-valued
if ~all(value(:) == round(value(:)))
    error('bct:schema:NonInteger', 'Index array must contain integer values.');
end

% Check >= indexBase
if any(value(:) < indexBase)
    minVal = min(value(:));
    error('bct:schema:InvalidIndexBase', ...
        'Index array values must be >= %d (%d-based). Minimum value: %d', ...
        indexBase, indexBase, minVal);
end

end
