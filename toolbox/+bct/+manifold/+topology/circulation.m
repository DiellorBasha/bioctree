function [nxt, prv] = circulation(F)
%CIRCULATION Compute next/prev halfedge pointers around faces
%
% Syntax:
%   [nxt, prv] = bct.manifold.topology.circulation(F)
%
% Inputs:
%   F - [nF×3] Face connectivity (1-indexed)
%
% Outputs:
%   nxt - [nH×1 uint32] Next halfedge around face (CCW)
%   prv - [nH×1 uint32] Previous halfedge around face (CCW)
%
% Description:
%   For each face with halfedges [h12, h23, h31], creates circulation:
%     next: h12 -> h23 -> h31 -> h12
%     prev: h12 <- h23 <- h31 <- h12
%
%   Uses fixed halfedge indexing:
%     h12 = 1:nF
%     h23 = (nF+1):(2*nF)
%     h31 = (2*nF+1):(3*nF)
%
% See also: bct.manifold.topology

nF = size(F, 1);
nH = 3 * nF;

% Halfedge index blocks
h12 = uint32(1:nF)';
h23 = h12 + nF;
h31 = h23 + nF;

% Initialize arrays
nxt = zeros(nH, 1, 'uint32');
prv = zeros(nH, 1, 'uint32');

% Next pointers (CCW around face)
nxt(h12) = h23;
nxt(h23) = h31;
nxt(h31) = h12;

% Previous pointers (CCW around face)
prv(h12) = h31;
prv(h23) = h12;
prv(h31) = h23;

end
