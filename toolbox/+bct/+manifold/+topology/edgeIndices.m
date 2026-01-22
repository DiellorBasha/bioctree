function edge_id = edgeIndices(F)
%EDGEINDICES Compute undirected edge index for each halfedge
%
% Syntax:
%   edge_id = bct.manifold.topology.edgeIndices(F)
%
% Outputs:
%   edge_id - [nH×1 uint32] Undirected edge index for each halfedge
%
% Description:
%   Uses canonical edge indexing from bct.manifold.topology.edges to
%   ensure consistency across all topology functions.
%
%   Each halfedge is assigned the index of its undirected edge.
%   Twin halfedges share the same edge index.
%
% See also: bct.manifold.topology.edges

[~, edge_id] = bct.manifold.topology.edges(F);
edge_id = uint32(edge_id);

end
