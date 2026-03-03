function [V2, F2, defects, map] = repair_mesh_defects(V, F, opts)
%REPAIR_MESH_DEFECTS Find + repair common triangle-mesh defects.
%
%   [V2, F2, defects, map] = repair_mesh_defects(V, F, opts)
%
% Inputs
%   V    : nV x 3 double vertex coordinates
%   F    : nF x 3 (double/int) 1-based vertex indices
%   opts : struct (optional)
%       .areaTol        : threshold for 2*area (default 1e-14 * scale^2)
%       .nearTol        : coordinate quantization tolerance for "near dup" (default [])
%                         If [] -> disabled. If set, merges near-duplicate vertices.
%       .maxPasses      : max repair iterations (default 3)
%       .fixNonManifold : true/false remove extra faces on >2-incident edges (default true)
%       .verbose        : true/false (default true)
%
% Outputs
%   V2, F2   : repaired mesh (compacted)
%   defects  : struct with indices/edges *in the mesh state when detected*
%   map      : struct describing mapping from original vertices -> repaired vertices
%       .old2new : nV x 1 (0 for removed)
%       .new2old : nV2 x 1 original vertex ids kept (after merges, maps to a rep)
%
% Notes
%   - Repairs performed (in order, per pass):
%       1) remove duplicate faces
%       2) remove degenerate faces (repeated indices + near-zero area)
%       3) merge duplicate vertices (exact); optionally merge near-duplicates
%       4) remove nonmanifold edges by dropping extra incident faces (heuristic)
%       5) remove unreferenced vertices + reindex faces
%   - Boundary edges are detected but NOT "repaired" here (closing holes is a separate step).
%
% Example
%   opts = struct('nearTol',1e-6,'verbose',true);
%   [Vh,Fh,def,map] = repair_mesh_defects(Vl, Fl, opts);

    if nargin < 3, opts = struct(); end
    opts = setDefault(opts, 'areaTol', []);
    opts = setDefault(opts, 'nearTol', []);
    opts = setDefault(opts, 'maxPasses', 3);
    opts = setDefault(opts, 'fixNonManifold', true);
    opts = setDefault(opts, 'verbose', true);

    V0 = V;
    F0 = double(F);

    % Initialize
    V2 = V0;
    F2 = F0;

    % map from current vertex ids -> original vertex ids (representatives)
    rep = (1:size(V2,1))';

    defects = struct();
    defects.passes = {};

    for pass = 1:opts.maxPasses
        if opts.verbose
            fprintf('\n--- repair_mesh_defects: pass %d/%d ---\n', pass, opts.maxPasses);
        end

        d = struct();
        nV = size(V2,1);
        nF = size(F2,1);

        % ---------- Detect duplicate faces ----------
        [dupFaceIdx, dupGroups] = findDuplicateFaces(F2);
        d.dupFaceIdx   = dupFaceIdx;
        d.dupFaceGroups = dupGroups;

        % Repair: remove duplicate faces (keep first in each group)
        if ~isempty(dupFaceIdx)
            keep = true(nF,1);
            keep(dupFaceIdx) = false;
            F2 = F2(keep,:);
            if opts.verbose, fprintf('Removed duplicate faces: %d\n', numel(dupFaceIdx)); end
        else
            if opts.verbose, fprintf('Duplicate faces: 0\n'); end
        end

        % ---------- Detect degenerate faces ----------
        [degRepIdx, degAreaIdx] = findDegenerateFaces(V2, F2, opts.areaTol);
        d.degRepIdx  = degRepIdx;
        d.degAreaIdx = degAreaIdx;

        % Repair: remove degenerates
        bad = false(size(F2,1),1);
        bad(degRepIdx) = true;
        bad(degAreaIdx) = true;
        if any(bad)
            F2 = F2(~bad,:);
            if opts.verbose, fprintf('Removed degenerate faces: %d (rep=%d, area=%d)\n', nnz(bad), numel(degRepIdx), numel(degAreaIdx)); end
        else
            if opts.verbose, fprintf('Degenerate faces: 0\n'); end
        end

        % ---------- Detect & merge duplicate vertices (exact) ----------
        [dupVertIdx, dupVertGroups, V2, F2, rep] = mergeDuplicateVerticesExact(V2, F2, rep);
        d.dupVertIdx    = dupVertIdx;
        d.dupVertGroups = dupVertGroups;

        if opts.verbose
            fprintf('Exact duplicate vertices merged: %d\n', numel(dupVertIdx));
        end

        % ---------- Detect & merge near-duplicate vertices (optional) ----------
        d.dupNearIdx = [];
        d.dupNearGroups = {};
        if ~isempty(opts.nearTol)
            [dupNearIdx, dupNearGroups, V2, F2, rep] = mergeDuplicateVerticesNear(V2, F2, rep, opts.nearTol);
            d.dupNearIdx    = dupNearIdx;
            d.dupNearGroups = dupNearGroups;
            if opts.verbose
                fprintf('Near-duplicate vertices merged (tol=%g): %d\n', opts.nearTol, numel(dupNearIdx));
            end
        end

        % After merging vertices, remove any newly-degenerate faces
        [degRepIdx2, degAreaIdx2] = findDegenerateFaces(V2, F2, opts.areaTol);
        bad2 = false(size(F2,1),1);
        bad2(degRepIdx2) = true;
        bad2(degAreaIdx2) = true;
        if any(bad2)
            F2 = F2(~bad2,:);
            if opts.verbose, fprintf('Removed post-merge degenerates: %d\n', nnz(bad2)); end
        end
        d.degRepIdx_postMerge  = degRepIdx2;
        d.degAreaIdx_postMerge = degAreaIdx2;

        % ---------- Detect boundary & nonmanifold edges ----------
        [boundaryEdges, nonmanifoldEdges, edgeCounts, Eu] = findEdgeDefects(F2);
        d.boundaryEdges    = boundaryEdges;
        d.nonmanifoldEdges = nonmanifoldEdges;
        d.edgeCounts = edgeCounts; %#ok<STRNU>
        d.uniqueEdges = Eu; %#ok<STRNU>

        if opts.verbose
            fprintf('Boundary edges: %d | Nonmanifold edges: %d\n', size(boundaryEdges,1), size(nonmanifoldEdges,1));
        end

        % Repair: fix nonmanifold edges by dropping extra incident faces (heuristic)
        d.removedFaces_nonmanifold = [];
        if opts.fixNonManifold && ~isempty(nonmanifoldEdges)
            [F2, removedFaceIdx] = fixNonmanifoldEdges_keepTwo(V2, F2, nonmanifoldEdges);
            d.removedFaces_nonmanifold = removedFaceIdx;
            if opts.verbose
                fprintf('Removed faces to fix nonmanifold edges: %d\n', numel(removedFaceIdx));
            end
        end

        % ---------- Unreferenced vertices (and compact/reindex) ----------
        [unrefVertIdx, V2, F2, rep, old2new_local, new2old_local] = compactMesh(V2, F2, rep);
        d.unrefVertIdx = unrefVertIdx;
        d.compact_old2new = old2new_local; %#ok<STRNU>
        d.compact_new2old = new2old_local; %#ok<STRNU>

        if opts.verbose
            fprintf('Unreferenced vertices removed: %d\n', numel(unrefVertIdx));
            fprintf('Mesh now: nV=%d, nF=%d\n', size(V2,1), size(F2,1));
        end

        % ---------- Nonmanifold vertices (bow-ties) ----------
        d.nonmanifoldVertIdx = findNonmanifoldVertices(V2, F2);
        if opts.verbose
            fprintf('Nonmanifold vertices (bow-ties): %d\n', numel(d.nonmanifoldVertIdx));
        end

        defects.passes{pass} = d;

        % Convergence: if nothing changed materially, break
        nothingToFix = isempty(d.dupFaceIdx) && isempty(d.degRepIdx) && isempty(d.degAreaIdx) && ...
                       isempty(d.dupVertIdx) && isempty(d.dupNearIdx) && isempty(d.nonmanifoldEdges) && isempty(d.unrefVertIdx);
        if nothingToFix
            if opts.verbose, fprintf('Converged: no further repairs detected.\n'); end
            break;
        end
    end

    % Final aggregated defect report on final mesh
    defects.final = struct();
    [defects.final.dupFaceIdx, defects.final.dupFaceGroups] = findDuplicateFaces(F2);
    [defects.final.degRepIdx, defects.final.degAreaIdx] = findDegenerateFaces(V2, F2, opts.areaTol);
    [defects.final.boundaryEdges, defects.final.nonmanifoldEdges] = deal(findEdgeDefects(F2));
    defects.final.unrefVertIdx = findUnreferencedVertices(size(V2,1), F2);
    defects.final.nonmanifoldVertIdx = findNonmanifoldVertices(V2, F2);

    % Mapping to original vertex ids: rep holds representative original id for each current vertex
    map = struct();
    map.new2old = rep(:);

    % old2new: for each original vertex, where did it end up? (if merged, maps to rep)
    old2new = zeros(size(V0,1),1);
    for newId = 1:numel(rep)
        oldId = rep(newId);
        old2new(oldId) = newId;
    end
    map.old2new = old2new;

