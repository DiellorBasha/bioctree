function [F2, info] = orientConsistently(V, F)
%ORIENTCONSISTENTLY Enforce consistent face winding over connected components.
%
% This ensures that across every interior edge shared by two faces,
% the two faces traverse the shared edge in opposite directions.
%
% Inputs:
%   V [nV×3] - used only for completeness (not required)
%   F [nF×3]
%
% Outputs:
%   F2 - faces with consistent winding (per component)
%   info - struct with counts (flipped faces, components, etc.)
%
% Notes:
%   - Works for open or closed surfaces.
%   - Assumes faces are valid triangles and indices are in range.
%
nF = size(F,1);
F2 = F;

% Build adjacency via undirected edges with incident faces and directed orientation
dE = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];         % 3*nF x 2
uE = sort(dE, 2);                                  % undirected keys
[Eu, ~, ic] = unique(uE, 'rows');

% For each unique edge, collect occurrences (two for interior manifold edges)
edgeOcc = accumarray(ic, (1:size(dE,1))', [], @(x){x}); % cell, occ indices in dE

% Build face adjacency and required flip relation:
% For two faces sharing an edge, if their directed edge is the same,
% then one face must be flipped relative to the other.
adj = cell(nF,1);
needFlip = cell(nF,1);  % parallel to adj: needFlip{f}(k)=true if neighbor must be flipped wrt f

for e = 1:size(Eu,1)
    occ = edgeOcc{e};
    if numel(occ) < 2
        continue; % boundary edge
    elseif numel(occ) > 2
        % non-manifold edge; orientation consistency may not be resolvable
        continue;
    end

    o1 = occ(1); o2 = occ(2);
    f1 = mod(o1-1, nF) + 1;
    f2 = mod(o2-1, nF) + 1;

    dir1 = dE(o1,:);
    dir2 = dE(o2,:);

    % If the two directed representations are identical, faces traverse edge same way => inconsistent.
    % We encode that neighbor must be flipped relative to current.
    flipNeighbor = isequal(dir1, dir2);

    % Add adjacency both ways
    adj{f1}(end+1) = f2;
    needFlip{f1}(end+1) = flipNeighbor;

    adj{f2}(end+1) = f1;
    needFlip{f2}(end+1) = flipNeighbor;
end

% BFS across face graph assigning orientation states
visited = false(nF,1);
flipState = false(nF,1);  % flipState(f)=true => flip face f relative to original

nComponents = 0;
nFlipped = 0;
hasContradiction = false;

for f0 = 1:nF
    if visited(f0), continue; end
    nComponents = nComponents + 1;

    % Start new component
    queue = f0;
    visited(f0) = true;
    flipState(f0) = false;

    while ~isempty(queue)
        f = queue(1); queue(1) = [];

        neigh = adj{f};
        rel   = needFlip{f};
        for k = 1:numel(neigh)
            g = neigh(k);
            desired = xor(flipState(f), rel(k));  % if rel says flip neighbor, xor it
            if ~visited(g)
                visited(g) = true;
                flipState(g) = desired;
                queue(end+1) = g; %#ok<AGROW>
            else
                if flipState(g) ~= desired
                    % Contradiction => mesh not orientable or adjacency built over non-manifold structure
                    hasContradiction = true;
                end
            end
        end
    end
end

% Apply flips
toFlip = find(flipState);
if ~isempty(toFlip)
    F2(toFlip, [2 3]) = F2(toFlip, [3 2]);
    nFlipped = numel(toFlip);
end

info = struct();
info.applied = true;
info.nFaces = nF;
info.nComponents = nComponents;
info.nFlippedFaces = nFlipped;
info.hasContradiction = hasContradiction;

end
