%% eigenmode_power_spectrum.m
%  Per-band eigenmode power spectrum for a single subject on fsaverage5.
%
%  Uses buildEigenmodeProjectionMatrix to pre-compose
%
%       QK = U' * M * W * K       [kTotal × nChannels]
%
%  which maps sensor CWT data directly to eigenmode coefficients in one
%  matrix multiply — no vertex-space intermediate, no Hilbert transform.
%
%  Data loading:
%    All CWT bands are pre-loaded in bulk from the raw CWT datastore
%    (cwt/data/).  Each channel file stores [nSamples × nBands], so a
%    single pass through the datastore yields the full 3-D tensor
%    [nSamples × nBands × nChannels].  Per-band sensor matrices are then
%    extracted by column indexing — zero additional I/O.
%
%  Pipeline:
%    1. Pre-load all CWT data  →  allCWT [nSamples × nBands × nChannels]
%    2. Build QK once
%    3. Per band:
%       a. bandCWT = allCWT(:, bi, :)' → [nChan × nSamples]
%       b. c(t) = QK * bandCWT(:,t)   → eigenmode coefficients
%       c. power_k = mean(c_k²)       → eigenmode power spectrum
%    4. Save per-band results and summary figure
%
%  Joint hemispheres:
%    The two hemispheres are disconnected surfaces, so the combined
%    Laplace–Beltrami operator is block-diagonal: L = blkdiag(L_L, L_R).
%    Its eigenmodes are the union of each hemisphere's eigenmodes, padded
%    with zeros on the other side.  Therefore QK.full = [QK.lh; QK.rh]
%    produces eigenmode coefficients that are identical to computing each
%    hemisphere separately.  We use the joint matrix for code simplicity
%    and a single matmul, while retaining per-hemisphere eigenvalue vectors
%    for analysis.
%
%  See also: buildEigenmodeProjectionMatrix, buildProjectionMatrix,
%            readBandMatrix, plotFilterbank

%% ========================================================================
%  SECTION 1 — CONFIGURATION
%  ========================================================================

analysisRoot = "Z:\brainstorm_protocols_analysis\TutorialOmega2";
groupPath    = fullfile(analysisRoot, "group");
fs5root      = "C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf";

% Subject to analyze
subjectId = "sub-0002";

% Eigenmodes
numModes = 1000;  % per hemisphere → 2000 total

% Zarr stores for fsaverage5 eigendata
zarrPathL = fullfile(groupPath, "lhfsaverage.zarr");
zarrPathR = fullfile(groupPath, "rhfsaverage.zarr");

% Destination sphere.reg files
[destSphL, ~] = mne_read_surface(fullfile(fs5root, 'lh.sphere.reg'));
[destSphR, ~] = mne_read_surface(fullfile(fs5root, 'rh.sphere.reg'));

% Vertex scale for wavelength conversion (FreeSurfer surfaces in m → mm)
vertexScale = 1e3;

%% ========================================================================
%  SECTION 2 — LOAD PROVENANCE & PRE-LOAD ALL CWT DATA
%  ========================================================================

outPath  = fullfile(analysisRoot, subjectId);
cwtPath  = fullfile(outPath, "cwt");

fprintf('\n============================================================\n');
fprintf('Subject: %s\n', subjectId);
fprintf('============================================================\n');

% ---- 2a. Load subject provenance and imaging kernel ----
meta  = load(fullfile(outPath, "provenance.mat")).provenance;
sfreq = meta.sfreq;
K     = load(fullfile(outPath, "ImagingKernel.mat")).K;  % [nSrc × nChan]

fprintf('  K: [%d × %d], sfreq = %.0f Hz\n', size(K), sfreq);

% ---- 2b. Load CWT provenance (band names, ordering) ----
cwtMeta   = load(fullfile(cwtPath, "provenance.mat"));
bandNames = cwtMeta.provenance.bandNames;       % e.g. ["delta","theta","alpha","beta","gamma1"]
nBands    = numel(bandNames);
fprintf('  CWT bands (%d): %s\n', nBands, strjoin(bandNames, ", "));

% ---- 2c. Pre-load all CWT data from raw datastore ----
%   Each channel file in cwt/data/ stores [nSamples × nBands].
%   We read all 270 files in one pass and stack into a 3-D array:
%       allCWT  [nSamples × nBands × nChannels]
%       chanOrder [nChannels × 1] string — channel ordering as read

fprintf('  Loading all CWT data ...');
tLoad = tic;

