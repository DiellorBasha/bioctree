function [N, e1, e2] = tangents(varargin)
%TANGENTS Compute orthonormal tangent frame for each face or vertex
%
% Syntax:
%   [N, e1, e2] = bct.manifold.tangents(M)
%   [N, e1, e2] = bct.manifold.tangents(V, F)
%   [N, e1, e2] = bct.manifold.tangents(___, 'Domain', 'face')    % default
%   [N, e1, e2] = bct.manifold.tangents(___, 'Domain', 'vertex')
%
% Inputs:
%   M - bct.Manifold object
%   V - [Nv×3] vertex coordinates
%   F - [Nf×3] face connectivity (1-indexed)
%
% Name-Value:
%   'Domain' - 'face' (default) or 'vertex'
%
% Outputs:
%   N  - normals:
%        * face domain:   [Nf×3] face normals (unit)
%        * vertex domain: [Nv×3] vertex normals (unit)
%   e1 - first tangent basis vector (same size as N)
%   e2 - second tangent basis vector (same size as N)
%
% Description:
%   Computes an orthonormal coordinate frame {e1, e2, N} for each face or
%   vertex. The frame is right-handed with:
%   - N: face/vertex normal
%   - e1: first tangent basis vector (orthogonal to N)
%   - e2: second tangent basis vector (orthogonal to both N and e1)
%
%   For Manifold objects, uses cached frames from bct.geometry.frame() for
%   efficiency. For V,F inputs, computes frames directly.
%
%   Face tangents are computed per triangle using the first edge (v2-v1).
%   Vertex tangents use a robust reference axis projection method to ensure
%   consistent in-plane directions.
%
% Examples:
%   % Face tangents from Manifold object
%   M = bct.Manifold(V, F);
%   [N, e1, e2] = bct.manifold.tangents(M);
%   [N, e1, e2] = bct.manifold.tangents(M, 'Domain', 'face');
%
%   % Vertex tangents from V, F directly
%   [N, e1, e2] = bct.manifold.tangents(V, F, 'Domain', 'vertex');
%
%   % Visualize face tangent frame at centroids
%   C = bct.manifold.centroids(M);
%   [N, e1, e2] = bct.manifold.tangents(M, 'Domain', 'face');
%   quiver3(C(:,1), C(:,2), C(:,3), e1(:,1), e1(:,2), e1(:,3), 0.5, 'r');
%   hold on;
%   quiver3(C(:,1), C(:,2), C(:,3), e2(:,1), e2(:,2), e2(:,3), 0.5, 'g');
%   quiver3(C(:,1), C(:,2), C(:,3), N(:,1), N(:,2), N(:,3), 0.5, 'b');
%
%   % Visualize vertex tangent frame
%   [N, e1, e2] = bct.manifold.tangents(M, 'Domain', 'vertex');
%   quiver3(V(:,1), V(:,2), V(:,3), e1(:,1), e1(:,2), e1(:,3), 0.5, 'r');
%
% See also: bct.geometry.frame, bct.geometry.normals, bct.geometry.centroids

% -------- Parse args: allow (M, nv) or (V,F,nv) --------
if nargin == 0
    error('bct:manifold:tangents:InvalidNumArgs', ...
        'Expected inputs: (M) or (V,F), optionally with name-value pairs.');
end

% Separate positional from name-values
nvStart = find(cellfun(@(x) ischar(x) || (isstring(x) && isscalar(x)), varargin), 1, 'first');
if isempty(nvStart)
    pos = varargin;
    nv  = {};
else
    pos = varargin(1:nvStart-1);
    nv  = varargin(nvStart:end);
end

p = inputParser;
p.FunctionName = 'bct.manifold.tangents';
addParameter(p, 'Domain', 'face', @(s) any(strcmpi(s, {'face','vertex'})));
parse(p, nv{:});
domain = lower(string(p.Results.Domain));

% -------- Get V,F and frames --------
haveManifold = (numel(pos) == 1) && isa(pos{1}, 'bct.Manifold');
haveVF       = (numel(pos) == 2);

if haveManifold
    % Use cached frames for Manifold objects (efficient)
    M = pos{1};
    fr = bct.geometry.frame(M);
    
    if domain == "face"
        N  = fr.Face.N;
        e1 = fr.Face.T1;
        e2 = fr.Face.T2;
    else
        N  = fr.Vertex.N;
        e1 = fr.Vertex.T1;
        e2 = fr.Vertex.T2;
    end

elseif haveVF
    % For V, F inputs, compute directly
    V = pos{1};
    F = pos{2};

    % Validate inputs
    if ~isnumeric(V) || size(V,2) ~= 3
        error('bct:manifold:tangents:InvalidVertices', ...
            'Vertices must be Nv×3 numeric array.');
    end
    if ~isnumeric(F) || size(F,2) ~= 3
        error('bct:manifold:tangents:InvalidFaces', ...
            'Faces must be Nf×3 numeric array.');
    end

    mesh = surfaceMesh(V, F);

    if domain == "face"
        computeNormals(mesh, "face");
        N = mesh.FaceNormals;      % [Nf×3], unit
        
        % Compute face tangents
        e1 = V(F(:,2),:) - V(F(:,1),:);
        e1 = e1 - sum(e1 .* N, 2) .* N;
        e1 = normalizeRows(e1);
        
        e2 = cross(N, e1, 2);
        e2 = normalizeRows(e2);
        
    else
        computeNormals(mesh, "vertex");
        N = mesh.VertexNormals;    % [Nv×3], unit
        
        % Compute vertex tangents
        nv = size(N,1);
        ref = repmat([1 0 0], nv, 1);
        parallel = abs(sum(ref .* N, 2)) > 0.9;
        ref(parallel,:) = repmat([0 1 0], sum(parallel), 1);
        
        e1 = ref - sum(ref .* N, 2) .* N;
        e1 = normalizeRows(e1);
        
        e2 = cross(N, e1, 2);
        e2 = normalizeRows(e2);
    end

else
    error('bct:manifold:tangents:InvalidInput', ...
        'Expected (M) or (V,F) as positional inputs, optionally with name-value pairs.');
end

end

% ===== Helper: normalize each row safely =====
function X = normalizeRows(X)
n = vecnorm(X, 2, 2);
bad = (n < eps) | isnan(n);
n(bad) = 1;          % prevent divide-by-zero; leaves bad rows unchanged
X = X ./ n;
X(bad,:) = 0;        % explicitly zero-out degenerate results
end