end

% ======================= Helpers =======================

function opts = setDefault(opts, field, val)
    if ~isfield(opts, field) || isempty(opts.(field))
        opts.(field) = val;
    end
end

function [dupFaceIdx, dupGroups] = findDuplicateFaces(F)
    nF = size(F,1);
    Fs = sort(F,2);
    [~, ia, ic] = unique(Fs,'rows','stable');

    dupMask = true(nF,1);
    dupMask(ia) = false;
    dupFaceIdx = find(dupMask);

    dupGroups = accumarray(ic, (1:nF)', [], @(x){x});
    dupGroups = dupGroups(cellfun(@numel, dupGroups) > 1);
end

function [degRepIdx, degAreaIdx] = findDegenerateFaces(V, F, areaTol)
    % repeated indices
    degRepIdx = find(F(:,1)==F(:,2) | F(:,2)==F(:,3) | F(:,1)==F(:,3));

    % area tolerance: scale-aware default if not provided
    if isempty(areaTol)
        bb = max(V,[],1) - min(V,[],1);
        scale = norm(bb);
        areaTol = 1e-14 * max(scale^2, 1); % conservative default
    end

    A = V(F(:,1),:); B = V(F(:,2),:); C = V(F(:,3),:);
    area2 = vecnorm(cross(B-A, C-A, 2), 2, 2);
    degAreaIdx = find(area2 < areaTol);
end

function unrefVertIdx = findUnreferencedVertices(nV, F)
    used = false(nV,1);
    used(F(:)) = true;
    unrefVertIdx = find(~used);
end

function [boundaryEdges, nonmanifoldEdges, counts, Eu] = findEdgeDefects(F)
    E = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];
    E = sort(E,2);
    [Eu,~,ic] = unique(E,'rows');
    counts = accumarray(ic,1);

    boundaryEdges = Eu(counts==1,:);
    nonmanifoldEdges = Eu(counts>2,:);