cwtStore  = signalDatastore(fullfile(cwtPath, "data"), SampleRate=sfreq);
nChan     = 0;
allCWT    = [];
chanOrder = strings(0, 1);

while hasdata(cwtStore)
    [data, info] = read(cwtStore);          % [nSamples × nBands]
    nChan = nChan + 1;
    if isempty(allCWT)
        [nSamples, nBCheck] = size(data);
        assert(nBCheck == nBands, ...
            'Channel %s has %d columns, expected %d bands', ...
            info.SignalVariableNames, nBCheck, nBands);
        allCWT = zeros(nSamples, nBands, cwtMeta.provenance.nChannels, 'like', data);
    end
    allCWT(:, :, nChan) = data;
    chanOrder(nChan, 1) = string(info.SignalVariableNames);
end

tTotal = nSamples / sfreq;
fprintf(' done (%.1f s)\n', toc(tLoad));
fprintf('  allCWT: [%d samples × %d bands × %d channels] (%.1f s recording)\n', ...
    nSamples, nBands, nChan, tTotal);

%% ========================================================================
%  SECTION 3 — BUILD EIGENMODE PROJECTION MATRIX
%  ========================================================================

[QK, eigenInfo] = buildEigenmodeProjectionMatrix( ...
    meta, K, destSphL, destSphR, zarrPathL, zarrPathR, ...
    NumModes=numModes);

kL      = eigenInfo.kL;
kR      = eigenInfo.kR;
kTotal  = eigenInfo.kTotal;
lambdaL = eigenInfo.lambdaL;
lambdaR = eigenInfo.lambdaR;
lambdaAll = eigenInfo.lambdaFull;

fprintf('  QK: [%d × %d]  (kL=%d, kR=%d)\n', size(QK.full), kL, kR);

% ---- Joint eigenvalue ordering (same for all bands) ----
%   Merge L and R eigenvalues and sort to get a single ordered spectrum.
%   sortIdx maps positions in the concatenated [powerL; powerR] vector
%   to their rank in the joint eigenvalue ordering.
lambdaJoint = [lambdaL; lambdaR];
[lambdaSorted, sortIdx] = sort(lambdaJoint);
wavelengthSorted = zeros(kTotal, 1);
wavelengthSorted(lambdaSorted > 0) = 2*pi ./ sqrt(lambdaSorted(lambdaSorted > 0));
wavelengthSorted_mm = wavelengthSorted * vertexScale;

fprintf('  Joint eigenvalue range: [%.4g, %.4g]\n', lambdaSorted(2), lambdaSorted(end));
fprintf('  Wavelength range: [%.1f, %.1f] mm\n', ...
    wavelengthSorted_mm(find(wavelengthSorted_mm > 0, 1, 'last')), ...
    wavelengthSorted_mm(find(wavelengthSorted_mm > 0, 1, 'first')));

%% ========================================================================
%  SECTION 4 — PER-BAND EIGENMODE POWER ANALYSIS
%  ========================================================================

allResults = struct();

