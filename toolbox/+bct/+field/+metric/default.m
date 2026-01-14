function metric = default()
%DEFAULT Return canonical default metric record for new fields
%
% Syntax:
%   metric = bct.field.metric.default()
%
% Outputs:
%   metric - Default metric structure with unset status
%
% Description:
%   Returns a canonical default metric record for fields where units
%   are not yet specified. The default metric has:
%   - status: "unset"
%   - dimensionless (unit="1", siUnit="1")
%   - zero base dimensions
%   - identity conversion (scale=1, offset=0)
%
% Examples:
%   metric = bct.field.metric.default()
%
% See also: bct.field.metric.validate, bct.field.metric.declare

metric = struct( ...
    'quantity',   "unknown", ...
    'unit',       "1", ...
    'siUnit',     "1", ...
    'dim',        struct('L',0, 'M',0, 'T',0, 'I',0, 'Theta',0), ...
    'scaleToSI',  1.0, ...
    'offsetToSI', 0.0, ...
    'status',     "unset", ...
    'version',    1);

end
