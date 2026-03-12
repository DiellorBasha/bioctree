function result = eigenmodeFilter(subjectPath, opts)
%EIGENMODEFILTER  Eigenmode spectral graph filtering of MEG band data
%
%   result = eigenmodeFilter(subjectPath)
%   result = eigenmodeFilter(subjectPath, Name=Value)
%
%   Applies spatial spectral graph filters (wavelet filterbanks) to
%   eigenmode-projected MEG data.  For each time window the CWT band
%   signals are projected into eigenmodes, time-averaged, filtered at
%   every filterbank scale, and reconstructed to vertex space.  Windows
%   are averaged (Welch-like) to produce stable source maps.
%
%   Because eigenmode projections are precomputed, filtering reduces to
%   element-wise multiplication of coefficients by the kernel response
%   evaluated at each eigenvalue:
%
%     filtered(m) = h(lambda_m) * coeff(m)
%
%   GSPBox analogy:
%     gsp_design_mexican_hat  ->  bct.filter.design ("SpectralMexicanHat")
%     gsp_filter_analysis     ->  h(lambda_m) * coeffs(m,:)
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
%       Root analysis folder that contains group/fsaverage5.mat.
%   KernelName   : string  (default = "SpectralMexicanHat")
%       Spectral kernel registered in bct.kernel.dictionary.
%   NScales      : double  (default = 6)
%       Total number of filterbank scales (1 lowpass + N-1 bandpass).
%   WindowSec    : double  (default = 4)
%       Window length in seconds for data loading.
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
%     .srcPowerL    [nVertL x nScales x nBands]  |source maps|, LH
%     .srcPowerR    [nVertR x nScales x nBands]  |source maps|, RH
%     .avgSrcL      [nVertL x nScales x nBands]  signed source maps, LH
%     .avgSrcR      [nVertR x nScales x nBands]  signed source maps, RH
%     .filter       struct - filterbank metadata
%         .kernelName    string
%         .nScales       double
%         .scaleLabels   string array   ["lowpass","scale 1",...]
%         .scalesL       [1 x nBandpass] wavelet tau scales, LH
%         .scalesR       [1 x nBandpass] wavelet tau scales, RH
%         .allWeightsL   [nModesL x nScales] filter weight matrix, LH
%         .allWeightsR   [nModesR x nScales] filter weight matrix, RH
%         .eigenvaluesL  [nModesL x 1]
%         .eigenvaluesR  [nModesR x 1]
%         .FL            bct.filter.design struct, LH
%         .FR            bct.filter.design struct, RH
%     .meta         struct - acquisition / processing metadata
%         .subjectPath   string
%         .bandNames     string array
%         .nBands        double
%         .windowSec     double
%         .overlapSec    double
%         .nWindows      double
%         .nVertL        double
%         .nVertR        double
%         .nModesL       double
%         .nModesR       double
%         .sfreq         double
%         .nSamples      double
%         .createdAt     datetime
%
%   See also buildEigenProjection, makeWindowedDatastore, bct.filter.design

    arguments
        subjectPath  (1,1) string {mustBeFolder}
        opts.AnalysisRoot (1,1) string = ""
        opts.KernelName   (1,1) string = "SpectralMexicanHat"
        opts.NScales      (1,1) double {mustBePositive, mustBeInteger} = 6
        opts.WindowSec    (1,1) double {mustBePositive} = 4
        opts.OverlapSec   (1,1) double {mustBeNonnegative} = 2
        opts.BandNames    (1,:) string = ["delta","theta","alpha","beta","gamma1"]
        opts.SavePath     (1,1) string = ""
        opts.Verbose      (1,1) logical = true
    end

    % ---- Resolve analysis root (default: parent of subjectPath) ----
    if opts.AnalysisRoot == ""
        opts.AnalysisRoot = string(fileparts(char(subjectPath)));
    end

    kernelName = opts.KernelName;
    nScales    = opts.NScales;
    bandNames  = opts.BandNames;
    nBands     = numel(bandNames);
    nBandpass  = nScales - 1;

    if opts.Verbose
        fprintf('=== eigenmodeFilter ===\n');
        fprintf('Subject : %s\n', subjectPath);
        fprintf('Bands   : %s\n', join(bandNames, ", "));
        fprintf('Kernel  : %s  (%d scales)\n', kernelName, nScales);
    end

    %% Load subject data & fsaverage5 eigenvectors
    provenance = load(fullfile(subjectPath, "provenance.mat")).provenance;
    eigen = load(fullfile(subjectPath, "eigen.mat")).eigen;

    fsav = load(fullfile(opts.AnalysisRoot, "group", "fsaverage5.mat"));
    U_lh = fsav.fsaverage5.lh.eigen.eigenvectors.value;   % [nVertL x nModesL]
    U_rh = fsav.fsaverage5.rh.eigen.eigenvectors.value;   % [nVertR x nModesR]

    if opts.Verbose
        fprintf('Eigen   : lh [%d x %d],  rh [%d x %d]\n', ...
            size(eigen.lh.imagingKernel), size(eigen.rh.imagingKernel));
        fprintf('Verts   : lh %d,  rh %d\n', size(U_lh, 1), size(U_rh, 1));
        fprintf('Signal  : %d samples at %.0f Hz (%.1f s)\n', ...
            provenance.nSamples, provenance.sfreq, ...
            provenance.nSamples / provenance.sfreq);
    end

    %% Windowed datastore
    [segDs, winTbl] = makeWindowedDatastore( ...
        fullfile(subjectPath, "bands.mat"), provenance.sfreq, ...
        provenance.nSamples, ...
        WindowSec=opts.WindowSec, OverlapSec=opts.OverlapSec);

    nWindows = height(winTbl);

    if opts.Verbose
        fprintf('Windows : %d x %.0f s  (%.0f%% overlap)\n', ...
            nWindows, opts.WindowSec, opts.OverlapSec / opts.WindowSec * 100);
    end

    %% Design spectral filterbank
    scalesL = logScales(eigen.lh.eigenvalues, nBandpass);
    scalesR = logScales(eigen.rh.eigenvalues, nBandpass);

    FL = bct.filter.design(eigen.lh.eigenvalues, kernelName, "tau", scalesL);
    FR = bct.filter.design(eigen.rh.eigenvalues, kernelName, "tau", scalesR);

    allWeightsL = [makeLowpass(eigen.lh.eigenvalues), FL.weights];  % [nModes x nScales]
    allWeightsR = [makeLowpass(eigen.rh.eigenvalues), FR.weights];

    if opts.Verbose
        fprintf('Filter  : LH [%d x %d],  RH [%d x %d]  (incl. lowpass)\n', ...
            size(allWeightsL), size(allWeightsR));
    end

    %% Main loop: project -> time-average -> filter -> reconstruct
    %
    %  Key identity:  mean(U*(w.*C), 2) = U*(w .* mean(C,2))
    %  Reduces nScales*nBands large multiplies to 1 per hemisphere.

    nVertL  = size(U_lh, 1);
    nVertR  = size(U_rh, 1);
    nModesL = size(allWeightsL, 1);
    nModesR = size(allWeightsR, 1);
    sumSrcL = zeros(nVertL, nScales, nBands);
    sumSrcR = zeros(nVertR, nScales, nBands);

    reset(segDs);
    winCount = 0;

    while hasdata(segDs)
        w = read(segDs);
        winCount = winCount + 1;

        [nCh, winSamp, ~] = size(w.X);

        % Reshape all bands into columns: [nCh x (winSamp * nBands)]
        Xflat = reshape(w.X, nCh, []);

        % Project once for all bands: [nModes x (winSamp*nBands)]
        coeffsLflat = eigen.lh.imagingKernel * Xflat;
        coeffsRflat = eigen.rh.imagingKernel * Xflat;

        % Time-average coefficients per band: [nModes x nBands]
        meanCL = squeeze(mean(reshape(coeffsLflat, nModesL, winSamp, nBands), 2));
        meanCR = squeeze(mean(reshape(coeffsRflat, nModesR, winSamp, nBands), 2));

        % Build filtered matrix: [nModes x (nScales * nBands)]
        filtL = zeros(nModesL, nScales * nBands);
        filtR = zeros(nModesR, nScales * nBands);
        for b = 1:nBands
            cols = (b-1)*nScales + (1:nScales);
            filtL(:, cols) = allWeightsL .* meanCL(:, b);
            filtR(:, cols) = allWeightsR .* meanCR(:, b);
        end

        % ONE reconstruction multiply per hemisphere
        srcAllL = U_lh * filtL;    % [nVertL x nScales*nBands]
        srcAllR = U_rh * filtR;    % [nVertR x nScales*nBands]

        % Reshape and accumulate
        sumSrcL = sumSrcL + reshape(srcAllL, nVertL, nScales, nBands);
        sumSrcR = sumSrcR + reshape(srcAllR, nVertR, nScales, nBands);

        if opts.Verbose
            fprintf('  Window %3d / %d  (%.1f-%.1f s)\n', ...
                winCount, nWindows, w.tStartSec, w.tStopSec);
        end
    end

    avgSrcL = sumSrcL / winCount;   % [nVertL x nScales x nBands]
    avgSrcR = sumSrcR / winCount;   % [nVertR x nScales x nBands]

    srcPowerL = abs(avgSrcL);       % [nVertL x nScales x nBands]
    srcPowerR = abs(avgSrcR);       % [nVertR x nScales x nBands]

    if opts.Verbose
        fprintf('Done: %d windows.  Source maps: LH [%s],  RH [%s]\n', ...
            winCount, join(string(size(avgSrcL)), 'x'), ...
            join(string(size(avgSrcR)), 'x'));
    end

    %% Assemble result struct
    scaleLabels = ["lowpass", compose("scale %d", 1:nBandpass)];

    result.srcPowerL = srcPowerL;
    result.srcPowerR = srcPowerR;
    result.avgSrcL   = avgSrcL;
    result.avgSrcR   = avgSrcR;

    result.filter.kernelName   = kernelName;
    result.filter.nScales      = nScales;
    result.filter.scaleLabels  = scaleLabels;
    result.filter.scalesL      = scalesL;
    result.filter.scalesR      = scalesR;
    result.filter.allWeightsL  = allWeightsL;
    result.filter.allWeightsR  = allWeightsR;
    result.filter.eigenvaluesL = eigen.lh.eigenvalues;
    result.filter.eigenvaluesR = eigen.rh.eigenvalues;
    result.filter.FL           = FL;
    result.filter.FR           = FR;

    result.meta.subjectPath = subjectPath;
    result.meta.bandNames   = bandNames;
    result.meta.nBands      = nBands;
    result.meta.windowSec   = opts.WindowSec;
    result.meta.overlapSec  = opts.OverlapSec;
    result.meta.nWindows    = winCount;
    result.meta.nVertL      = nVertL;
    result.meta.nVertR      = nVertR;
    result.meta.nModesL     = nModesL;
    result.meta.nModesR     = nModesR;
    result.meta.sfreq       = provenance.sfreq;
    result.meta.nSamples    = provenance.nSamples;
    result.meta.createdAt   = datetime("now");

    %% Optional save
    if opts.SavePath ~= ""
        saveDir = fileparts(opts.SavePath);
        if saveDir ~= "" && ~isfolder(saveDir)
            mkdir(saveDir);
        end
        save(opts.SavePath, '-struct', 'result', '-v7.3');
        if opts.Verbose
            fprintf('Saved -> %s\n', opts.SavePath);
        end
    end
end

%% ================================================================
%  LOCAL FUNCTIONS
%% ================================================================

function scales = logScales(eigenvalues, N)
%LOGSCALES  Log-spaced wavelet scales (GSPBox gsp_wlog_scales convention)
%   lmin = lmax / lpfactor (lpfactor = 20).  Bandpass wavelets tile
%   [lmax/20, lmax].  A separate lowpass covers lambda near 0.
    lpfactor = 20;
    t1 = 1;  t2 = 2;
    lmax = max(eigenvalues);
    lmin = lmax / lpfactor;
    smin = t1 / lmax;
    smax = t2 / lmin;
    scales = exp(linspace(log(smax), log(smin), N));
end

function w = makeLowpass(eigenvalues)
%MAKELOWPASS  Exponential low-pass complementary to Mexican hat bank
%   h(lambda) = 1.2 * exp(-1) * exp(-(lambda / (0.4 * lmin))^4)
%   lmin = lmax / 20,  matching GSPBox gsp_design_mexican_hat gl().
    lpfactor = 20;
    lmax = max(eigenvalues);
    lmin = lmax / lpfactor;
    lminfac = 0.4 * lmin;
    w = 1.2 * exp(-1) * exp(-(eigenvalues / lminfac).^4);
end