for bi = 1:nBands
    bandName = bandNames(bi);
    fprintf('  ---- %s (band %d/%d) ----\n', bandName, bi, nBands);

    % Extract band column from pre-loaded tensor → [nChan × nSamples]
    bandCWT = squeeze(allCWT(:, bi, :))';   % [nChan × nSamples]

    fprintf('    bandCWT: [%d × %d]\n', size(bandCWT));

    % ---- Eigenmode coefficients (single matmul) ----
    %   c = QK.full * bandCWT   →  [kTotal × nSamples]
    %   First kL rows = left hemi modes, next kR = right hemi modes
    tStart = tic;
    cAll = QK.full * bandCWT;       % [kTotal × nSamples]
    cL   = cAll(1:kL, :);           % [kL × nSamples]
    cR   = cAll(kL+1:end, :);       % [kR × nSamples]

    % ---- Power spectrum (mean squared coefficient per mode) ----
    powerL = mean(cL.^2, 2);        % [kL × 1]
    powerR = mean(cR.^2, 2);        % [kR × 1]
    powerAll = [powerL; powerR];     % [kTotal × 1]

    % ---- Joint sorted spectrum (L+R merged by eigenvalue) ----
    powerSorted = powerAll(sortIdx);       % [kTotal × 1] sorted by eigenvalue
    powerNorm   = powerSorted / sum(powerSorted);  % normalized to sum = 1

    % Mean amplitude (for additional diagnostics)
    meanL = mean(abs(cL), 2);
    meanR = mean(abs(cR), 2);

    elapsed = toc(tStart);
    fprintf('    Eigenmode power computed in %.1f s\n', elapsed);

    % ---- Wavelength mapping ----
    wavelengthL = zeros(kL, 1);
    wavelengthR = zeros(kR, 1);
    wavelengthL(lambdaL > 0) = 2*pi ./ sqrt(lambdaL(lambdaL > 0));
    wavelengthR(lambdaR > 0) = 2*pi ./ sqrt(lambdaR(lambdaR > 0));
    wavelengthL_mm = wavelengthL * vertexScale;
    wavelengthR_mm = wavelengthR * vertexScale;

    % ---- Cumulative power ----
    cumPowerL = cumsum(powerL) / sum(powerL) * 100;
    cumPowerR = cumsum(powerR) / sum(powerR) * 100;
    k90L = find(cumPowerL >= 90, 1);
    k90R = find(cumPowerR >= 90, 1);
    k95L = find(cumPowerL >= 95, 1);
    k95R = find(cumPowerR >= 95, 1);

    fprintf('    90%% power: L=%d modes, R=%d modes\n', k90L, k90R);
    fprintf('    95%% power: L=%d modes, R=%d modes\n', k95L, k95R);

    % ---- Joint cumulative power (sorted L+R) ----
    cumPowerJoint = cumsum(powerSorted) / sum(powerSorted) * 100;
    k90 = find(cumPowerJoint >= 90, 1);
    k95 = find(cumPowerJoint >= 95, 1);
    fprintf('    90%% power (joint): %d modes\n', k90);
    fprintf('    95%% power (joint): %d modes\n', k95);

    % ---- Pack results ----
    res = struct();
    res.subjectId      = subjectId;
    res.bandName       = bandName;
    res.sfreq          = sfreq;
    res.nSamples       = nSamples;
    res.kL             = kL;
    res.kR             = kR;
    res.kTotal         = kTotal;
    res.powerL         = powerL;
    res.powerR         = powerR;
    res.powerAll       = powerAll;
    res.meanL          = meanL;
    res.meanR          = meanR;
    res.lambdaL        = lambdaL;
    res.lambdaR        = lambdaR;
    res.lambdaAll      = lambdaAll;
    res.wavelengthL_mm = wavelengthL_mm;
    res.wavelengthR_mm = wavelengthR_mm;
    res.cumPowerL      = cumPowerL;
    res.cumPowerR      = cumPowerR;
    res.k90L           = k90L;
    res.k90R           = k90R;
    res.k95L           = k95L;
    res.k95R           = k95R;
    res.lambdaSorted      = lambdaSorted;
    res.powerSorted       = powerSorted;
    res.powerNorm         = powerNorm;
    res.wavelengthSorted_mm = wavelengthSorted_mm;
    res.cumPowerJoint     = cumPowerJoint;
    res.k90               = k90;
    res.k95               = k95;
    res.sortIdx           = sortIdx;
    res.chanOrder      = chanOrder;
    res.createdOn      = string(datetime("now"));

    % Save per-band result
    saveFile = fullfile(outPath, sprintf("eigenpower_%s.mat", bandName));
    save(saveFile, '-struct', 'res', '-v7.3');
    fprintf('    Saved: %s\n', saveFile);

    % Store for cross-band plotting
    allResults.(bandName) = res;
end

fprintf('\n============================================================\n');
fprintf('All bands complete for %s.\n', subjectId);
fprintf('============================================================\n');

%% ========================================================================
%  SECTION 5 — PLOT: ALL BANDS OVERLAY (COMBINED L+R EIGENSPECTRUM)
%  ========================================================================

bandColors = struct( ...
    'delta',  [0.2 0.4 0.8], ...
    'theta',  [0.0 0.7 0.7], ...
    'alpha',  [0.0 0.6 0.2], ...
    'beta',   [0.9 0.6 0.0], ...
    'gamma1', [0.8 0.1 0.1]);

figure('Name', sprintf('Eigenpower — %s', subjectId), ...
    'Position', [80 80 1600 900], 'Color', 'w');

% ---- 5a. MAIN: Normalized power histogram vs sorted mode index ----
%   Stairs plot gives histogram aesthetic with multiple overlaid bands.
%   Three vertical lines mark modes 10, 100, 1000 with wavelength labels.
subplot(2, 3, [1 2]); hold on;
for bi = 1:nBands
    b = bandNames(bi);
    r = allResults.(b);
    stairs(1:kTotal, r.powerNorm, '-', ...
        'Color', bandColors.(b), 'LineWidth', 1.3);
