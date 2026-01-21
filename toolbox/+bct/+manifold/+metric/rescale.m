function M = rescale(M, options)
%RESCALE Rescale manifold vertices from a source unit to SI meters
%
% Syntax:
%   M = bct.manifold.metric.rescale(M, 'From', fromUnit)
%   M = bct.manifold.metric.rescale(M, 'From', fromUnit, 'Force', true)
%   M = bct.manifold.metric.rescale(M, 'Factor', scaleFactor)
%
% Inputs:
%   M - bct.Manifold object
%
% Name-Value Arguments:
%   From   - Source unit: "m" | "cm" | "mm" | "um" | "nm"
%   Factor - Direct scaling factor (alternative to 'From')
%   Force  - Allow rescaling even if already applied (default: false)
%
% Outputs:
%   M - New Manifold with rescaled vertices
%
% Description:
%   Rescales manifold vertex coordinates from a known decimal length unit
%   to SI meters, or by a direct scaling factor.
%
%   Conversion factors:
%   - "m"  → 1 (identity)
%   - "cm" → 1e-2
%   - "mm" → 1e-3
%   - "um" → 1e-6
%   - "nm" → 1e-9
%
%   Alternatively, use 'Factor' for direct scaling (uses surfaceMesh.scale).
%
%   Guardrails:
%   - Prevents double-rescaling unless Force=true
%   - Returns new Manifold (original unchanged)
%
% Examples:
%   % Data originally in millimeters
%   M = bct.Manifold(V_mm, F);
%   M = bct.manifold.metric.rescale(M, 'From', 'mm');
%
%   % Direct scaling factor
%   M = bct.manifold.metric.rescale(M, 'Factor', 0.001);
%
%   % Force re-rescaling (use with caution)
%   M = bct.manifold.metric.rescale(M, 'From', 'cm', 'Force', true);
%
% See also: bct.manifold.metric.validateUnit, surfaceMesh.scale

arguments
    M (1,1) bct.Manifold
    options.From (1,1) string = ""
    options.Factor (1,1) double = NaN
    options.Force (1,1) logical = false
end

% Determine scaling factor
if ~isnan(options.Factor)
    % Direct factor provided - use surfaceMesh.scale() method
    factor = options.Factor;
    
elseif options.From ~= ""
    % Unit conversion
    bct.manifold.metric.validateUnit(options.From);
    
    % Define conversion factors to meters
    unitToMeters = containers.Map( ...
        {'m', 'cm', 'mm', 'um', 'nm'}, ...
        {1, 1e-2, 1e-3, 1e-6, 1e-9} ...
    );
    
    factor = unitToMeters(char(options.From));
else
    error('bct:manifold:metric:NoScalingSpecified', ...
        'Must specify either ''From'' (unit) or ''Factor'' (scaling factor)');
end

% Guardrail: prevent double-rescaling
if M.Header.Metric.rescale.applied && ~options.Force
    error('bct:manifold:metric:DoubleRescale', ...
        ['Rescaling has already been applied (from "%s" with factor %.2e). ' ...
         'This likely indicates an attempt to rescale twice, which would corrupt the geometry. ' ...
         'If you are certain you want to rescale again, use ''Force'', true.'], ...
        M.Header.Metric.rescale.fromUnit, M.Header.Metric.rescale.factor);
end

% Use surfaceMesh.scale() for actual scaling
mesh = surfaceMesh(M.Vertices, M.Faces);
scale(mesh, factor);  % Modifies mesh in-place

% Create new Manifold with scaled vertices
M = bct.Manifold(mesh.Vertices, mesh.Faces);

end
