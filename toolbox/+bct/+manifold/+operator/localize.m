function localizedField = localize(meshInput, vertexIdx, filterSpec, varargin)
%LOCALIZE Localize a spectral filter to a specific vertex
%
% Syntax:
%   localizedField = bct.manifold.operator.localize(M, vertexIdx, F)
%   localizedField = bct.manifold.operator.localize(V, F, vertexIdx, F)
%   localizedField = bct.manifold.operator.localize(___, Name, Value)
%
% Inputs:
%   M           - bct.Manifold object
%   OR
%   V           - [Nv×3] vertex coordinates
%   F           - [Nf×3] face connectivity (1-indexed)
%
%   vertexIdx   - Scalar integer, 1-based vertex index for localization
%   filterSpec  - Filter struct from bct.filter.design
%                 Can be single filter (J=1) or filterbank (J>1)
%
% Name-Value Arguments:
%   OutputFormat - "stack" (default) | "cell"
%                  "stack": return [N×J] array (or [N×1] if J=1)
%                  "cell":  return {1×J} cell array, each [N×1]
%   Strict       - logical (default true), enforce validation
%
% Outputs:
%   localizedField - Localized filter response(s)
%                    If OutputFormat="stack": [N×J] (or [N×1] if J=1)
%                    If OutputFormat="cell":  {1×J} cell, each [N×1]
%
% Description:
%   Localizes a spectral filter or filterbank to a specific vertex by:
%   1. Creating a Dirac delta function at vertexIdx using bct.manifold.query.delta
%   2. Applying spectral filtering via bct.filter.analysis
%   3. Returning the filtered field(s)
%
%   This operation computes:
%     localizedField = imft * diag(filterWeights) * mft * delta(vertexIdx)
%
%   Where:
%   - delta(vertexIdx) is a unit impulse at the specified vertex
%   - mft is the forward manifold Fourier transform
%   - filterWeights are the spectral filter coefficients
%   - imft is the inverse manifold Fourier transform
%
%   The result shows how the filter "spreads" or "localizes" from the
%   specified vertex across the manifold, respecting the manifold geometry
%   and the filter's spectral characteristics.
%
% Use Cases:
%   - Visualizing filter support/extent on the manifold
%   - Computing Green's functions for filtered operators
%   - Analyzing spatial-spectral properties of filters
%   - Creating localized basis functions (wavelets on manifolds)
%
% Examples:
%   % Localize a heat diffusion kernel to vertex 100
%   M = bct.manifold.load();
%   E = M.eigenmodes(100);
%   F = bct.filter.design(E.values, "Heat", "tau", 10);
%   localField = bct.manifold.operator.localize(M, 100, F);
%   % localField is [N×1], shows heat diffusion from vertex 100
%
%   % Localize a filterbank (multiple scales)
%   taus = [1, 5, 10, 20];
%   F = bct.filter.design(E.values, "Heat", "tau", taus);
%   localFields = bct.manifold.operator.localize(M, 100, F);
%   % localFields is [N×4], each column is a different scale
%
%   % Visualize localization
%   M = bct.manifold.load();
%   E = M.eigenmodes(100);
%   F = bct.filter.design(E.values, "Heat", "tau", 15);
%   localField = bct.manifold.operator.localize(M, 500, F);
%   V = bct.ui.manifold.Viewer(M);
%   V.show(localField);
%
%   % Using V, F input
%   [V, F] = bct.manifold.load('fsaverage_lh_white');
%   E = bct.graph.eigensolve(V, F, 100);
%   filter = bct.filter.design(E.values, "Gaussian", "mu", 0.1, "sigma", 0.05);
%   localField = bct.manifold.operator.localize(V, F, 250, filter);
%
% See also: bct.manifold.query.delta, bct.filter.analysis, bct.filter.design,
%           bct.manifold.operator.mft, bct.manifold.operator.imft

% ----------------------------
% Parse inputs
% ----------------------------
p = inputParser;
p.FunctionName = 'bct.manifold.operator.localize';

