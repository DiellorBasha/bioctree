function [faceNeighbors, neighborEdge] = neighbors(F, fh, twin, face_id)
%NEIGHBORS Compute face adjacency information
%
% Syntax:
%   [faceNeighbors, neighborEdge] = bct.manifold.topology.neighbors(F, fh, twin, face_id)
%
% Inputs:
%   F       - [nF×3] Face connectivity (1-indexed)
%   fh      - [nF×3] Halfedge indices per face
%   twin    - [nH×1] Twin halfedge indices (0 for boundary)
%   face_id - [nH×1] Incident face index for each halfedge
%
% Outputs:
%   faceNeighbors - [nF×3 int32] Adjacent face indices (-1 for boundary)
%   neighborEdge  - [nF×3 uint8] Local edge index (1..3) in neighbor face
%
% Description:
%   For each face and each of its three edges, finds:
%     - The adjacent face across that edge (or -1 if boundary)
%     - The local edge index in the neighbor face (1..3)
%
%   Convention: faceNeighbors(f, i) is the face adjacent across edge i,
%   where i=1,2,3 corresponds to edges [v1-v2, v2-v3, v3-v1].
%
% See also: bct.manifold.topology

nF = size(F, 1);

% Initialize outputs
faceNeighbors = -ones(nF, 3, 'int32');
neighborEdge = zeros(nF, 3, 'uint8');

% For each face and each edge
for f = 1:nF
    for i = 1:3
        h = fh(f, i);
        ht = twin(h);
        
        % Skip boundary edges
        if ht == 0
            continue;
        end
        
        % Get neighbor face
        g = face_id(ht);
        faceNeighbors(f, i) = int32(g);
        
        % Find which local edge in face g corresponds to halfedge ht
        idx = find(fh(g, :) == ht, 1, 'first');
        if isempty(idx)
            error('bct:topology:halfedge:neighbors:TwinInconsistency', ...
                'Halfedge twin not found in neighbor face');
        end
        neighborEdge(f, i) = uint8(idx);
    end
end

end
