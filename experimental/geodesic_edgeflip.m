%% flip_geodesic_bct_demo.m
% Intrinsic flip-geodesic skeleton using bct topo + geom.edge.lengths
% Assumptions:
%  - closed manifold (sphere-like); no boundary edges in practice
%  - topo is consistent halfedge structure
%  - edge lengths from geom.edge.lengths.value are the intrinsic metric

clear; clc;

%% ------------------------------------------------------------
% 0) Load mesh into bct
% ------------------------------------------------------------
bct.start

fs4path='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial';
[vertices, faces] = freesurfer_read_surf(fs4path);

M = bct.Manifold(vertices, faces);
M = M.flip;  % match your convention

topo = M.topology;
geom = M.geometry;

nV = size(M.Vertices,1);
nF = size(M.Faces,1);
nH = numel(topo.tailVertex.value);
nE = size(geom.edge.lengths.value,1);

fprintf('--- sizes --- |V|=%d |F|=%d |E|=%d |H|=%d\n', nV,nF,nE,nH);

%% ------------------------------------------------------------
% 1) Build intrinsic mesh state IM from bct structures
% ------------------------------------------------------------
IM = struct();

IM.nV = nV;
IM.nF = nF;
IM.nE = nE;
IM.nH = nH;

% Topology (mutable copies)
IM.tail = uint32(topo.tailVertex.value);
IM.head = uint32(topo.headVertex.value);
IM.face = uint32(topo.face.value);
IM.next = uint32(topo.next.value);
IM.prev = uint32(topo.prev.value);
IM.twin = uint32(topo.twin.value);
IM.edge = uint32(topo.edge.value);

IM.faceHalfedges = uint32(topo.faceHalfedges.value);  % nF x 3

% Metric
IM.edgeLen = double(geom.edge.lengths.value(:));      % nE x 1

% Convenience: for each halfedge h, its "undirected edge id" is IM.edge(h)
% For each edge e, we need one representative halfedge hRep(e).
hRep = zeros(nE,1,'uint32');
for h = 1:nH
    e = IM.edge(h);
    if hRep(e) == 0
        hRep(e) = uint32(h);
    end
end
IM.hRep = hRep;

%% ------------------------------------------------------------
% 2) Choose endpoints + initial shortest edge path (graph shortestpath)
% ------------------------------------------------------------
% Choose two vertices (example poles; change as needed)

antIdx  = 6653;
postIdx = 978;
s = uint32(antIdx);
t = uint32(postIdx);

% Build an undirected edge list from halfedges -> edges
% Use topo.edgeList if it exists; else build from halfedges.
% In your topo, topo.edgeList.value typically is [nE x 2] endpoints.
if isfield(topo, 'edgeList') && isfield(topo.edgeList, 'value') && ~isempty(topo.edgeList.value)
    EV = uint32(topo.edgeList.value);   % [nE x 2]
else
    % fallback: derive from representative halfedge
    EV = zeros(nE,2,'uint32');
    for e = 1:nE
        h = double(IM.hRep(e));
        EV(e,1) = IM.tail(h);
        EV(e,2) = IM.head(h);
    end
end

G = graph(double(EV(:,1)), double(EV(:,2)), IM.edgeLen, nV);

% Shortest vertex path
vPath = shortestpath(G, double(s), double(t));  % vertex sequence
vPath = uint32(vPath(:));

fprintf('Initial vertex path length: %d vertices\n', numel(vPath));

% Convert vertex path -> edge IDs along path
% We need a mapping (u,v) -> edge id
% Build sparse lookup for speed
edgeIdOf = sparse(double(EV(:,1)), double(EV(:,2)), (1:nE)', nV, nV);
edgeIdOf = edgeIdOf + edgeIdOf.';  % undirected

ePath = zeros(numel(vPath)-1,1,'uint32');
for k = 1:numel(ePath)
    a = double(vPath(k));
    b = double(vPath(k+1));

    eid = full(edgeIdOf(a,b));          % <-- key fix: sparse scalar -> full
    if eid == 0
        error('No edge between consecutive vertices in vPath at step %d', k);
    end
    ePath(k) = uint32(eid);
end


% Path length
L0 = sum(IM.edgeLen(double(ePath)));
fprintf('Initial edge-path length: %.6f\n', L0);

%% ------------------------------------------------------------
% 3) Flip-improvement loop (local shortening criterion)
% ------------------------------------------------------------
maxPasses = 20;
nFlipsTotal = 0;

