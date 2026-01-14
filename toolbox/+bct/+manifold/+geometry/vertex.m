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
elseif isnumeric(meshInput) && ~isempty(varargin) && isnumeric(varargin{1})
    % vertex(V, F) - valid
else
    error('bct:manifold:geometry:vertex:InvalidInput', ...
        'Expected vertex(M) or vertex(V, F)');
end

% Initialize output structure
out = struct();
out.header = struct();

% Compute vertex normals
[normalHeader, out.normals] = bct.manifold.geometry.vertex.normals(meshInput, varargin{:});
out.header.normals = normalHeader;

% Compute vertex tangents
[tangent1Header, out.tangent1] = bct.manifold.geometry.vertex.tangents1(meshInput, varargin{:});
out.header.tangent1 = tangent1Header;

[tangent2Header, out.tangent2] = bct.manifold.geometry.vertex.tangents2(meshInput, varargin{:});
out.header.tangent2 = tangent2Header;

end
