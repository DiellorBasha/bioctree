function result = eigenmodeWaveFilter_function(subjectPath, opts)
%EIGENMODEWAVEFILTER_FUNCTION  JTV wave filter in eigenmode space
%
%   result = eigenmodeWaveFilter_function(subjectPath)
%   result = eigenmodeWaveFilter_function(subjectPath, Name=Value)
%
%   Applies a Joint Time-Vertex (JTV) wave filter to eigenmode-projected
%   MEG band data.  For a single window the CWT band signals are projected
%   into eigenmodes, then each eigenmode coefficient is modulated by the
%   wave kernel:
%
%     g(lambda_m, t) = cos( t * acos(1 - alpha^2 * lambda_m / (2*lmax)) )
%
%   where t is the integer sample index and alpha controls propagation
%   speed on the manifold.  High-eigenvalue modes oscillate faster.
%   Energy is conserved (cos^2 redistributes but does not decay).
%
%   Damped wave mode (optional):
%     g(lambda_m, t) = exp(-beta * t / fs) * cos(omega_m * t)
%
%   This adds an exponential temporal envelope that damps ALL modes
%   uniformly over time, replicating GSPBox's gsp_jtv_design_damped_wave.
%
%   Constraint:  alpha <= 2  (for acos validity).
%
%   GSPBox analogy:
%     gsp_jtv_design_wave         ->  undamped wave kernel
%     gsp_jtv_design_damped_wave  ->  exp(-beta*t/fs) * wave kernel
%
%   Prerequisite: run buildEigenProjection() once per subject.
%
%   Inputs
%   ------
%   subjectPath : char | string
%       Path to subject folder containing provenance.mat, eigen.mat,
%       and bands.mat.
%
%   Name-Value Options
%   ------------------
%   AnalysisRoot : string  (default = parent of subjectPath)
%       Root analysis folder containing group/fsaverage5.mat.
%   Alphas       : double vector  (default = [0.05, 0.1, 0.2, 0.4])
%       Wave velocity parameters.  Must be in (0, 2].
%   Beta         : double  (default = 0)
%       Temporal damping factor.  0 = undamped wave.
%       Positive values add exp(-beta*t/fs) envelope (damped wave).
%   BandToFilter : double  (default = 3, i.e. alpha band)
%       Index into BandNames selecting which frequency band to filter.
%   WindowIdx    : double  (default = 1)
%       Which window to load (1-based).
%   WindowSec    : double  (default = 4)
%       Window length in seconds.
%   OverlapSec   : double  (default = 2)
%       Overlap between consecutive windows in seconds.
%   BandNames    : string  (default = ["delta","theta","alpha","beta","gamma1"])
%       Names of CWT frequency bands stored in bands.mat.
%   SavePath     : string  (default = "")
%       If non-empty, saves result struct to this .mat file (v7.3).
%   Verbose      : logical (default = true)
%       Print progress messages.
%
%   Output
%   ------
%   result : struct with fields
%     .filtSrcL     {nAlphas x 1} cell of [nVertL x winSamp]  filtered source, LH
%     .filtSrcR     {nAlphas x 1} cell of [nVertR x winSamp]  filtered source, RH
%     .srcOrigL     [nVertL x winSamp]  unfiltered source, LH
%     .srcOrigR     [nVertR x winSamp]  unfiltered source, RH
%     .coeffsL      [nModesL x winSamp x nBands]  eigenmode coefficients, LH
%     .coeffsR      [nModesR x winSamp x nBands]  eigenmode coefficients, RH
%     .kernelL      {nAlphas x 1} cell of [nModesL x winSamp]  kernel matrices, LH
%     .kernelR      {nAlphas x 1} cell of [nModesR x winSamp]  kernel matrices, RH
%     .omegaL       {nAlphas x 1} cell of [nModesL x 1]  angular freqs per mode, LH
%     .omegaR       {nAlphas x 1} cell of [nModesR x 1]  angular freqs per mode, RH
%     .filter       struct - filter metadata
%         .alphas        double vector
%         .beta          double
%         .isDamped      logical
%         .eigenvaluesL  [nModesL x 1]
%         .eigenvaluesR  [nModesR x 1]
%         .lmaxL         double
%         .lmaxR         double
%     .meta         struct - acquisition / processing metadata
%         .subjectPath   string
%         .bandNames     string array
%         .bandToFilter  double
%         .bandFiltered  string
%         .nBands        double
%         .windowIdx     double
%         .windowSec     double
%         .overlapSec    double
%         .nVertL        double
%         .nVertR        double
%         .nModesL       double
%         .nModesR       double
%         .sfreq         double
%         .winSamp       double
%         .tAxis         [1 x winSamp]  time within window (s)
%         .tWin          [1 x winSamp]  absolute time (s)
%         .tStartSec     double
%         .tStopSec      double
%         .createdAt     datetime
%     .fsaverage5   struct - surface geometry
%         .lh.vertices   [nVertL x 3]
%         .lh.faces      [nFacesL x 3]
%         .rh.vertices   [nVertR x 3]
%         .rh.faces      [nFacesR x 3]
%
%   See also buildEigenProjection, makeWindowedDatastore,
%            plotWaveKernel, plotWaveResults

    arguments
        subjectPath  (1,1) string {mustBeFolder}
        opts.AnalysisRoot  (1,1) string = ""
        opts.Alphas        (1,:) double {mustBePositive} = [0.05, 0.1, 0.2, 0.4]
        opts.Beta          (1,1) double {mustBeNonnegative} = 0
        opts.BandToFilter  (1,1) double {mustBePositive, mustBeInteger} = 3
        opts.WindowIdx     (1,1) double {mustBePositive, mustBeInteger} = 1
        opts.WindowSec     (1,1) double {mustBePositive} = 4
        opts.OverlapSec    (1,1) double {mustBeNonnegative} = 2
        opts.BandNames     (1,:) string = ["delta","theta","alpha","beta","gamma1"]
        opts.SavePath      (1,1) string = ""
        opts.Verbose       (1,1) logical = true
    end

    %% Validate
    assert(all(opts.Alphas <= 2), ...
        'eigenmodeWaveFilter:invalidAlpha', ...
        'All alpha values must be <= 2 for acos validity.');

    alphas  = opts.Alphas;
    beta    = opts.Beta;
    nAlphas = numel(alphas);
    isDamped = beta > 0;

    bandNames    = opts.BandNames;
    nBands       = numel(bandNames);
    bandToFilter = opts.BandToFilter;

    assert(bandToFilter <= nBands, ...
        'eigenmodeWaveFilter:invalidBand', ...
        'BandToFilter (%d) exceeds number of bands (%d).', bandToFilter, nBands);

    %% Resolve analysis root
    if opts.AnalysisRoot == ""
        opts.AnalysisRoot = string(fileparts(char(subjectPath)));
    end

    if isDamped
        filterLabel = "Damped Wave";
    else
        filterLabel = "Wave";
    end

    if opts.Verbose
        fprintf('=== JTV %s Filter (Single Window) ===\n', filterLabel);
        fprintf('Subject:    %s\n', subjectPath);
        fprintf('Alphas:     %s\n', join(string(alphas), ", "));
        if isDamped
            fprintf('Beta:       %g  (damping factor)\n', beta);
        end
        fprintf('Band:       %s  (index %d)\n', bandNames(bandToFilter), bandToFilter);
    end

    %% Load subject data & fsaverage5 eigenvectors
    meta  = load(fullfile(subjectPath, "provenance.mat")).provenance;
    eigen = load(fullfile(subjectPath, "eigen.mat")).eigen;

    fsav = load(fullfile(opts.AnalysisRoot, "group", "fsaverage5.mat"));
    U_lh = fsav.fsaverage5.lh.eigen.eigenvectors.value;   % [nVertL x nModesL]
    U_rh = fsav.fsaverage5.rh.eigen.eigenvectors.value;   % [nVertR x nModesR]

    lambdaL = eigen.lh.eigenvalues;   % [nModesL x 1]
    lambdaR = eigen.rh.eigenvalues;   % [nModesR x 1]
    lmaxL   = max(lambdaL);
    lmaxR   = max(lambdaR);

    nVertL  = size(U_lh, 1);
    nVertR  = size(U_rh, 1);
    nModesL = numel(lambdaL);
    nModesR = numel(lambdaR);

    if opts.Verbose
        fprintf('Eigen:      lh [%d modes],  rh [%d modes]\n', nModesL, nModesR);
        fprintf('Verts:      lh %d,  rh %d\n', nVertL, nVertR);
        fprintf('lmax:       lh %.4f,  rh %.4f\n', lmaxL, lmaxR);
    end

    %% Load single window
    [segDs, ~] = makeWindowedDatastore( ...
        fullfile(subjectPath, "bands.mat"), meta.sfreq, meta.nSamples, ...
        WindowSec=opts.WindowSec, OverlapSec=opts.OverlapSec);

    reset(segDs);
    for k = 1:opts.WindowIdx
        w = read(segDs);
    end

    [nCh, winSamp, ~] = size(w.X);
    tAxis    = (0:winSamp-1) / meta.sfreq;   % time within window [s]
    tSamples = 0:winSamp-1;                   % integer sample indices
    tWin     = w.tStartSec + tAxis;           % absolute time [s]

    if opts.Verbose
        fprintf('Window %d:   %.1f–%.1f s  (%d samples at %.0f Hz)\n', ...
            opts.WindowIdx, w.tStartSec, w.tStopSec, winSamp, meta.sfreq);
    end

    %% Project to eigenmodes — all bands
    Xflat = reshape(w.X, nCh, []);                             % [nCh x winSamp*nBands]
    coeffsLflat = eigen.lh.imagingKernel * Xflat;              % [nModesL x winSamp*nBands]
    coeffsRflat = eigen.rh.imagingKernel * Xflat;              % [nModesR x winSamp*nBands]

    coeffsL = reshape(coeffsLflat, nModesL, winSamp, nBands);  % [nModes x winSamp x nBands]
    coeffsR = reshape(coeffsRflat, nModesR, winSamp, nBands);

    if opts.Verbose
        fprintf('Coeffs:     LH [%d x %d x %d],  RH [%d x %d x %d]\n', ...
            size(coeffsL), size(coeffsR));
    end

    %% Build wave kernel and apply
    %
    %  Undamped:   g(m,t) = cos(omega_m * t)
    %  Damped:     g(m,t) = exp(-beta * t / fs) * cos(omega_m * t)

    if opts.Verbose
        fprintf('\nApplying JTV %s filter for band: %s\n', filterLabel, bandNames(bandToFilter));
    end

    % Temporal damping envelope (uniform across modes)
    if isDamped
        dampEnvelope = exp(-beta * tSamples / meta.sfreq);   % [1 x winSamp]
    else
        dampEnvelope = ones(1, winSamp);
    end

    % Pre-build kernel matrices [nModes x winSamp] — one per alpha per hemisphere
    kernelL = cell(nAlphas, 1);
    kernelR = cell(nAlphas, 1);
    omegaL  = cell(nAlphas, 1);
    omegaR  = cell(nAlphas, 1);

    for j = 1:nAlphas
        % Angular frequency per eigenmode
        omegaL{j} = acos(1 - alphas(j)^2 * lambdaL / (2*lmaxL));  % [nModesL x 1]
        omegaR{j} = acos(1 - alphas(j)^2 * lambdaR / (2*lmaxR));  % [nModesR x 1]

        % Wave kernel (optionally damped)
        kernelL{j} = cos(omegaL{j} * tSamples) .* dampEnvelope;   % [nModesL x winSamp]
        kernelR{j} = cos(omegaR{j} * tSamples) .* dampEnvelope;   % [nModesR x winSamp]
    end

    % Extract coefficients for the selected band
    cL = coeffsL(:, :, bandToFilter);   % [nModesL x winSamp]
    cR = coeffsR(:, :, bandToFilter);   % [nModesR x winSamp]

    % Apply filter and reconstruct — per alpha
    filtSrcL = cell(nAlphas, 1);
    filtSrcR = cell(nAlphas, 1);

    for j = 1:nAlphas
        if opts.Verbose
            fprintf('  alpha = %g ...', alphas(j));
        end
        filtSrcL{j} = U_lh * (kernelL{j} .* cL);   % [nVertL x winSamp]
        filtSrcR{j} = U_rh * (kernelR{j} .* cR);   % [nVertR x winSamp]
        if opts.Verbose
            fprintf('  done\n');
        end
    end

    % Unfiltered source for comparison
    srcOrigL = U_lh * cL;   % [nVertL x winSamp]
    srcOrigR = U_rh * cR;   % [nVertR x winSamp]

    if opts.Verbose
        fprintf('Reconstruction complete.\n');
    end

    %% Assemble result struct
    result = struct();

    % Filtered & unfiltered source maps
    result.filtSrcL  = filtSrcL;
    result.filtSrcR  = filtSrcR;
    result.srcOrigL  = srcOrigL;
    result.srcOrigR  = srcOrigR;

    % Eigenmode coefficients (all bands)
    result.coeffsL = coeffsL;
    result.coeffsR = coeffsR;

    % Kernel matrices and angular frequencies
    result.kernelL = kernelL;
    result.kernelR = kernelR;
    result.omegaL  = omegaL;
    result.omegaR  = omegaR;

    % Filter metadata
    result.filter.alphas       = alphas;
    result.filter.beta         = beta;
    result.filter.isDamped     = isDamped;
    result.filter.eigenvaluesL = lambdaL;
    result.filter.eigenvaluesR = lambdaR;
    result.filter.lmaxL        = lmaxL;
    result.filter.lmaxR        = lmaxR;

    % Processing metadata
    result.meta.subjectPath   = string(subjectPath);
    result.meta.bandNames     = bandNames;
    result.meta.bandToFilter  = bandToFilter;
    result.meta.bandFiltered  = bandNames(bandToFilter);
    result.meta.nBands        = nBands;
    result.meta.windowIdx     = opts.WindowIdx;
    result.meta.windowSec     = opts.WindowSec;
    result.meta.overlapSec    = opts.OverlapSec;
    result.meta.nVertL        = nVertL;
    result.meta.nVertR        = nVertR;
    result.meta.nModesL       = nModesL;
    result.meta.nModesR       = nModesR;
    result.meta.sfreq         = meta.sfreq;
    result.meta.winSamp       = winSamp;
    result.meta.tAxis         = tAxis;
    result.meta.tWin          = tWin;
    result.meta.tStartSec     = w.tStartSec;
    result.meta.tStopSec      = w.tStopSec;
    result.meta.createdAt     = datetime("now");

    % Surface geometry (for plotting)
    result.fsaverage5.lh.vertices = fsav.fsaverage5.lh.vertices;
    result.fsaverage5.lh.faces    = fsav.fsaverage5.lh.faces;
    result.fsaverage5.rh.vertices = fsav.fsaverage5.rh.vertices;
    result.fsaverage5.rh.faces    = fsav.fsaverage5.rh.faces;

    %% Optional save
    if opts.SavePath ~= ""
        if opts.Verbose
            fprintf('Saving to %s ...\n', opts.SavePath);
        end
        save(opts.SavePath, '-struct', 'result', '-v7.3');
        if opts.Verbose
            fprintf('Saved.\n');
        end
    end

    if opts.Verbose
        fprintf('=== %s filter complete ===\n', filterLabel);
    end

end
