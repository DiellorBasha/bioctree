function faceNeighborsOpp0 = computeFaceNeighbors(F, H)
% computeFaceNeighborsOpp0
% Returns face neighbor table [nF x 3] where column i is the neighbor across the
% edge opposite vertex F(f,i).
%
% Output is 0-based for JS, with boundary = -1 sentinel.

F  = int32(F);  % [nF x 3], 1-based vertex indices
nF = int32(size(F,1));

fh   = int32(H.fh);          % [nF x 3], halfedge ids (1-based)
v    = int32(H.v);           % [nH x 1], from-vertex for each halfedge
to   = int32(H.to);          % [nH x 1], to-vertex for each halfedge
twin = int32(H.twin);        % [nH x 1], twin halfedge id
faceOf = int32(H.face);      % [nH x 1], face id for each halfedge (1-based)
isB  = logical(H.isBoundary);

faceNeighborsOpp = -ones(nF, 3, 'int32');   % 1-based face ids for now (or -1)

for f = 1:nF

    a = F(f,1); b = F(f,2); c = F(f,3);

    % For vertex order [a b c], opposite edges are:
    % opp(1,:) = [b c] (opposite a)
    % opp(2,:) = [c a] (opposite b)
    % opp(3,:) = [a b] (opposite c)
    opp = [ b c;  c a;  a b ];

    for i = 1:3

        p = opp(i,1); q = opp(i,2);

        % find which of the 3 halfedges of face f corresponds to edge {p,q}
        kFound = int32(0);
        for k = 1:3
            h = fh(f,k);
            if (v(h)==p && to(h)==q) || (v(h)==q && to(h)==p)
                kFound = int32(k);
                break;
            end
        end

        if kFound == 0
            error('Could not match opposite edge for face %d, vertex slot %d.', f, i);
        end

        h = fh(f,kFound);

        if isB(h)
            faceNeighborsOpp(f,i) = -1;
        else
            ht = twin(h);
            g = faceOf(ht);          % neighbor face (1-based)
            faceNeighborsOpp(f,i) = g;
        end

    end
end

% Convert to 0-based for JS (keep -1 sentinel)
faceNeighborsOpp0 = faceNeighborsOpp;
mask = faceNeighborsOpp0 > 0;
faceNeighborsOpp0(mask) = faceNeighborsOpp0(mask) - 1;

end
