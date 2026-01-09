function out = frame(M)
%FRAME Compute and cache orthonormal frames [DEPRECATED - Use bct.geometry.frame]
%
% Syntax:
%   fr = bct.manifold.frame(M)
%
% DEPRECATED: This function has been moved to bct.geometry.frame
%             Please update your code to use: bct.geometry.frame(M)
%
% Inputs:
%   M - bct.Manifold object
%
% Outputs:
%   fr - Struct containing:
%        .Face   - struct('N', Nf, 'T1', T1f, 'T2', T2f)
%                  Nf:  [Nf×3] face normals (unit)
%                  T1f: [Nf×3] first face tangent (unit)
%                  T2f: [Nf×3] second face tangent (unit)
%        .Vertex - struct('N', Nv, 'T1', T1v, 'T2', T2v)
%                  Nv:  [Nv×3] vertex normals (unit)
%                  T1v: [Nv×3] first vertex tangent (unit)
%                  T2v: [Nv×3] second vertex tangent (unit)
%        .Meta   - struct('Hash', hash, 'CreatedOn', timestamp)
%
% See also: bct.geometry.frame, bct.geometry.normals, bct.geometry.tangents

warning('bct:manifold:frame:deprecated', ...
    ['bct.manifold.frame is deprecated and will be removed in a future release.\n', ...
     'Use bct.geometry.frame instead.']);

% Validate input
if ~isa(M, 'bct.Manifold')
    error('bct:manifold:frame:InvalidInput', ...
        'Input must be a bct.Manifold object');
end

% Delegate to bct.geometry.frame
out = bct.geometry.frame(M);
end

% Compute geometry hash for cache validation
V = M.Vertices;
F = M.Faces;
numVerts = size(V, 1);
numFaces = size(F, 1);
bbox = [min(V, [], 1); max(V, [], 1)];  % [2×3]
currentHash = [numVerts, numFaces, bbox(:)'];       % [1×8] vector

% Check cache validity
needsCompute = true;
geomCache = M.getGeometry();
if isfield(geomCache, 'Frame') && ~isempty(geomCache.Frame)
    if isfield(geomCache.Frame, 'Meta') && isfield(geomCache.Frame.Meta, 'Hash')
        cachedHash = geomCache.Frame.Meta.Hash;
        if isequal(cachedHash, currentHash)
            needsCompute = false;
            out = geomCache.Frame;
        end
    end
end

% Compute frames if cache invalid or missing
if needsCompute
    % Create surfaceMesh and compute normals
    mesh = surfaceMesh(V, F);
    computeNormals(mesh, "face");
    computeNormals(mesh, "vertex");
    
    Nf = mesh.FaceNormals;      % [Nf×3], unit
    Nv = mesh.VertexNormals;    % [Nv×3], unit
    
    % Compute face tangents
    T1f = V(F(:,2),:) - V(F(:,1),:);              % First edge
    T1f = T1f - sum(T1f .* Nf, 2) .* Nf;          % Project to tangent plane
    T1f = normalizeRows(T1f);
    
    T2f = cross(Nf, T1f, 2);
    T2f = normalizeRows(T2f);
    
    % Compute vertex tangents
    numVertNormals = size(Nv, 1);
    ref = repmat([1 0 0], numVertNormals, 1);     % X-axis reference
    parallel = abs(sum(ref .* Nv, 2)) > 0.9;      % Too aligned with X
    ref(parallel,:) = repmat([0 1 0], sum(parallel), 1);  % Use Y-axis
    
    T1v = ref - sum(ref .* Nv, 2) .* Nv;          % Project to tangent plane
    T1v = normalizeRows(T1v);
    
    T2v = cross(Nv, T1v, 2);
    T2v = normalizeRows(T2v);
    
    % Build output structure
    out = struct(...
        'Face',   struct('N', Nf,  'T1', T1f, 'T2', T2f), ...
        'Vertex', struct('N', Nv,  'T1', T1v, 'T2', T2v), ...
        'Meta',   struct('Hash', currentHash, 'CreatedOn', datetime("now")) ...
    );
    
    % Store in cache
    geomCache = M.getGeometry();
    geomCache.Frame = out;
    M.setGeometry(geomCache);
end

end

% ===== Helper: normalize each row safely =====
function X = normalizeRows(X)
    n = vecnorm(X, 2, 2);
    bad = (n < eps) | isnan(n);
    n(bad) = 1;          % Prevent divide-by-zero
    X = X ./ n;
    X(bad,:) = 0;        % Zero-out degenerate results
end
