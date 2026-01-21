function indices = normalizeIndexArray(indices, fieldName)
%NORMALIZEINDEXARRAY Normalize index array to uint32
%
% Converts index arrays (Faces, Edges) to canonical uint32 type.
% Ensures integer values and validates range for uint32 storage.
%
% Syntax:
%   indices = bct.manifold.schema.rules.normalizeIndexArray(indices, fieldName)
%
% Inputs:
%   indices   - Index array (any numeric type)
%   fieldName - Name of field (for error messages)
%
% Outputs:
%   indices - Index array as uint32
%
% Validation:
%   - Values must be integer-valued
%   - Values must be positive (1-based indexing)
%   - Values must fit in uint32 range [1, 4294967295]
%
% Examples:
%   % Normalize faces from double to uint32
%   F = double([1 2 3; 4 5 6]);
%   F_normalized = bct.manifold.schema.rules.normalizeIndexArray(F, 'Faces');
%   class(F_normalized)  % 'uint32'
%
% See also: bct.manifold.schema.normalize

arguments
    indices
    fieldName (1,1) string = "indices"
end

% Validate input is numeric
if ~isnumeric(indices)
    error('bct:schema:InvalidIndexType', ...
        '%s must be numeric, got %s.', fieldName, class(indices));
end

% Check for empty array (valid, but return early)
if isempty(indices)
    indices = uint32(indices);
    return;
end

% Validate integer-valued
if ~all(indices(:) == round(indices(:)))
    error('bct:schema:NonIntegerIndices', ...
        '%s must contain integer values.', fieldName);
end

% Validate positive (1-based indexing in MATLAB)
if any(indices(:) < 1)
    minVal = min(indices(:));
    error('bct:schema:InvalidIndexRange', ...
        '%s must contain positive indices (1-based). Minimum value: %d', ...
        fieldName, minVal);
end

% Validate range fits in uint32 (max: 4,294,967,295)
maxVal = max(indices(:));
if maxVal > double(intmax('uint32'))
    error('bct:schema:IndexOverflow', ...
        '%s contains values exceeding uint32 range (max: %d). Maximum value: %d', ...
        fieldName, intmax('uint32'), maxVal);
end

% Convert to uint32
indices = uint32(indices);

end
