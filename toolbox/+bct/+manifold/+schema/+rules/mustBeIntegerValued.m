function mustBeIntegerValued(value)
%MUSTBEINTEGERVALUED Validate that all values are integers
%
% Checks that a numeric array contains only integer values,
% even if stored as floating point type.
%
% Syntax:
%   bct.manifold.schema.rules.mustBeIntegerValued(value)
%
% Inputs:
%   value - Numeric array to validate
%
% Examples:
%   % Valid: integer values as double
%   bct.manifold.schema.rules.mustBeIntegerValued([1.0, 2.0, 3.0]);
%
%   % Invalid: non-integer values
%   % bct.manifold.schema.rules.mustBeIntegerValued([1.5, 2.7]);  % Error

arguments
    value {mustBeNumeric}
end

if ~all(value(:) == round(value(:)))
    error('bct:schema:NonInteger', 'All values must be integer-valued.');
end

end
