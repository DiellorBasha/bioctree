function [W, projInfo] = buildProjectionMatrix(sm, destSphereL, destSphereR, opts)
%BUILDPROJECTIONMATRIX Build sparse interpolation matrix for projecting
%   source data from a subject's cortex to an fsaverage (or any target)
%   surface, using FreeSurfer spherical registration.
%
%   [W, projInfo] = buildProjectionMatrix(sm, destSphereL, destSphereR)
%   [W, projInfo] = buildProjectionMatrix(sm, destSphereL, destSphereR, Name=Value)
%
%   Uses the subject's Reg.Sphere.Vertices (FreeSurfer ?h.sphere.reg
%   coordinates stored in the Brainstorm surface file) and the destination
%   surface's sphere.reg coordinates to build a Shepard's inverse-distance
%   interpolation matrix W.
%
%   The interpolation is done **per hemisphere** in the shared spherical
%   registration space. W maps from subject source space → destination
%   vertex space:
%
%       projectedData = W * subjectSourceData;
%       % [nDestTotal × T] = [nDestTotal × nSrcTotal] * [nSrcTotal × T]
%
%   Inputs:
%       sm           - sourceMapping struct from loadBrainstorm (must have
%                      .Reg.Sphere.Vertices and .Atlas fields), OR a struct
%                      with at least those two fields. Can also pass the
%                      provenance struct from writeSourceDatastore.
%       destSphereL  - [nDestL × 3] destination left-hemisphere sphere.reg
%                      vertex coordinates (e.g. fsaverage5 lh.sphere.reg)
%       destSphereR  - [nDestR × 3] destination right-hemisphere sphere.reg
%                      vertex coordinates (e.g. fsaverage5 rh.sphere.reg)
%
%   Name-Value Arguments:
%       NbNeighbors  - number of nearest neighbors for Shepard's
%                      interpolation (default 8, matching Brainstorm)
%       ExpDistance   - distance exponent for weight decay (default 2)
%       Verbose      - print diagnostics (default true)
%
%   Outputs:
%       W        - sparse [nDestTotal × nSrcTotal] interpolation matrix
%                  where nDestTotal = nDestL + nDestR
%                  Rows sum to 1 (weighted average). Row order is
%                  [left hemisphere; right hemisphere].
%       projInfo - struct with projection metadata:
%                  .nSrcL, .nSrcR, .nSrcTotal  — source vertex counts
%                  .nDestL, .nDestR, .nDestTotal — destination vertex counts
%                  .nbNeighbors, .expDistance    — interpolation parameters
%                  .srcIdxL, .srcIdxR           — L/R vertex indices in src
%                  .hemiOrder                    — "LR" or "RL"
%
%   Pipeline example:
%       % Build W once per subject:
%       fs5root = 'C:\...\fsaverage5\surf';
%       [sphL, ~] = mne_read_surface(fullfile(fs5root, 'lh.sphere.reg'));
%       [sphR, ~] = mne_read_surface(fullfile(fs5root, 'rh.sphere.reg'));
%       [W, pInfo] = buildProjectionMatrix(sm, sphL, sphR);
%
%       % Source-map a band, then project to fsaverage5:
%       alphaSource = K * amplitude.alpha;      % [10244 × T]
%       alphaFs5    = W * alphaSource;           % [20484 × T]
%
%       % Or combined in one step:
%       alphaFs5 = W * K * amplitude.alpha;      % W*K can be precomputed
%
%   Interpolation method:
%       Modified Shepard's inverse-distance weighting with k nearest
%       neighbors, matching Brainstorm's tess_interp_tess2tess. For each
%       destination vertex, the k=8 nearest source vertices on the
%       registered sphere are found, and weights are assigned:
%
%           w_j = ((d_k - d_j) / (d_k * d_j))^p
%
%       where d_j is the squared distance to neighbor j, d_k is the
%       squared distance to the k-th (farthest) neighbor, and p is the
%       distance exponent (default 2). Weights are row-normalized.
%
%   See also: bst_shepards, bst_nearest, loadBrainstorm, readBandMatrix

    arguments
        sm           (1,1) struct
        destSphereL  (:,3) double
        destSphereR  (:,3) double
        opts.NbNeighbors (1,1) double {mustBePositive, mustBeInteger} = 8
        opts.ExpDistance  (1,1) double {mustBePositive}               = 2
        opts.Verbose     (1,1) logical                               = true
    end

    % ---- Validate source Reg.Sphere.Vertices ----
    if ~isfield(sm, 'Reg') || ~isfield(sm.Reg, 'Sphere') || ...
       ~isfield(sm.Reg.Sphere, 'Vertices') || isempty(sm.Reg.Sphere.Vertices)
        error('buildProjectionMatrix:NoReg', ...
            'Source struct must have Reg.Sphere.Vertices (FreeSurfer sphere registration).');
    end
    srcSphere = sm.Reg.Sphere.Vertices;  % [nSrcTotal × 3]
    nSrcTotal = size(srcSphere, 1);

    % ---- Split source sphere into L/R hemispheres ----
    [srcIdxL, srcIdxR, hemiOrder] = splitHemispheres(sm, nSrcTotal);
    nSrcL = numel(srcIdxL);
    nSrcR = numel(srcIdxR);

    % Extract per-hemisphere sphere coordinates
    % Reg.Sphere.Vertices is packed as two contiguous blocks
    if hemiOrder == "LR"
        srcSphL = srcSphere(1:nSrcL, :);
        srcSphR = srcSphere(nSrcL+1:end, :);
    else
        srcSphR = srcSphere(1:nSrcR, :);
        srcSphL = srcSphere(nSrcR+1:end, :);
    end

    nDestL = size(destSphereL, 1);
    nDestR = size(destSphereR, 1);
    nDestTotal = nDestL + nDestR;

    if opts.Verbose
        fprintf('buildProjectionMatrix:\n');
        fprintf('  Source:  %d vertices (L=%d, R=%d), hemi order: %s\n', ...
            nSrcTotal, nSrcL, nSrcR, hemiOrder);
        fprintf('  Dest:    %d vertices (L=%d, R=%d)\n', nDestTotal, nDestL, nDestR);
        fprintf('  Params:  k=%d neighbors, distance exponent=%d\n', ...
            opts.NbNeighbors, opts.ExpDistance);
    end

    % ---- Build interpolation matrices per hemisphere ----
    if opts.Verbose, fprintf('  Building left hemisphere W [%d × %d]...\n', nDestL, nSrcL); end
    W_L = shepards(destSphereL, srcSphL, opts.NbNeighbors, opts.ExpDistance);

    if opts.Verbose, fprintf('  Building right hemisphere W [%d × %d]...\n', nDestR, nSrcR); end
    W_R = shepards(destSphereR, srcSphR, opts.NbNeighbors, opts.ExpDistance);

    % ---- Assemble full W matrix ----
    % W is [nDestTotal × nSrcTotal] with block-diagonal structure:
    %   [ W_L   0  ]     if hemiOrder == "LR"  (src cols: L first, R second)
    %   [  0   W_R ]
    %
    %   [  0   W_L ]     if hemiOrder == "RL"  (src cols: R first, L second)
    %   [ W_R   0  ]
    %
    % Dest rows are always [L; R].

    if hemiOrder == "LR"
        % Source is [L block; R block] → W_L occupies cols 1:nSrcL, W_R occupies cols nSrcL+1:end
        W = blkdiag(W_L, W_R);
    else
        % Source is [R block; L block]
        % Dest row order: L rows (1:nDestL), R rows (nDestL+1:end)
        % L dest needs src cols nSrcR+1:end (the L block in src)
        % R dest needs src cols 1:nSrcR (the R block in src)
        W = sparse(nDestTotal, nSrcTotal);
        W(1:nDestL, nSrcR+1:end) = W_L;
        W(nDestL+1:end, 1:nSrcR) = W_R;
    end

    % ---- Info struct ----
    projInfo = struct();
    projInfo.nSrcL       = nSrcL;
    projInfo.nSrcR       = nSrcR;
    projInfo.nSrcTotal   = nSrcTotal;
    projInfo.nDestL      = nDestL;
    projInfo.nDestR      = nDestR;
    projInfo.nDestTotal  = nDestTotal;
    projInfo.nbNeighbors = opts.NbNeighbors;
    projInfo.expDistance  = opts.ExpDistance;
    projInfo.srcIdxL     = srcIdxL;
    projInfo.srcIdxR     = srcIdxR;
    projInfo.hemiOrder   = hemiOrder;

    if opts.Verbose
        fprintf('  W: sparse [%d × %d], %.0f nonzeros (%.1f per row)\n', ...
            size(W,1), size(W,2), nnz(W), nnz(W)/nDestTotal);
        fprintf('  Done.\n');
    end
