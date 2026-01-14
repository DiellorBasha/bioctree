function d = delta(nVertices, vertexIdx)
%DELTA Create Dirac delta vector at specified vertex
%
% Syntax:
%   d = bct.manifold.query.delta(nVertices, vertexIdx)
%
% Inputs:
%   nVertices - Total number of vertices (scalar)
%   vertexIdx - Index of vertex where delta is 1 (scalar, 1-based)
%
% Outputs:
%   d - [nVertices×1] sparse column vector
%       Value is 1 at vertexIdx, 0 elsewhere
%
% Description:
%   Creates a Dirac delta function on the discrete manifold - a vector
%   with value 1 at the specified vertex and 0 at all other vertices.
%   This is useful for:
%   - Point source initialization
%   - Green's function computation
%   - Testing operators at specific locations
%   - Localized field generation
%
%   Returns a sparse vector for memory efficiency.
%
% Examples:
%   % Create delta at vertex 23 for a 100-vertex mesh
%   d = bct.manifold.query.delta(100, 23);
%   % d(23) = 1, all other entries are 0
%
%   % Use as point source for heat equation
%   M = bct.Manifold(V, F);
%   d = bct.manifold.query.delta(M.numVertices(), 50);
%   % Apply Laplacian
%   ops = bct.manifold.operator(M);
%   result = ops.laplacebeltrami * d;
%
%   % Multiple deltas via indexing
%   indices = [10, 20, 30];
%   D = zeros(100, 3);
%   for i = 1:3
%       D(:,i) = bct.manifold.query.delta(100, indices(i));
%   end
%
% See also: bct.Manifold.delta

arguments
    nVertices (1,1) {mustBeInteger, mustBePositive}
    vertexIdx (1,1) {mustBeInteger, mustBePositive}
end

% Validate vertex index
if vertexIdx > nVertices
    error('bct:manifold:query:delta:InvalidIndex', ...
        'vertexIdx (%d) exceeds nVertices (%d)', vertexIdx, nVertices);
end

if vertexIdx < 1
    error('bct:manifold:query:delta:InvalidIndex', ...
        'vertexIdx must be positive (1-based indexing), got %d', vertexIdx);
end

% Create sparse delta vector
d = sparse(vertexIdx, 1, 1, nVertices, 1);

end
