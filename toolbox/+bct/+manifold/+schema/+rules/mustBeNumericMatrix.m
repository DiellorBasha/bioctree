function mustBeNumericMatrix(value, nRows, nCols)
%MUSTBENUMERICMATRIX Validate that value is a numeric matrix with expected dimensions
%
% Syntax:
%   bct.manifold.schema.rules.mustBeNumericMatrix(value, nRows, nCols)
%
% Inputs:
%   value - Value to validate
%   nRows - Expected number of rows ('any' or positive integer)
%   nCols - Expected number of columns (positive integer)
%
% Throws:
%   Error if value is not numeric, not 2D, or has wrong dimensions
%
% Examples:
%   % Validate 3-column matrix
%   bct.manifold.schema.rules.mustBeNumericMatrix(V, 'any', 3);
%
%   % Validate exact size
%   bct.manifold.schema.rules.mustBeNumericMatrix(F, 100, 3);

arguments
    value
    nRows = 'any'
    nCols (1,1) {mustBePositive} = []
end

% Check numeric
if ~isnumeric(value)
    error('bct:schema:NotNumeric', 'Value must be numeric, got %s.', class(value));
end

% Check 2D
if ndims(value) ~= 2 %#ok<ISMAT>
    error('bct:schema:NotMatrix', 'Value must be 2D matrix, got %dD array.', ndims(value));
end

% Check rows
actualRows = size(value, 1);
if ~strcmp(nRows, 'any') && actualRows ~= nRows
    error('bct:schema:WrongRows', 'Expected %d rows, got %d.', nRows, actualRows);
end

% Check columns
if ~isempty(nCols)
    actualCols = size(value, 2);
    if actualCols ~= nCols
        error('bct:schema:WrongColumns', 'Expected %d columns, got %d.', nCols, actualCols);
    end
end

end
