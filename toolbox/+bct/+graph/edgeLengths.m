function w = edgeLengths(Manifold)
%EDGELENGTHS Compute Euclidean edge lengths
%
% Syntax:
%   w = bct.graph.edgeLengths(Manifold)
%
% Inputs:
%   Manifold - bct.Manifold object
%
% Returns:
%   w - [E×1] vector of edge lengths (geometric weights)
%
% Notes:
%   - Uses Euclidean distance between vertex positions
%   - Standard geometric metric for navigation
%
% See also: bct.graph.femWeights

arguments
    Manifold (1,1) bct.Manifold
end

V = Manifold.Vertices;
E = Manifold.Edges;

i = E(:,1);
j = E(:,2);

w = vecnorm(V(i,:) - V(j,:), 2, 2);

end
