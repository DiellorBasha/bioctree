function [QK, info] = buildEigenmodeProjectionMatrix(meta, K, destSphereL, destSphereR, zarrPathL, zarrPathR, opts)
%BUILDEIGENMODEPROJECTIONMATRIX  Pre-compose sensor → eigenmode projection.
%
%   [QK, info] = buildEigenmodeProjectionMatrix(meta, K, destSphL, destSphR, zarrL, zarrR)
%   [QK, info] = buildEigenmodeProjectionMatrix(..., Name=Value)
%
%   Composes the full linear chain
%
%       QK = U' * M * W * K                   (per hemisphere)
%
%   into a single dense matrix that maps sensor data directly to eigenmode
%   coefficients:
%
%       c(t) = QK * sensorData(:,t)           [k × 1]
%
%   Dimensions per hemisphere:
%       K  : [nSources × nChannels]            imaging kernel
%       W  : [nDest    × nSources]  sparse     sphere interpolation
%       M  : [nDest    × nDest]     sparse     FEM mass matrix
%       U  : [nDest    × k]                    Laplace–Beltrami eigenmodes
%       QK : [k        × nChannels]            pre-composed result
%
% ---- Mathematical note ----
%
%   The current pipeline applies the Hilbert envelope (a per-vertex
%   nonlinearity) before eigenmode analysis:
%
%       src = WK * s        →  env = |H{src}|    →  c = U'M * env
%
%   This function bypasses the Hilbert step:
%
%       c = U'M * WK * s  =  QK * s
%
%   For a narrowband signal (e.g. one CWT band), the two approaches yield
%   closely related eigenmode power spectra:
%
%     • SIGNED power  ⟨|c_k|²⟩  captures the coherent oscillatory power
%       at spatial scale k.  Vertices whose phases align constructively
%       add up; out-of-phase vertices cancel (phase-sensitive).
%
%     • ENVELOPE power  ⟨|c_k^{env}|²⟩  captures how much amplitude
%       modulation lives at spatial scale k, disregarding phase.
%
%   The signed approach is:
%     (a) sufficient for ranking which spatial scales carry the most power,
%     (b) more informative (reveals spatial phase coherence),
%     (c) vastly more efficient — single [k × nChan] multiply per window,
%         no vertex-space intermediate, no Hilbert transform.
%
%   Under the narrowband approximation  src_i(t) ≈ a_i(t)·cos(ω₀t+φ_i):
%
%       ⟨c_k²⟩_T  ≈  ½ · ⟨|∑_i q_{ki} a_i(t) e^{jφ_i(t)}|²⟩_T
%
%   which equals half of the envelope power when phases are spatially
%   uniform, and is smaller when phases vary across the manifold.
%
% ---- Inputs ----
%
%   meta         Source mapping / provenance struct (needs Reg.Sphere.Vertices
%                and Atlas or surfaceVertices for hemisphere splitting).
%
%   K            Imaging kernel, [nSources × nChannels].
%
%   destSphereL  [nDestL × 3]  left-hemisphere destination sphere.reg
%                coordinates (e.g. fsaverage5 lh.sphere.reg).
%
%   destSphereR  [nDestR × 3]  right-hemisphere destination sphere.reg
%                coordinates.
%
%   zarrPathL    Path to left-hemisphere zarr store containing
%                manifold/eigenmodes/{eigenvalues,eigenvectors} and
%                manifold/operators/mass/{row,col,data}.
%
%   zarrPathR    Path to right-hemisphere zarr store.
%
% ---- Name-Value Arguments ----
%
%   NumModes      Number of eigenmodes per hemisphere (default: all
%                 available in the zarr store).
%
%   NbNeighbors   Number of Shepard's nearest neighbors for sphere
%                 interpolation (default: 8, matching Brainstorm).
%
%   ExpDistance    Distance exponent for Shepard's weights (default: 2).
%
%   Verbose       Print diagnostics (default: true).
%
% ---- Outputs ----
%
%   QK   Struct with fields:
%          .lh     [kL × nChan]  left hemisphere projection matrix
%          .rh     [kR × nChan]  right hemisphere projection matrix
%          .full   [kTotal × nChan]  vertically stacked [lh; rh]
%
%   info Struct with metadata:
%          .lambdaL, .lambdaR    eigenvalues [k × 1]
%          .lambdaFull           concatenated [kL+kR × 1]
%          .kL, .kR, .kTotal     mode counts
%          .nDestL, .nDestR      destination vertex counts
%          .nChannels            number of sensor channels
%          .projInfo             output of buildProjectionMatrix
%
% ---- Usage example ----
%
%   % Build once per subject:
%   [QK, info] = buildEigenmodeProjectionMatrix( ...
%       meta, K, destSphL, destSphR, zarrL, zarrR, NumModes=1000);
%
%   % Apply to any sensor-space band:
%   cL = QK.lh * bandCWT;    % [kL × T] eigenmode coefficients
%   cR = QK.rh * bandCWT;    % [kR × T]
%
%   % Eigenmode power spectrum:
%   powerL = mean(cL.^2, 2);   % [kL × 1]
%   powerR = mean(cR.^2, 2);   % [kR × 1]
%
% See also: buildProjectionMatrix, buildSpectralProjection, readBandMatrix

    arguments
        meta          (1,1) struct
        K             (:,:) double
        destSphereL   (:,3) double
        destSphereR   (:,3) double
        zarrPathL     (1,1) string
        zarrPathR     (1,1) string
        opts.NumModes (1,1) double {mustBePositive, mustBeInteger} = Inf
        opts.NbNeighbors (1,1) double {mustBePositive, mustBeInteger} = 8
        opts.ExpDistance  (1,1) double {mustBePositive}               = 2
        opts.Verbose     (1,1) logical                               = true
    end

    nChan = size(K, 2);
    if opts.Verbose
        fprintf('buildEigenmodeProjectionMatrix:\n');
        fprintf('  Imaging kernel: [%d × %d]\n', size(K,1), size(K,2));
    end

    %% 1. Sphere interpolation  W: [nDest × nSrc]
    if opts.Verbose, fprintf('  Building sphere interpolation W...\n'); end
    [W, projInfo] = buildProjectionMatrix(meta, destSphereL, destSphereR, ...
        NbNeighbors=opts.NbNeighbors, ExpDistance=opts.ExpDistance, ...
        Verbose=opts.Verbose);

    nDestL = size(destSphereL, 1);
    nDestR = size(destSphereR, 1);

    %% 2. Compose  WK = W * K  and split hemispheres
    if opts.Verbose, fprintf('  Composing WK = W * K  [%d × %d]...\n', ...
            nDestL + nDestR, nChan); end
    WK = W * K;                          % [nDestTotal × nChan]
    WK_L = WK(1:nDestL, :);             % [nDestL × nChan]
    WK_R = WK(nDestL+1:end, :);         % [nDestR × nChan]
    clear WK W;  % free memory

    %% 3. Read eigenmodes and mass from zarr (direct, no cache)
    if opts.Verbose, fprintf('  Reading eigenmodes and mass from zarr...\n'); end
    hemis  = struct('lh', zarrPathL, 'rh', zarrPathR);
    hNames = ["lh", "rh"];
    WK_hemi = {WK_L, WK_R};
    nDest   = [nDestL, nDestR];

    lambdas = cell(1, 2);
    QK_hemi = cell(1, 2);
    kModes  = zeros(1, 2);

    for hi = 1:2
        h  = hNames(hi);
        zp = hemis.(h);

        % --- Eigenvalues [kAvail × 1] ---
        eigenPath = fullfile("manifold", "eigenmodes");
        lambda = double(bct.file.zarr.readArray(zp, ...
            fullfile(eigenPath, "eigenvalues")));
        lambda = lambda(:);

        % --- Eigenvectors [nDest × kAvail] ---
        U = double(bct.file.zarr.readArray(zp, ...
            fullfile(eigenPath, "eigenvectors")));

        kAvail = numel(lambda);
        k = min(opts.NumModes, kAvail);
        lambda = lambda(1:k);
        U = U(:, 1:k);

        % --- Mass matrix from COO sparse ---
        M = readCOO(zp, fullfile("manifold", "operators", "mass"));

        % Validate dimensions
        assert(size(U, 1) == nDest(hi), ...
            'Eigenvector rows (%d) ≠ destination vertices (%d) for %s.', ...
            size(U, 1), nDest(hi), h);
        assert(size(M, 1) == nDest(hi), ...
            'Mass matrix rows (%d) ≠ destination vertices (%d) for %s.', ...
            size(M, 1), nDest(hi), h);

        % --- Compose QK = U' * M * WK  [k × nChan] ---
        Q = U' * M;              % [k × nDest]  (eigenmode analysis operator)
        QK_hemi{hi} = Q * WK_hemi{hi};  % [k × nChan]  (sensor → eigenmode)

        lambdas{hi} = lambda;
        kModes(hi)  = k;

        if opts.Verbose
            fprintf('    %s: %d modes (of %d avail), mass nnz=%d, QK [%d × %d]\n', ...
                h, k, kAvail, nnz(M), size(QK_hemi{hi}));
        end
    end

    %% 4. Pack outputs
    QK = struct();
    QK.lh   = QK_hemi{1};                        % [kL × nChan]
    QK.rh   = QK_hemi{2};                        % [kR × nChan]
    QK.full = [QK_hemi{1}; QK_hemi{2}];          % [kTotal × nChan]

    info = struct();
    info.lambdaL     = lambdas{1};
    info.lambdaR     = lambdas{2};
    info.lambdaFull  = [lambdas{1}; lambdas{2}];
    info.kL          = kModes(1);
    info.kR          = kModes(2);
    info.kTotal      = sum(kModes);
    info.nDestL      = nDestL;
    info.nDestR      = nDestR;
    info.nChannels   = nChan;
    info.projInfo    = projInfo;

    if opts.Verbose
        fprintf('  Done: QK.lh [%d × %d], QK.rh [%d × %d], QK.full [%d × %d]\n', ...
            size(QK.lh), size(QK.rh), size(QK.full));
    end
end


%% ========================================================================
%  LOCAL FUNCTIONS
%  ========================================================================

function S = readCOO(zarrPath, groupRelPath)
%READCOO Read a COO-format sparse matrix from zarr.
%   Reads row/col/data sub-arrays and .zattrs for shape.
%   Zarr indices are 0-based → converted to 1-based.

    rowInd = double(bct.file.zarr.readArray(zarrPath, fullfile(groupRelPath, "row")));
    colInd = double(bct.file.zarr.readArray(zarrPath, fullfile(groupRelPath, "col")));
    vals   = double(bct.file.zarr.readArray(zarrPath, fullfile(groupRelPath, "data")));

    attrs = bct.file.zarr.readAttrs(zarrPath, groupRelPath);
    if isfield(attrs, 'shape')
        nRows = attrs.shape(1);
        nCols = attrs.shape(2);
    else
        nRows = max(rowInd) + 1;
        nCols = max(colInd) + 1;
    end

    S = sparse(rowInd(:) + 1, colInd(:) + 1, vals(:), nRows, nCols);
end
