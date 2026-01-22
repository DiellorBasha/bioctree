function face_id = faces(F)
%FACES Compute incident face index for all halfedges
%
% Syntax:
%   face_id = bct.manifold.topology.faces(F)
%
% Inputs:
%   F - [nF×3] Face connectivity (1-indexed)
%
% Outputs:
%   face_id - [nH×1 uint32] Incident face index for each halfedge
%
% Description:
%   Each of the three halfedges per face has the same incident face.
%   Returns [1,1,1,...,nF,nF,nF]' reshaped to match halfedge indexing.
%
% See also: bct.manifold.topology.vertices

nF = size(F, 1);

% Each face contributes 3 halfedges with the same face index
face_id = uint32([(1:nF)'; (1:nF)'; (1:nF)']);

end
