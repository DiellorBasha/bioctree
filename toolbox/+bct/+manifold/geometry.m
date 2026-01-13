function geom = geometry(M, varargin)
%GEOMETRY Compute all geometric properties of a manifold
%
% Syntax:
%   geom = bct.manifold.geometry(M)
%   geom = bct.manifold.geometry(M, Name, Value)
%
% Inputs:
%   M - bct.Manifold object
%
% Name-Value Arguments:
%   'NormalType' - 'vertex' (default) or 'face' for normal computation
%   'TangentDomain' - 'face' (default) or 'vertex' for tangent frames
%   'ForceFrame' - false (default) or true to force frame recomputation
%
% Outputs:
%   geom - Structure with fields:
%     .centroids - [nF×3] Face centroids
%     .normals   - [nV×3] or [nF×3] Normal vectors (depends on NormalType)
%     .tangents  - Structure with fields:
%       .N  - [nF×3] or [nV×3] Normal vectors
%       .e1 - [nF×3] or [nV×3] First tangent basis vector
%       .e2 - [nF×3] or [nV×3] Second tangent basis vector
%     .frame     - Structure with orthonormal frame (from bct.manifold.geometry.frame)
%     .cotan     - [nF×3] Cotangent values per face
%
% Description:
%   Convenience function that computes all geometric properties of a
%   manifold in a single call. Results are returned in a structure for
%   easy access.
%
% Examples:
%   % Compute all geometry
%   M = bct.Manifold(V, F);
%   geom = bct.manifold.geometry(M);
%   
%   % Access individual properties
%   C = geom.centroids;
%   N = geom.normals;
%   T1 = geom.tangents.e1;
%   
%   % Compute with face normals instead
%   geom = bct.manifold.geometry(M, 'NormalType', 'face');
%   FN = geom.normals;  % Now [nF×3]
%
% See also: bct.manifold.geometry.centroids, bct.manifold.geometry.normals,
%           bct.manifold.geometry.tangents, bct.manifold.geometry.frame,
%           bct.manifold.geometry.cotan

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.geometry';
addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));
addParameter(p, 'NormalType', 'vertex', @(x) ischar(x) || isstring(x));
addParameter(p, 'TangentDomain', 'face', @(x) ischar(x) || isstring(x));
addParameter(p, 'ForceFrame', false, @islogical);
parse(p, M, varargin{:});

normalType = p.Results.NormalType;
tangentDomain = p.Results.TangentDomain;
forceFrame = p.Results.ForceFrame;

% Validate inputs
if ~ismember(lower(normalType), {'vertex', 'face'})
    error('bct:manifold:geometry:InvalidNormalType', ...
        'NormalType must be ''vertex'' or ''face''');
end
if ~ismember(lower(tangentDomain), {'vertex', 'face'})
    error('bct:manifold:geometry:InvalidTangentDomain', ...
        'TangentDomain must be ''vertex'' or ''face''');
end

% Compute all geometry properties
geom = struct();

% Centroids
geom.centroids = bct.manifold.geometry.centroids(M);

% Normals
geom.normals = bct.manifold.geometry.normals(M, normalType);

% Tangent frames
[N, e1, e2] = bct.manifold.geometry.tangents(M, 'Domain', tangentDomain);
geom.tangents = struct('N', N, 'e1', e1, 'e2', e2);

% Frame (cached orthonormal frame)
if forceFrame
    geom.frame = bct.manifold.geometry.frame(M, 'Force', true);
else
    geom.frame = bct.manifold.geometry.frame(M);
end

% Cotangent values
geom.cotan = bct.manifold.geometry.cotan(M.Vertices, M.Faces);

end
