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
%     .normals  - [Nv×3] Vertex normal vectors (unit, area-weighted)
%     .frame    - Structure with .normal, .tangent1, .tangent2 orthonormal frames
%     .header   - Metadata about computation
%
% Description:
%   Aggregator function that computes all vertex-based geometric properties
%   by calling the individual functions in bct.manifold.geometry.vertex.*
%
% Examples:
%   % Compute all vertex geometry
%   M = bct.Manifold(V, F);
%   vertexGeom = bct.manifold.geometry.vertex(M);
%   
%   % Access individual properties
%   normals = vertexGeom.normals;
%   frame = vertexGeom.frame;
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

% Compute vertex frames
[frameHeader, normal, tangent1, tangent2] = bct.manifold.geometry.vertex.frame(meshInput, varargin{:});
out.frame = struct('normal', normal, 'tangent1', tangent1, 'tangent2', tangent2);
out.header.frame = frameHeader;

end
