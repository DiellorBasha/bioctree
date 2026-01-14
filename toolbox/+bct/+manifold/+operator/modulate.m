function modulatedSignal = modulate(meshInput, signal, eigenmodeSpec, varargin)
%MODULATE Modulate a vertex signal by an eigenmode
%
% Syntax:
%   modulatedSignal = bct.manifold.operator.modulate(M, signal, k)
%   modulatedSignal = bct.manifold.operator.modulate(M, signal, eigenvector)
%   modulatedSignal = bct.manifold.operator.modulate(V, F, signal, k)
%   modulatedSignal = bct.manifold.operator.modulate(V, F, signal, eigenvector)
%   modulatedSignal = bct.manifold.operator.modulate(___, Name, Value)
%
% Inputs:
%   M           - bct.Manifold object
%   OR
%   V           - [Nv×3] vertex coordinates
%   F           - [Nf×3] face connectivity (1-indexed)
%
%   signal      - [N×T] vertex-domain signal
%                 N = number of vertices, T = time samples (default 1)
%   eigenmodeSpec - Eigenmode specification:
%                   - Scalar integer k: eigenmode index (1-based)
%                   - [N×1] vector: explicit eigenvector
%
% Name-Value Arguments:
%   NormalizationScale - Scalar (default: sqrt(N))
%                        Scaling factor applied to modulation
%   Strict             - logical (default true), enforce validation
%
% Outputs:
%   modulatedSignal - [N×T] modulated signal
%
% Description:
%   Modulates a vertex-domain signal by multiplying with an eigenmode,
%   implementing generalized modulation on manifolds:
%
%     modulatedSignal = normalizationScale * signal .* eigenmodeVector
%
%   Where:
%   - signal is the input signal at each vertex
%   - eigenmodeVector is an eigenfunction of the Laplace-Beltrami operator
%   - normalizationScale is typically sqrt(N) for consistency with spectral theory
%
%   This operation shifts the signal's spectral content in frequency space,
%   analogous to amplitude modulation in classical signal processing but
%   adapted to the manifold's intrinsic geometry via the eigenmodes.
%
% Interpretation:
%   Modulation by eigenmode k translates spectral components:
%   - Couples the signal with the spatial oscillation pattern of mode k
%   - In spectral domain, convolution with a shifted delta function
%   - Enables analysis of signal content at different spectral frequencies
%
% Use Cases:
%   - Frequency translation on manifolds
%   - Analyzing signal content at specific spectral scales
%   - Creating test signals with known spectral properties
%   - Implementing spectral multiplexing
%   - Windowing operations in spectral domain
%
% Examples:
%   % Modulate signal by 10th eigenmode (from Manifold)
%   M = bct.manifold.load();
%   signal = randn(M.nVertices, 1);
%   E = M.eigenmodes(50);
%   modulated = bct.manifold.operator.modulate(M, signal, 10);
%
%   % Modulate using explicit eigenvector
%   E = M.eigenmodes(50);
%   eigenvector = E.vectors(:, 10);
%   modulated = bct.manifold.operator.modulate(M, signal, eigenvector);
%
%   % Modulate multiple time samples
%   signals = randn(M.nVertices, 100);  % 100 time points
%   modulated = bct.manifold.operator.modulate(M, signals, 15);
%   % size(modulated) = [N, 100]
%
%   % Using V, F input
%   [V, F] = bct.manifold.load('fsaverage_lh_white');
%   E = bct.graph.eigensolve(V, F, 50);
%   signal = randn(size(V, 1), 1);
%   modulated = bct.manifold.operator.modulate(V, F, signal, 10);
%
%   % Custom normalization
%   modulated = bct.manifold.operator.modulate(M, signal, 10, ...
%       'NormalizationScale', 1.0);  % No sqrt(N) scaling
%
%   % Visualize modulation effect
%   M = bct.manifold.load();
%   signal = ones(M.nVertices, 1);  % Constant signal
%   modulated = bct.manifold.operator.modulate(M, signal, 20);
%   V = bct.ui.manifold.Viewer(M);
%   V.show(modulated);  % Shows 20th eigenmode pattern
%
% See also: bct.manifold.operator.localize, bct.manifold.eigenmodes,
%           bct.graph.eigensolve, bct.filter.analysis

% ----------------------------
% Parse inputs
% ----------------------------
p = inputParser;
p.FunctionName = 'bct.manifold.operator.modulate';