if isa(meshInput, 'bct.Manifold')
    % Case: localize(M, vertexIdx, filterSpec, Name=Value...)
    addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));
    addRequired(p, 'vertexIdx', @(x) isnumeric(x) && isscalar(x) && x >= 1 && x == round(x));
    addRequired(p, 'filterSpec', @isstruct);
    parse(p, meshInput, vertexIdx, filterSpec);
    
    M = meshInput;
    useManifold = true;
    nameValueStart = 1;
    
elseif isnumeric(meshInput) && nargin >= 4 && isnumeric(varargin{1})
    % Case: localize(V, F, vertexIdx, filterSpec, Name=Value...)
    addRequired(p, 'V', @isnumeric);
    addRequired(p, 'F', @isnumeric);
    addRequired(p, 'vertexIdx', @(x) isnumeric(x) && isscalar(x) && x >= 1 && x == round(x));
    addRequired(p, 'filterSpec', @isstruct);
    
    V = meshInput;
    F_faces = vertexIdx;
    vertexIdx = filterSpec;
    filterSpec = varargin{1};
    
    parse(p, V, F_faces, vertexIdx, filterSpec);
    
    % Validate V, F
    if size(V, 2) ~= 3
        error('bct:manifold:operator:localize:InvalidVertices', ...
            'V must be an [N×3] numeric array.');
    end
    if size(F_faces, 2) ~= 3
        error('bct:manifold:operator:localize:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    
    M = [];
    useManifold = false;
    nameValueStart = 2;
    
else
    error('bct:manifold:operator:localize:InvalidInput', ...
        'Expected localize(M, vertexIdx, filterSpec) or localize(V, F, vertexIdx, filterSpec)');
end

% Parse optional arguments
addParameter(p, 'OutputFormat', "stack", @(x) ismember(string(x), ["stack", "cell"]));
addParameter(p, 'Strict', true, @islogical);
parse(p, meshInput, vertexIdx, filterSpec, varargin{nameValueStart:end});

outputFormat = string(p.Results.OutputFormat);
strict = p.Results.Strict;

% ----------------------------
% Validate inputs
% ----------------------------
if useManifold
    nVertices = M.numVertices();
else
    nVertices = size(V, 1);
end

if vertexIdx > nVertices
    error('bct:manifold:operator:localize:InvalidIndex', ...
        'vertexIdx (%d) exceeds number of vertices (%d)', vertexIdx, nVertices);
end

% Validate filter struct
if ~isfield(filterSpec, 'weights')
    error('bct:manifold:operator:localize:InvalidFilter', ...
        'filterSpec must be a valid filter struct from bct.filter.design with .weights field');
end

% ----------------------------
% Create delta function at specified vertex
% ----------------------------
deltaSignal = bct.manifold.query.delta(nVertices, vertexIdx);
% deltaSignal is [N×1] sparse vector with 1 at vertexIdx, 0 elsewhere

% ----------------------------
% Get transform operators
% ----------------------------
if useManifold
    % Get MFT and IMFT operators from Manifold (uses cached eigenmodes)
    [~, mftOp] = bct.manifold.operator.mft(M);
    [~, imftOp] = bct.manifold.operator.imft(M);
else
    % Compute MFT and IMFT from V, F
    % Need eigenmodes and mass matrix
    k = size(filterSpec.weights, 1);  % Number of spectral modes
    
    % Get eigenmodes
    E = bct.graph.eigensolve(V, F_faces, k);
    
    % Get mass matrix
    [~, Mass] = bct.manifold.operator.mass(V, F_faces);
    
    % Construct transform operators
    [~, mftOp] = bct.manifold.operator.mft(E.vectors, Mass);
    [~, imftOp] = bct.manifold.operator.imft(E.vectors, Mass);
end

% ----------------------------
% Apply spectral filtering
% ----------------------------
localizedField = bct.filter.analysis(mftOp, imftOp, deltaSignal, filterSpec, ...
    'OutputFormat', outputFormat, ...
    'Strict', strict);

% Note: bct.filter.analysis already handles:
% 1. Forward transform: spectrum = mft * deltaSignal
% 2. Filter application: filteredSpectrum = filterWeights .* spectrum
% 3. Inverse transform: localizedField = imft * filteredSpectrum

end