end


% =========================================================================
%  HEMISPHERE SPLITTING
% =========================================================================

function [idxL, idxR, hemiOrder] = splitHemispheres(sm, nSrcTotal)
%SPLITHEMISPHERES Find L/R vertex indices from Atlas or fallback geometry.

    idxL = [];
    idxR = [];

    % Strategy 1: Structures atlas (Brainstorm standard)
    if isfield(sm, 'Atlas') && ~isempty(sm.Atlas)
        iStruct = find(strcmpi({sm.Atlas.Name}, 'Structures'), 1);
        if ~isempty(iStruct)
            scouts = sm.Atlas(iStruct).Scouts;
            iL = find(strcmpi('Cortex L', {scouts.Label}), 1);
            iR = find(strcmpi('Cortex R', {scouts.Label}), 1);
            if ~isempty(iL) && ~isempty(iR)
                idxL = scouts(iL).Vertices(:);
                idxR = scouts(iR).Vertices(:);
            end
        end
    end

    % Strategy 2: Geometric split using surface vertices
    if isempty(idxL) && isfield(sm, 'surfaceVertices')
        V = sm.surfaceVertices;
        % FreeSurfer convention: Y-axis is left-right in RAS
        % Brainstorm convention: dim 2 is typically left-right in SCS
        % Use median split on Y coordinate
        yMedian = median(V(:,2));
        idxL = find(V(:,2) > yMedian);
        idxR = find(V(:,2) <= yMedian);
        warning('buildProjectionMatrix:GeometricSplit', ...
            'No Structures atlas found. Using geometric Y-split (less reliable).');
    end

    if isempty(idxL)
        error('buildProjectionMatrix:NoHemiSplit', ...
            'Cannot determine hemisphere split. Provide Atlas with Structures atlas.');
    end

    % Validate sizes
    if numel(idxL) + numel(idxR) ~= nSrcTotal
        error('buildProjectionMatrix:HemiMismatch', ...
            'Hemisphere vertex counts (L=%d + R=%d = %d) do not match sphere vertices (%d).', ...
            numel(idxL), numel(idxR), numel(idxL)+numel(idxR), nSrcTotal);
    end

    % Determine hemisphere ordering in Reg.Sphere.Vertices
    if idxL(1) < idxR(1)
        hemiOrder = "LR";
    else
        hemiOrder = "RL";
    end
