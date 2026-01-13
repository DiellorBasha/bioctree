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
%   - Delegates to bct.manifold.geometry.edgeLengths
%
% See also: bct.graph.femWeights, bct.manifold.geometry.edgeLengths

arguments
    Manifold (1,1) bct.Manifold
end

% Delegate to geometry module (returns header and values)
[~, w] = bct.manifold.geometry.edgeLengths(Manifold);

end
