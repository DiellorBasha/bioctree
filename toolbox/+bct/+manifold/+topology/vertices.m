function [v, to] = vertices(F)
%VERTICES Compute tail and head vertices for all halfedges
%
% Syntax:
%   [v, to] = bct.manifold.topology.vertices(F)
%
% Inputs:
%   F - [nF×3] Face connectivity (1-indexed)
%
% Outputs:
%   v  - [nH×1 uint32] Tail vertex index for each halfedge
%   to - [nH×1 uint32] Head vertex index for each halfedge
%
% Description:
%   For each face [v1 v2 v3], creates three halfedges:
%     h12: v1 -> v2
%     h23: v2 -> v3
%     h31: v3 -> v1
%
%   Halfedges are indexed in blocks:
%     h12 = 1:nF
%     h23 = (nF+1):(2*nF)
%     h31 = (2*nF+1):(3*nF)
%
% See also: bct.manifold.topology

if size(F, 2) ~= 3
    error('bct:topology:halfedge:vertices:InvalidInput', ...
        'Only triangular faces (nF×3) are supported');
end

% Tail vertices: [v1, v1, ..., v2, v2, ..., v3, v3, ...]
v = uint32([F(:,1); F(:,2); F(:,3)]);

% Head vertices: [v2, v2, ..., v3, v3, ..., v1, v1, ...]
to = uint32([F(:,2); F(:,3); F(:,1)]);

end
