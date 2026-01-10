function A = assembleAdjacency(Manifold)
%ASSEMBLEADJACENCY Build adjacency matrix from Manifold topology
%
% Syntax:
%   A = bct.graph.assembleAdjacency(Manifold)
%
% Inputs:
%   Manifold - bct.Manifold object
%
% Returns:
%   A - [N×N] sparse logical adjacency matrix (symmetric, no self-loops)
%
% Notes:
%   - Uses Manifold.Edges as canonical topology source
%   - Result is symmetric (undirected graph)
%   - No self-loops included
%
% See also: bct.Manifold.adjacency

arguments
    Manifold (1,1) bct.Manifold
end

% Use Manifold's adjacency method (canonical source)
A = Manifold.adjacency();

end
