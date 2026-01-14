function out = vertex(meshInput, varargin)
%VERTEX Compute all vertex-based geometric properties
%
% Syntax:
%   vertexGeom = bct.manifold.geometry.vertex(M)
%   vertexGeom = bct.manifold.geometry.vertex(V, F)
%
% Inputs:
%   M    - bct.Manifold object
%   OR
%   V    - [Nv×3] vertex coordinates
%   F    - [Nf×3] face connectivity (1-indexed)
%
% Outputs:
%   out - Structure with fields:
%     .normals   - [Nv×3] Vertex normal vectors (unit, area-weighted)
%     .tangent1  - [Nv×3] First tangent vectors (unit, orthogonal to normals)
%     .tangent2  - [Nv×3] Second tangent vectors (unit, orthogonal to normals and tangent1)
%     .header    - Metadata about computation
%
% Description:
%   Aggregator function that computes all vertex-based geometric properties
%   by calling the individual functions in bct.manifold.geometry.vertex.*
%   Returns normals and tangents directly without duplication in a frame structure.
%
% Examples:
%   % Compute all vertex geometry
%   M = bct.Manifold(V, F);
%   vertexGeom = bct.manifold.geometry.vertex(M);
%   
%   % Access individual properties
%   normals = vertexGeom.normals;
%   tangent1 = vertexGeom.tangent1;
%   tangent2 = vertexGeom.tangent2;
%
% See also: bct.manifold.geometry.face, bct.manifold.geometry.edge,
%           bct.manifold.geometry

% Parse inputs
if nargin == 0
    error('bct:manifold:geometry:vertex:NoInput', ...
        'At least one input required: vertex(M) or vertex(V, F)');
end

% Validate input (Manifold or V,F)
if isa(meshInput, 'bct.Manifold')
    % vertex(M)
    V = meshInput.Vertices;
    F = meshInput.Faces;
elseif isnumeric(meshInput) && ~isempty(varargin) && isnumeric(varargin{1})
    % vertex(V, F) - valid
    V = meshInput;
    F = varargin{1};
else
    error('bct:manifold:geometry:vertex:InvalidInput', ...
        'Expected vertex(M) or vertex(V, F)');
end

% Create surfaceMesh once to avoid redundant creation in subfunctions
mesh = surfaceMesh(V, F);

% Initialize output structure
out = struct();
out.header = struct();

% Compute vertex frame (normals + tangents) in one call to avoid redundancy
% Pass surfaceMesh to avoid redundant creation
[frameHeader, out.normals, out.tangent1, out.tangent2] = ...
    bct.manifold.geometry.vertex.frame(mesh);
out.header.frame = frameHeader;

end