% For fast membership queries
onPath = false(nE,1);
onPath(double(ePath)) = true;

for pass = 1:maxPasses
    nFlipsThisPass = 0;

    % Iterate over a snapshot of the current path edges
    eList = unique(double(ePath), 'stable');

    for ii = 1:numel(eList)
        e = eList(ii);

        % Representative halfedge for this edge (intrinsic)
        h = double(IM.hRep(e));
        if h == 0, continue; end

        ht = double(IM.twin(h));
        if ht == 0, continue; end

        f0 = double(IM.face(h));
        f1 = double(IM.face(ht));
        if f0 == 0 || f1 == 0
            % boundary edge (shouldn't happen on sphere)
            continue;
        end

        % Quad vertices around diagonal ab:
        a = double(IM.tail(h));
        b = double(IM.head(h));

        % c = third vertex of face f0 opposite edge ab
        % using halfedge cycle: h : a->b, next(h): b->c, next(next(h)): c->a
        h_next  = double(IM.next(h));
        c = double(IM.head(h_next));

        % d = third vertex of face f1 opposite edge ab
        ht_next = double(IM.next(ht));
        d = double(IM.head(ht_next));

        % Reject degeneracy (shouldn't happen)
        if numel(unique([a b c d])) < 4
            continue;
        end

        % Gather the 5 needed edge lengths:
        % lab (current diagonal)
        lab = IM.edgeLen(e);

        % lengths in triangle (a,b,c): lbc, lca
        eid_bc = full(edgeIdOf(b,c)); eid_ca = full(edgeIdOf(c,a));
        if eid_bc==0 || eid_ca==0, continue; end
        lbc = IM.edgeLen(eid_bc);
        lca = IM.edgeLen(eid_ca);

        % lengths in triangle (b,a,d): lad, ldb
        eid_ad = full(edgeIdOf(a,d)); eid_db = full(edgeIdOf(d,b));
        if eid_ad==0 || eid_db==0, continue; end
        lad = IM.edgeLen(eid_ad);
        ldb = IM.edgeLen(eid_db);

        % Compute flipped diagonal length lcd by 2-triangle unfolding
        % Place a=(0,0), b=(lab,0)
        % Triangle abc gives c=(xc, +yc), triangle abd gives d=(xd, -yd)
        xc = (lca^2 - lbc^2 + lab^2) / (2*lab);
        yc2 = lca^2 - xc^2;

        xd = (lad^2 - ldb^2 + lab^2) / (2*lab);
        yd2 = lad^2 - xd^2;

        if yc2 < -1e-10 || yd2 < -1e-10
            % invalid due to numeric or non-metric inconsistency
            continue;
        end

        yc = sqrt(max(yc2,0));
        yd = -sqrt(max(yd2,0));

        lcd = hypot(xc - xd, yc - yd);

        % Local path-shortening heuristic:
        % If the path is using diagonal (a-b), see if replacing it by (c-d)
        % could shorten a local reroute. Minimal naive test:
        % compare lab vs lcd (this is not always sufficient but is a safe v1 gate).
        if lcd >= lab
            continue;
        end

        % --- Perform intrinsic flip of edge e: replace diagonal (a-b) with (c-d) ---
        % We'll reuse the same edge id e, and update the two incident faces connectivity.
        %
        % IMPORTANT: this is the most topology-sensitive part.
        % We will rebuild the two faces' halfedge cycles locally.
        %
        % We'll identify the 6 halfedges involved:
        % For face f0 (a,b,c): halfedges are h (a->b), h_next (b->c), h_prev (c->a)
        h_prev = double(IM.prev(h));
        % For face f1 (b,a,d): halfedges are ht (b->a), ht_next (a->d), ht_prev (d->b)
        ht_prev = double(IM.prev(ht));

        % Rename for clarity:
        hab = h;        hba = ht;
        hbc = h_next;   hca = h_prev;
        had = ht_next;  hdb = ht_prev;

        % After flip, the new diagonal is (c->d) and (d->c)
        % We will set hab to be (c->d) and hba to be (d->c)
        IM.tail(hab) = uint32(c); IM.head(hab) = uint32(d);
        IM.tail(hba) = uint32(d); IM.head(hba) = uint32(c);

        % Update edge id mapping for these halfedges remains edge e
        IM.edge(hab) = uint32(e);
        IM.edge(hba) = uint32(e);

        % Now rebuild face cycles:
        % New face f0 becomes (c,d,b) with halfedges: c->d (hab), d->b (hdb), b->c (hbc)
        % New face f1 becomes (d,c,a) with halfedges: d->c (hba), c->a (hca), a->d (had)

        % Set faces for involved halfedges
        IM.face(hab) = uint32(f0);
        IM.face(hdb) = uint32(f0);
        IM.face(hbc) = uint32(f0);

        IM.face(hba) = uint32(f1);
        IM.face(hca) = uint32(f1);
        IM.face(had) = uint32(f1);

        % Set next/prev around f0: hab -> hdb -> hbc -> hab
        IM.next(hab) = uint32(hdb); IM.prev(hab) = uint32(hbc);
        IM.next(hdb) = uint32(hbc); IM.prev(hdb) = uint32(hab);
        IM.next(hbc) = uint32(hab); IM.prev(hbc) = uint32(hdb);

        % Set next/prev around f1: hba -> hca -> had -> hba
        IM.next(hba) = uint32(hca); IM.prev(hba) = uint32(had);
        IM.next(hca) = uint32(had); IM.prev(hca) = uint32(hba);
        IM.next(had) = uint32(hba); IM.prev(had) = uint32(hca);

        % Update faceHalfedges (store in your [h12 h23 h31] convention; any cyclic order is OK)
        IM.faceHalfedges(f0,:) = uint32([hab, hdb, hbc]);
        IM.faceHalfedges(f1,:) = uint32([hba, hca, had]);

        % Update edge length for flipped diagonal (reuse id e)
        IM.edgeLen(e) = lcd;

        nFlipsThisPass = nFlipsThisPass + 1;
        nFlipsTotal = nFlipsTotal + 1;

        % Also: the global (u,v)->edgeIdOf lookup is still valid because edge ids did not change,
        % but note: the endpoints of edge e changed! So edgeIdOf is now stale for (a,b) vs (c,d).
        % For a proper intrinsic mesh, you need an intrinsic adjacency map.
        %
        % v1 fix: update EV endpoints for edge e and update edgeIdOf accordingly:
        old_u = EV(e,1); old_v = EV(e,2);
        EV(e,1) = uint32(c); EV(e,2) = uint32(d);

        % Remove old mapping
        edgeIdOf(double(old_u), double(old_v)) = 0;
        edgeIdOf(double(old_v), double(old_u)) = 0;

        % Add new mapping
        edgeIdOf(double(c), double(d)) = e;
        edgeIdOf(double(d), double(c)) = e;
    end

    fprintf('Pass %d: flips accepted = %d\n', pass, nFlipsThisPass);

    if nFlipsThisPass == 0
        break;
    end

    % Recompute shortest path on the UPDATED intrinsic graph after flips (simple but robust)
    G = graph(double(EV(:,1)), double(EV(:,2)), IM.edgeLen, nV);
    vPath = shortestpath(G, double(s), double(t));
    vPath = uint32(vPath(:));

    ePath = zeros(numel(vPath)-1,1,'uint32');
    for k = 1:numel(ePath)
        a = double(vPath(k));
        b = double(vPath(k+1));
        eid = full(edgeIdOf(a,b));
        if eid == 0
            error('After flips, missing edge between path vertices at step %d', k);
        end
        ePath(k) = uint32(eid);
    end
end

Lf = sum(IM.edgeLen(double(ePath)));

fprintf('\n--- done ---\n');
fprintf('Total flips: %d\n', nFlipsTotal);
fprintf('Final edge-path length: %.6f  (initial %.6f)\n', Lf, L0);

%% ------------------------------------------------------------
% 4) Output: visualize the final vertex path on the original mesh (optional)
% ------------------------------------------------------------
% For quick sanity, show endpoints and a polyline in MATLAB (not intrinsic straight line).
% If you want to draw on three.js, export vPath and draw as polyline in 3D using M.Vertices.

V = M.Vertices;
P3 = V(double(vPath),:);
viewer = bct.ui.show(M);
viewer.addLine('Action', 'clear');

% Interleave start and end points manually
N = size(P3, 1) - 1;
segments = zeros(N, 6);
for i = 1:N
    segments(i, 1:3) = P3(i, :);      % Start point
    segments(i, 4:6) = P3(i+1, :);    % End point
end

viewer.addLine('Name', 'geodesic', ...
               'Segments', segments, ...
               'Color', 0x0c61bb, ...
               'LineWidth', 5);