if isa(meshInput, 'bct.Manifold')
    % Case: modulate(M, signal, eigenmodeSpec, Name=Value...)
    addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));
    addRequired(p, 'signal', @isnumeric);
    addRequired(p, 'eigenmodeSpec');  % Can be scalar or vector
    parse(p, meshInput, signal, eigenmodeSpec);
    
    M = meshInput;
    useManifold = true;
    nameValueStart = 1;
    
elseif isnumeric(meshInput) && nargin >= 4 && isnumeric(varargin{1})
    % Case: modulate(V, F, signal, eigenmodeSpec, Name=Value...)
    addRequired(p, 'V', @isnumeric);
    addRequired(p, 'F', @isnumeric);
    addRequired(p, 'signal', @isnumeric);
    addRequired(p, 'eigenmodeSpec');  % Can be scalar or vector
    
    V = meshInput;
    F_faces = signal;
    signal = eigenmodeSpec;
    eigenmodeSpec = varargin{1};
    
    parse(p, V, F_faces, signal, eigenmodeSpec);
    
    % Validate V, F
    if size(V, 2) ~= 3
        error('bct:manifold:operator:modulate:InvalidVertices', ...
            'V must be an [N×3] numeric array.');
    end
    if size(F_faces, 2) ~= 3
        error('bct:manifold:operator:modulate:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    
    M = [];
    useManifold = false;
    nameValueStart = 2;
    
else
    error('bct:manifold:operator:modulate:InvalidInput', ...
        'Expected modulate(M, signal, eigenmodeSpec) or modulate(V, F, signal, eigenmodeSpec)');
end

% Parse optional arguments
addParameter(p, 'NormalizationScale', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'Strict', true, @islogical);
parse(p, meshInput, signal, eigenmodeSpec, varargin{nameValueStart:end});

normScale = p.Results.NormalizationScale;
strict = p.Results.Strict;

% ----------------------------
% Validate signal dimensions
% ----------------------------
if isvector(signal)
    signal = signal(:);  % Ensure column vector [N×1]
end
[N, T] = size(signal);

if useManifold
    nVertices = M.nVertices;
else
    nVertices = size(V, 1);
end

if N ~= nVertices
    error('bct:manifold:operator:modulate:SignalSizeMismatch', ...
        'Signal has %d vertices but mesh has %d vertices', N, nVertices);
end

% ----------------------------
% Get eigenmode vector
% ----------------------------
if isscalar(eigenmodeSpec)
    % eigenmodeSpec is an index k
    k = eigenmodeSpec;
    
    if k < 1 || k ~= round(k)
        error('bct:manifold:operator:modulate:InvalidIndex', ...
            'Eigenmode index must be a positive integer, got %g', k);
    end
    
    % Retrieve eigenvector
    if useManifold
        E = M.eigenmodes(k);  % Get at least k eigenmodes
        if k > size(E.vectors, 2)
            error('bct:manifold:operator:modulate:InsufficientModes', ...
                'Requested eigenmode %d but only %d modes available', k, size(E.vectors, 2));
        end
        eigenvector = E.vectors(:, k);
    else
        % Compute eigenmodes from V, F
        E = bct.graph.eigensolve(V, F_faces, k);
        if k > size(E.vectors, 2)
            error('bct:manifold:operator:modulate:InsufficientModes', ...
                'Requested eigenmode %d but only %d modes computed', k, size(E.vectors, 2));
        end
        eigenvector = E.vectors(:, k);
    end
    
elseif isvector(eigenmodeSpec)
    % eigenmodeSpec is an explicit eigenvector
    eigenvector = eigenmodeSpec(:);  % Ensure column vector
    
    if length(eigenvector) ~= nVertices
        error('bct:manifold:operator:modulate:EigenvectorSizeMismatch', ...
            'Eigenvector has %d elements but mesh has %d vertices', ...
            length(eigenvector), nVertices);
    end
    
else
    error('bct:manifold:operator:modulate:InvalidEigenmodeSpec', ...
        'eigenmodeSpec must be a scalar index or [N×1] eigenvector');
end

% Validate eigenvector (Strict mode)
if strict
    if ~isreal(eigenvector)
        error('bct:manifold:operator:modulate:ComplexEigenvector', ...
            'Eigenvector must be real-valued');
    end
    if any(~isfinite(eigenvector))
        error('bct:manifold:operator:modulate:InvalidEigenvector', ...
            'Eigenvector contains NaN or Inf values');
    end
end

% ----------------------------
% Set normalization scale
% ----------------------------
if isempty(normScale)
    normScale = sqrt(nVertices);
end

% ----------------------------
% Perform modulation
% ----------------------------
% Broadcasting: [N×1] eigenvector modulates each column of [N×T] signal
modulatedSignal = normScale * signal .* eigenvector;

end