end


% =========================================================================
%  SHEPARD'S INTERPOLATION
% =========================================================================

function W = shepards(destLoc, srcLoc, nbNeighbors, expDistance)
%SHEPARDS Modified Shepard's inverse-distance interpolation.
%   W = shepards(destLoc, srcLoc, nbNeighbors, expDistance)
%
%   Builds a sparse [nDest × nSrc] interpolation matrix using k-nearest
%   neighbor Shepard's weighting. Compatible with Brainstorm's bst_shepards.
%
%   If bst_shepards is on the MATLAB path (Brainstorm initialized), uses
%   it directly. Otherwise, uses a standalone implementation with
%   knnsearch (Statistics and Machine Learning Toolbox).

    nDest = size(destLoc, 1);

    % Try Brainstorm's implementation first (most compatible)
    try
        W = bst_shepards(destLoc, srcLoc, nbNeighbors, 0, expDistance, 0);
        return
    catch
        % Fall through to standalone implementation
    end

    % ---- Standalone implementation ----
    % k-NN search
    K = nbNeighbors;
    try
        [I, D] = knnsearch(srcLoc, destLoc, 'K', K);
    catch
        % Fallback: brute force if no Statistics toolbox
        I = zeros(nDest, K);
        D = zeros(nDest, K);
        for di = 1:nDest
            diffs = srcLoc - destLoc(di,:);
            dists = sqrt(sum(diffs.^2, 2));
            [sortedD, sortedI] = sort(dists);
            I(di,:) = sortedI(1:K)';
            D(di,:) = sortedD(1:K)';
        end
    end

    % Squared distances
    D2 = D .^ 2;
    D2(D2 == 0) = eps;

    % Shepard's weights using K-1 neighbors (K-th is normalizing reference)
    d_k = D2(:, K);  % farthest neighbor distance (per dest vertex)

    % Weight: ((d_k - d_j) / (d_k * d_j))^p for j = 1..K-1
    % The K-th neighbor gets weight 0 by construction
    wts = zeros(nDest, K);
    for j = 1:K-1
        num = d_k - D2(:,j);
        den = d_k .* D2(:,j);
        wts(:,j) = (num ./ den) .^ expDistance;
    end

    % Row-normalize
    rowSums = sum(wts, 2);
    rowSums(rowSums == 0) = 1;
    wts = wts ./ rowSums;

    % Build sparse matrix (use only first K-1 neighbors)
    nSrc = size(srcLoc, 1);
    rows = repmat((1:nDest)', 1, K-1);
    cols = I(:, 1:K-1);
    vals = wts(:, 1:K-1);

    W = sparse(rows(:), cols(:), vals(:), nDest, nSrc);
end
