function [projected, t, projInfo] = projectToFsaverage(bandMatrix, sm, fsAvgRoot, opts)
%PROJECTTOFSAVERAGE Project source-space band data to fsaverage surface.
%
%   [projected, t, projInfo] = projectToFsaverage(bandMatrix, sm, fsAvgRoot)
%   [projected, t, projInfo] = projectToFsaverage(..., Name=Value)
%
%   Combines source mapping (K * sensorData) and surface projection
%   (W * sourceData) in a single function. Projects per-band sensor-space
%   matrices to a FreeSurfer fsaverage surface (e.g. fsaverage5).
%
%   Inputs:
%       bandMatrix - [nChannels × nSamples] sensor-space data for one band
%                    (e.g. amplitude.alpha from readHilbertBands), OR
%                    a struct where each field is [nChannels × nSamples]
%                    (e.g. the full amplitude struct with .delta, .alpha, etc.)
%       sm         - sourceMapping struct from loadBrainstorm, OR provenance
%                    struct from writeSourceDatastore. Must contain:
%                      .Reg.Sphere.Vertices — FreeSurfer sphere registration
%                      .Atlas               — with Structures atlas
%                    Optionally:
%                      .ImagingKernel       — if not providing K separately
%       fsAvgRoot  - path to the fsaverage surf/ directory, e.g.
%                    "C:\...\fsaverage5\surf". Must contain:
%                      lh.sphere.reg, rh.sphere.reg
%
%   Name-Value Arguments:
%       K            - [nSources × nChannels] imaging kernel. If not
%                      provided, uses sm.ImagingKernel.
%       W            - precomputed projection matrix from
%                      buildProjectionMatrix. If provided, skips rebuilding.
%       Sfreq        - sampling frequency for time vector (default 1)
%       NbNeighbors  - Shepard's neighbors (default 8)
%       Verbose      - print progress (default true)
%
%   Outputs:
%       projected - If bandMatrix is a matrix:
%                     [nDestTotal × nSamples] projected data
%                   If bandMatrix is a struct (multi-band):
%                     struct with same fields, each [nDestTotal × nSamples]
%       t         - [nSamples × 1] time vector (0-based)
%       projInfo  - struct with:
%                     .W — the projection matrix (cache for reuse)
%                     .K — the imaging kernel used
%                     .projDetails — from buildProjectionMatrix
%                     .nSrcVertices, .nDestVertices
%                     .fsAvgRoot
%
%   Usage patterns:
%       % --- Single band ---
%       alphaFs5 = projectToFsaverage(amplitude.alpha, sm, fs5root, K=K2);
%
%       % --- All bands at once ---
%       projAmps = projectToFsaverage(amplitude, sm, fs5root, K=K2);
%       % projAmps.delta, .theta, .alpha, ... each [20484 × T]
%
%       % --- Precompute W for reuse across bands ---
%       [~, ~, pInfo] = projectToFsaverage(amplitude.alpha, sm, fs5root, K=K2);
%       W = pInfo.W;
%       WK = W * K2;  % precompute combined operator
%       betaFs5 = WK * amplitude.beta;
%       gammaFs5 = WK * amplitude.gamma1;
%
%       % --- Using saved provenance (no Brainstorm needed) ---
%       meta = load(fullfile(outPath, "provenance.mat"));
%       K2 = load(fullfile(outPath, "ImagingKernel.mat")).K;
%       alphaFs5 = projectToFsaverage(amplitude.alpha, meta.provenance, fs5root, K=K2);
%
%   See also: buildProjectionMatrix, readHilbertBands, readBandMatrix,
%             mne_read_surface, bst_shepards

    arguments
        bandMatrix
        sm          (1,1) struct
        fsAvgRoot   (1,1) string
        opts.K                                                       = []
        opts.W                                                       = []
        opts.Sfreq       (1,1) double {mustBePositive}               = 1
        opts.NbNeighbors (1,1) double {mustBePositive, mustBeInteger} = 8
        opts.Verbose     (1,1) logical                               = true
    end

    % ---- Resolve imaging kernel ----
    K = opts.K;
    if isempty(K)
        if isfield(sm, 'ImagingKernel') && ~isempty(sm.ImagingKernel)
            K = sm.ImagingKernel;
        else
            error('projectToFsaverage:NoKernel', ...
                'No imaging kernel provided. Pass K=... or ensure sm has .ImagingKernel.');
        end
    end

    % ---- Build or reuse projection matrix W ----
    if ~isempty(opts.W)
        W = opts.W;
        projDetails = struct('nSrcTotal', size(W,2), 'nDestTotal', size(W,1));
        if opts.Verbose
            fprintf('projectToFsaverage: using precomputed W [%d × %d]\n', size(W,1), size(W,2));
        end
    else
        % Load fsaverage sphere.reg files
        sphLPath = fullfile(fsAvgRoot, 'lh.sphere.reg');
        sphRPath = fullfile(fsAvgRoot, 'rh.sphere.reg');

        if ~isfile(sphLPath) || ~isfile(sphRPath)
            error('projectToFsaverage:NoSphereReg', ...
                'sphere.reg files not found in %s.\nExpected: lh.sphere.reg, rh.sphere.reg', ...
                fsAvgRoot);
        end

        [destSphL, ~] = mne_read_surface(char(sphLPath));
        [destSphR, ~] = mne_read_surface(char(sphRPath));

        [W, projDetails] = buildProjectionMatrix(sm, destSphL, destSphR, ...
            NbNeighbors=opts.NbNeighbors, Verbose=opts.Verbose);
    end

    % ---- Validate dimensions ----
    nSources  = size(K, 1);
    nChannels = size(K, 2);

    if size(W, 2) ~= nSources
        error('projectToFsaverage:DimMismatch', ...
            'W has %d columns but K has %d rows (sources). Dimensions must match.', ...
            size(W,2), nSources);
    end

    % ---- Project ----
    if isstruct(bandMatrix)
        % Multi-band: project each field
        bandNames = string(fieldnames(bandMatrix));
        projected = struct();

        for bi = 1:numel(bandNames)
            bn = bandNames(bi);
            mat = bandMatrix.(bn);  % [nChannels × nSamples]

            if size(mat, 1) ~= nChannels
                error('projectToFsaverage:BandDimMismatch', ...
                    'Band "%s" has %d rows but K expects %d channels.', ...
                    bn, size(mat,1), nChannels);
            end

            if opts.Verbose
                fprintf('projectToFsaverage: projecting %s [%d × %d]...\n', ...
                    bn, size(mat,1), size(mat,2));
            end

            projected.(bn) = W * (K * mat);  % [nDest × T]
        end

        nSamples = size(bandMatrix.(bandNames(1)), 2);
    else
        % Single matrix
        if size(bandMatrix, 1) ~= nChannels
            error('projectToFsaverage:DimMismatch', ...
                'bandMatrix has %d rows but K expects %d channels.', ...
                size(bandMatrix,1), nChannels);
        end

        if opts.Verbose
            fprintf('projectToFsaverage: projecting [%d × %d]...\n', ...
                size(bandMatrix,1), size(bandMatrix,2));
        end

        projected = W * (K * bandMatrix);  % [nDest × T]
        nSamples = size(bandMatrix, 2);
    end

    % ---- Time vector ----
    t = (0:nSamples-1)' / opts.Sfreq;

    % ---- Info struct ----
    projInfo = struct();
    projInfo.W             = W;
    projInfo.K             = K;
    projInfo.projDetails   = projDetails;
    projInfo.nSrcVertices  = nSources;
    projInfo.nDestVertices = size(W, 1);
    projInfo.nChannels     = nChannels;
    projInfo.fsAvgRoot     = fsAvgRoot;

    if opts.Verbose
        fprintf('projectToFsaverage: complete → [%d × %d]\n', ...
            size(W,1), nSamples);
    end
end