end
set(gca, 'YScale', 'log');

% Wavelength markers at eigenmodes 10, 100, 1000
markerModes = [10, 100, 1000];
for mi = 1:numel(markerModes)
    mk = markerModes(mi);
    if mk <= kTotal
        wl = wavelengthSorted_mm(mk);
        xline(mk, '--', sprintf('k=%d  (%.0f mm)', mk, wl), ...
            'Color', [0.3 0.3 0.3], 'LineWidth', 1.2, ...
            'LabelOrientation', 'horizontal', ...
            'LabelVerticalAlignment', 'top', 'FontSize', 9);
    end
end

xlabel('Sorted eigenmode index k');
ylabel('Normalized power');
title('Eigenmode Power Spectrum (L+R combined)');
legend(bandNames, 'Location', 'northeast');
grid on; set(gca, 'FontSize', 10);

% ---- 5b. Power vs eigenvalue (log-log, combined L+R) ----
subplot(2, 3, 3); hold on;
for bi = 1:nBands
    b = bandNames(bi);
    r = allResults.(b);
    loglog(lambdaSorted(2:end), r.powerSorted(2:end), '.', ...
        'Color', bandColors.(b), 'MarkerSize', 3);
end
xlabel('\lambda_k'); ylabel('Power \langle c_k^2 \rangle');
title('Power vs Eigenvalue (L+R)');
legend(bandNames, 'Location', 'southwest');
grid on; set(gca, 'FontSize', 10);

% ---- 5c. Cumulative power (combined L+R) ----
subplot(2, 3, 4); hold on;
for bi = 1:nBands
    b = bandNames(bi);
    r = allResults.(b);
    plot(1:kTotal, r.cumPowerJoint, '-', ...
        'Color', bandColors.(b), 'LineWidth', 1.5);
end
yline(90, 'k--', '90%', 'LineWidth', 1, 'LabelHorizontalAlignment', 'left');
yline(95, 'k:', '95%', 'LineWidth', 1, 'LabelHorizontalAlignment', 'left');
xlabel('Number of modes'); ylabel('Cumulative power (%)');
title('Cumulative Power (L+R)');
legend(bandNames, 'Location', 'southeast');
grid on; set(gca, 'FontSize', 10);

% ---- 5d. Power vs wavelength (combined L+R, mm) ----
subplot(2, 3, 5); hold on;
for bi = 1:nBands
    b = bandNames(bi);
    r = allResults.(b);
    semilogx(wavelengthSorted_mm(2:end), r.powerSorted(2:end), '.', ...
        'Color', bandColors.(b), 'MarkerSize', 3);
end
xlabel('Wavelength (mm)'); ylabel('Power \langle c_k^2 \rangle');
title('Power vs Wavelength (L+R)');
set(gca, 'XDir', 'reverse');
legend(bandNames, 'Location', 'northeast');
grid on; set(gca, 'FontSize', 10);

% ---- 5e. Log-binned power spectrum (combined L+R) ----
subplot(2, 3, 6); hold on;
nBins = 50;
for bi = 1:nBands
    b = bandNames(bi);
    r = allResults.(b);
    logBinEdges = logspace( ...
        log10(max(lambdaSorted(2), 1e-6)), log10(max(lambdaSorted)), nBins + 1);
    binPower = zeros(nBins, 1);
    binCenter = zeros(nBins, 1);
    binCount = zeros(nBins, 1);
    for bni = 1:nBins
        mask = lambdaSorted >= logBinEdges(bni) & lambdaSorted < logBinEdges(bni+1);
        if any(mask)
            binPower(bni) = mean(r.powerSorted(mask));
            binCenter(bni) = exp(mean(log(lambdaSorted(mask))));
            binCount(bni) = sum(mask);
        end
    end
    valid = binCount > 0;
    loglog(binCenter(valid), binPower(valid), '-o', ...
        'Color', bandColors.(b), 'LineWidth', 1.2, ...
        'MarkerSize', 3, 'MarkerFaceColor', bandColors.(b));
end
xlabel('\lambda_k (log-binned)'); ylabel('Mean power');
title('Log-Binned Spectrum (L+R)');
legend(bandNames, 'Location', 'southwest');
grid on; set(gca, 'FontSize', 10);

sgtitle(sprintf('Eigenmode Power Spectrum — %s (%d modes/hemi, %d total)', ...
    subjectId, numModes, kTotal), 'FontSize', 14, 'FontWeight', 'bold');