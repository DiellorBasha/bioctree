function Q = quantity(value, unit, Lexp, meta)
%QUANTITY Create standardized unit-aware quantity structure
%
% Syntax:
%   Q = bct.manifold.metric.quantity(value, unit, Lexp)
%   Q = bct.manifold.metric.quantity(value, unit, Lexp, meta)
%
% Inputs:
%   value - Numeric data (scalar, vector, matrix, sparse)
%   unit  - SI unit label string (e.g., "m", "m^2", "1/m", "1")
%   Lexp  - Length dimension exponent (integer: +2, +1, 0, -1, -2)
%   meta  - Optional metadata struct (default: empty struct)
%
% Outputs:
%   Q - Standardized quantity structure with fields:
%       .value - Numeric data
%       .unit  - SI unit label
%       .dim   - Dimension descriptor (struct with Lexp field)
%       .meta  - Metadata (normalization, method, conventions)
%
% Description:
%   Constructs unit-aware quantity wrappers with enforced schema.
%   All manifold measurements use this standard representation when
%   annotation is enabled. Ensures consistent handling of physical
%   dimensions across geometry, operators, and spectral analysis.
%
% Examples:
%   % Face area measurement
%   Q = bct.manifold.metric.quantity(areas, "m^2", 2);
%   % Q.value = [numeric areas]
%   % Q.unit = "m^2"
%   % Q.dim.Lexp = 2
%
%   % Gradient operator
%   Q = bct.manifold.metric.quantity(D0, "1/m", -1);
%
%   % Dimensionless normals
%   Q = bct.manifold.metric.quantity(N, "1", 0, struct('normalized', true));
%
% See also: bct.manifold.metric.annotate, bct.manifold.metric.spec

arguments
    value
    unit (1,1) string
    Lexp (1,1) {mustBeInteger}
    meta struct = struct()
end

% Validate unit string (basic format check)
if ~ismember(unit, ["m^2", "m", "1", "1/m", "1/m^2"])
    warning('bct:manifold:metric:NonStandardUnit', ...
        'Unit "%s" is not in standard SI format. Expected: m^2, m, 1, 1/m, or 1/m^2', unit);
end

% Construct standardized quantity structure
Q = struct();
Q.value = value;
Q.unit = unit;
Q.dim = struct('Lexp', Lexp);
Q.meta = meta;

end
