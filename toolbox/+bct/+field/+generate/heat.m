function F = heat(M, vertexIdx, tau, varargin)
%HEAT Create heat kernel diffused field from point source at vertex
%
% Syntax:
%   F = bct.field.generate.heat(M, vertexIdx, tau)
%   F = bct.field.generate.heat(M, vertexIdx, tau, 'Normalize', true)
%
% Inputs:
%   M         - bct.Manifold object (must have eigenmodes computed)
%   vertexIdx - Vertex index for heat source
%   tau       - Heat kernel time parameter (controls diffusion width)
%
% Optional Parameters:
%   'Normalize' - Normalize output to [0,1] (default: true)
%
% Outputs:
%   F - Field struct with vertex support, scalar values
%
% Description:
%   Creates a heat kernel field centered at vertexIdx using the
%   Manifold's spectral representation. Simply wraps M.localize()
%   with a heat filter.
%   
%   The tau parameter controls diffusion distance:
%   - Small tau (1-10) → localized near source
%   - Medium tau (10-100) → moderate spread
%   - Large tau (100-1000) → global smooth field
%
% Examples:
%   M = bct.manifold.load();
%   M.eigenmodes(100);  % Pre-compute eigenmodes
%   F = bct.field.generate.heat(M, 1000, 10);
%
% See also: bct.Manifold.localize, bct.filter.design

p = inputParser();
p.addParameter('Normalize', true, @islogical);
p.parse(varargin{:});

normalize = p.Results.Normalize;

% Get eigenvalues from Manifold cache
eigenvalues = M.eigenvalues();

% Design heat filter with specified tau
filterSpec = bct.filter.design(eigenvalues, "Heat", "tau", tau);

% Localize filter at specified vertex
heat_values = M.localize(filterSpec, vertexIdx);

% Normalize if requested
if normalize
    heat_values = heat_values - min(heat_values);
    if max(heat_values) > 0
        heat_values = heat_values / max(heat_values);
    end
end

% Build field struct
F = struct();
F.schemaVersion = 'bct.field@1';
F.meshId = char(M.ID);
F.support = 'vertex';
F.valueType = 'scalar';
F.value = heat_values;
F.meta = struct(...
    'generator', 'heat', ...
    'vertexIdx', vertexIdx, ...
    'tau', tau, ...
    'numModes', numel(eigenvalues), ...
    'normalized', normalize);

end
