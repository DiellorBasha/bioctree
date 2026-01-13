function M = rescale(M, options)
%RESCALE Rescale manifold vertices from a source unit to SI meters
%
% Syntax:
%   M = bct.manifold.metric.rescale(M, 'From', fromUnit)
%   M = bct.manifold.metric.rescale(M, 'From', fromUnit, 'Force', true)
%
% Inputs:
%   M - bct.Manifold object
%
% Name-Value Arguments:
%   From  - Source unit (required): "m" | "cm" | "mm" | "um" | "nm"
%   Force - Allow rescaling even if already applied (default: false)
%
% Outputs:
%   M - Manifold with rescaled vertices in SI meters
%
% Description:
%   Rescales manifold vertex coordinates from a known decimal length unit
%   to SI meters. All bct.Manifold objects are interpreted as meters, so
%   if input data was in mm, cm, etc., use this function to correct.
%
%   Conversion factors:
%   - "m"  → 1 (identity)
%   - "cm" → 1e-2
%   - "mm" → 1e-3
%   - "um" → 1e-6
%   - "nm" → 1e-9
%
%   Guardrails:
%   - Prevents double-rescaling unless Force=true
%   - Invalidates all metric-dependent caches (geometry, operators, spectral)
%   - Records rescaling provenance in M.Metric
%
% Examples:
%   % Data originally in millimeters
%   M = bct.Manifold(V_mm, F);
%   M = bct.manifold.metric.rescale(M, 'From', 'mm');
%
%   % Force re-rescaling (use with caution)
%   M = bct.manifold.metric.rescale(M, 'From', 'cm', 'Force', true);
%
% See also: bct.manifold.metric.validateUnit, bct.manifold.metric.info

arguments
    M (1,1) bct.Manifold
    options.From (1,1) string
    options.Force (1,1) logical = false
end

% Validate source unit
bct.manifold.metric.validateUnit(options.From);

% Define conversion factors to meters
unitToMeters = containers.Map( ...
    {'m', 'cm', 'mm', 'um', 'nm'}, ...
    {1, 1e-2, 1e-3, 1e-6, 1e-9} ...
);

factor = unitToMeters(char(options.From));

% Guardrail: prevent double-rescaling
if M.Metric.rescale.applied && ~options.Force
    error('bct:manifold:metric:DoubleRescale', ...
        ['Rescaling has already been applied (from "%s" with factor %.2e). ' ...
         'This likely indicates an attempt to rescale twice, which would corrupt the geometry. ' ...
         'If you are certain you want to rescale again, use ''Force'', true.'], ...
        M.Metric.rescale.fromUnit, M.Metric.rescale.factor);
end

% Apply scaling to vertices
M.Vertices = M.Vertices * factor;

% Update metric record
M.Metric.unit = "m";
M.Metric.rescale.applied = true;
M.Metric.rescale.fromUnit = options.From;
M.Metric.rescale.factor = factor;
M.Metric.rescale.timestamp = string(datetime('now'));

% Invalidate all metric-dependent caches
M = M.invalidateMetricDependentCaches();

end
