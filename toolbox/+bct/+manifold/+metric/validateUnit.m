function validateUnit(unit)
%VALIDATEUNIT Validate that unit is supported
%
% Syntax:
%   bct.manifold.metric.validateUnit(unit)
%
% Inputs:
%   unit - String specifying length unit
%
% Description:
%   Validates that the provided unit is one of the supported decimal
%   length units. Throws an error if the unit is not supported.
%
% Supported Units:
%   "m", "cm", "mm", "um", "nm"
%
% Examples:
%   bct.manifold.metric.validateUnit("mm");  % OK
%   bct.manifold.metric.validateUnit("km");  % Error
%
% See also: bct.manifold.metric.supportedUnits, bct.manifold.metric.rescale

arguments
    unit (1,1) string
end

supported = bct.manifold.metric.supportedUnits();

if ~ismember(unit, supported)
    error('bct:manifold:metric:UnsupportedUnit', ...
        'Unsupported length unit "%s". Supported units are: %s', ...
        unit, strjoin(supported, ", "));
end

end
