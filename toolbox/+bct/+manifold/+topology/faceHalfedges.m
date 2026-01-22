function fh = faceHalfedges(F)
%FACEHALFEDGES Compute halfedge indices for each face
%
% Syntax:
%   fh = bct.manifold.topology.faceHalfedges(F)
%
% Inputs:
%   F - [nF×3] Face connectivity (1-indexed)
%
% Outputs:
%   fh - [nF×3 uint32] Halfedge indices per face [h12 h23 h31]
%
% Description:
%   Returns the three halfedge indices for each face in order:
%     fh(f,:) = [h12, h23, h31]
%   where h12: v1->v2, h23: v2->v3, h31: v3->v1
%
%   Uses fixed halfedge indexing blocks:
%     h12 = 1:nF
%     h23 = (nF+1):(2*nF)
%     h31 = (2*nF+1):(3*nF)
%
% See also: bct.manifold.topology

nF = size(F, 1);

h12 = uint32(1:nF)';
h23 = h12 + nF;
h31 = h23 + nF;

fh = [h12, h23, h31];

end