end

function [dupVertIdx, dupVertGroups, V2, F2, rep2] = mergeDuplicateVerticesExact(V, F, rep)
    nV = size(V,1);

    [~, ia, ic] = unique(V, 'rows', 'stable');
    dupMask = true(nV,1); dupMask(ia) = false;
    dupVertIdx = find(dupMask);

    dupVertGroups = accumarray(ic, (1:nV)', [], @(x){x});
    dupVertGroups = dupVertGroups(cellfun(@numel, dupVertGroups) > 1);

    if isempty(dupVertIdx)
        V2 = V; F2 = F; rep2 = rep;
        return;
    end

    % Map every vertex to its kept representative (the first occurrence in stable unique)
    repId = ia(ic);              % nV x 1, points to kept vertex index
    F2 = repId(F);

    % Merge rep mapping (track original representative id)
    rep2 = rep(repId);

    % Compact mesh to remove unreferenced vertices
    [~, V2, F2, rep2] = compactMesh(V, F2, rep2);
end

function [dupNearIdx, dupNearGroups, V2, F2, rep2] = mergeDuplicateVerticesNear(V, F, rep, tol)
    nV = size(V,1);

    Vr = round(V / tol) * tol;
    [~, ia, ic] = unique(Vr,'rows','stable');

    dupMask = true(nV,1); dupMask(ia) = false;
    dupNearIdx = find(dupMask);

    dupNearGroups = accumarray(ic, (1:nV)', [], @(x){x});
    dupNearGroups = dupNearGroups(cellfun(@numel, dupNearGroups) > 1);

    if isempty(dupNearIdx)
        V2 = V; F2 = F; rep2 = rep;
        return;
    end

    repId = ia(ic);      % representative by quantized bin
    F2 = repId(F);
    rep2 = rep(repId);

    % Replace coordinates by representative coordinates (optional but keeps exact duplicates)
    V2 = V;
    V2 = V2(repId,:);  % keep representative coords per original id (will be compacted next)

    % Compact
    [~, V2, F2, rep2] = compactMesh(V2, F2, rep2);
end

function [Fout, removedFaceIdx] = fixNonmanifoldEdges_keepTwo(V, F, nonmanifoldEdges)
    toRemove = false(size(F,1),1);

    for k = 1:size(nonmanifoldEdges,1)
        e = nonmanifoldEdges(k,:);
        fids = facesIncidentToEdge(F, e);
        if numel(fids) <= 2, continue; end

        % Keep two most similar normals
        N = faceNormals(V, F(fids,:));
        S = N*N';
        S(1:size(S,1)+1:end) = -Inf;

        [i,j] = ind2sub(size(S), find(S==max(S(:)),1,'first'));
        keep = sort([fids(i); fids(j)]);
        drop = setdiff(fids, keep);

        toRemove(drop) = true;
    end

    removedFaceIdx = find(toRemove);
    Fout = F(~toRemove,:);
end

function fids = facesIncidentToEdge(F, e)
    a = e(1); b = e(2);
    fids = find(any(F==a,2) & any(F==b,2));
end

function N = faceNormals(V, F)
    A = V(F(:,1),:); B = V(F(:,2),:); C = V(F(:,3),:);
    N = cross(B-A, C-A, 2);
    nrm = vecnorm(N,2,2);
    N = N ./ max(nrm, eps);
end

function [unrefVertIdx, V2, F2, rep2, old2new, new2old] = compactMesh(V, F, rep)
    nV = size(V,1);
    used = false(nV,1);
    used(F(:)) = true;
    unrefVertIdx = find(~used);

    new2old = find(used);  % old ids that survive (in current mesh indexing)
    old2new = zeros(nV,1);
    old2new(new2old) = 1:numel(new2old);

    V2 = V(new2old,:);
    F2 = old2new(F);

    rep2 = rep(new2old);
end

function nonmanifoldVertIdx = findNonmanifoldVertices(V, F)
    %#ok<INUSD>
    nV = size(V,1);
    Vf = accumarray(F(:), repelem((1:size(F,1))',3), [nV 1], @(x){x}, {});

    nonmanifoldVert = false(nV,1);

    for v = 1:nV
        fids = Vf{v};
        if numel(fids) < 3, continue; end

        Fi = F(fids,:);
        other = zeros(numel(fids),2);
        for i = 1:numel(fids)
            tri = Fi(i,:);
            tri(tri==v) = [];
            if numel(tri) ~= 2
                % degenerate face should have been removed; mark as problematic
                nonmanifoldVert(v) = true;
                continue;
            end
            other(i,:) = tri;
        end

        Adj = false(numel(fids));
        for i = 1:numel(fids)
            for j = i+1:numel(fids)
                if any(other(i,:)==other(j,1)) || any(other(i,:)==other(j,2))
                    Adj(i,j)=true; Adj(j,i)=true;
                end
            end
        end

        G = graph(Adj);
        bins = conncomp(G);
        if max(bins) > 1
            nonmanifoldVert(v) = true;
        end
    end

    nonmanifoldVertIdx = find(nonmanifoldVert);
end