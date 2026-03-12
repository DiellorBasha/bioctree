%% eigenmodeGroupAnalysis — Aggregate per-subject eigenmode results
%
%  Loads eigenmodeAnalysis.mat from each subject directory and produces
%  group-level summaries:
%
%    1) Grand-average eigenmode PSD spectrogram (modes × frequency)
%    2) Per-band eigenmode power profiles (signed + envelope)
%    3) Inter-subject variability in eigenmode spectra
%    4) Band-specific eigenmode concentration analysis
%    5) Cross-subject correlation of eigenmode power profiles
%
%  All subjects are in fsaverage5 eigenmode space (registered), so
%  mode indices are directly comparable across subjects.
%
%  Prerequisite: run eigenmodeAnalysis(..., Save=true) for each subject.

%% 1) Configuration

analysisRoot = "Z:\brainstorm_protocols_analysis\TutorialOmega2";

% Visualization options
useLogScale   = false;    % log-scale eigenvalue axis and PSD colormap
useBinning    = true;     % bin eigenmodes for spectrogram (smoother) vs raw
modesPerBin   = 10;       % modes per bin (only used when useBinning=true)
smoothN       = 20;       % smoothing window for rank-based line plots

% Subjects to include — auto-detect or specify manually
subjectNames = findSubjects(analysisRoot);
% Or manually:  subjectNames = ["sub-0002", "sub-0004", "sub-0007"];

nSubjects = numel(subjectNames);
fprintf('=== eigenmodeGroupAnalysis ===\n');
fprintf('Root:      %s\n', analysisRoot);
fprintf('Subjects:  %d  [%s]\n', nSubjects, join(subjectNames, ", "));

%% 2) Load all per-subject results

allResults = cell(nSubjects, 1);
validMask  = true(nSubjects, 1);

for s = 1:nSubjects
    matFile = fullfile(analysisRoot, subjectNames(s), "eigenmodeAnalysis.mat");
    if ~isfile(matFile)
        warning('Missing: %s — skipping.', matFile);
        validMask(s) = false;
        continue;
    end
    tmp = load(matFile);
    allResults{s} = tmp.results;
    fprintf('  Loaded %s  (%d freq windows, %d band windows)\n', ...
        subjectNames(s), ...
        allResults{s}.frequency.nWindows, ...
        allResults{s}.signedBand.nWindows);
end

% Keep only valid subjects
subjectNames = subjectNames(validMask);
allResults   = allResults(validMask);
nSubjects    = numel(allResults);

if nSubjects == 0
    error('eigenmodeGroupAnalysis:noData', 'No valid subjects found.');
end

fprintf('\nValid subjects: %d\n', nSubjects);

% Reference dimensions from first subject
ref = allResults{1};
freqs     = ref.frequency.freqs;
nFreqs    = numel(freqs);
bandNames = ref.signedBand.bandNames;
nBands    = numel(bandNames);
nModesL   = numel(ref.eigenvalues.lh);
nModesR   = numel(ref.eigenvalues.rh);
nJoint    = nModesL + nModesR;

fprintf('Modes:     LH %d, RH %d  (joint %d)\n', nModesL, nModesR, nJoint);
fprintf('Freqs:     %d bins (0–%.1f Hz, df=%.2f Hz)\n', nFreqs, freqs(end), freqs(2)-freqs(1));
fprintf('Bands:     %s\n', join(bandNames, ", "));

%% 2b) Load filter results (Mexican Hat & Heat)
%
%  Each filter file contains vertex-space source maps [nVert × nScales × nBands]
%  produced by eigenmodeFilter() with different spectral kernels.
%  We extract compact summaries: mean vertex power per scale per band.

filterTypes  = ["mxhat", "heat"];
filterLabels = ["Mexican Hat", "Heat"];
nFilterTypes = numel(filterTypes);

filterGroup = struct();

for fi = 1:nFilterTypes
    fTag  = filterTypes(fi);
    fFile = sprintf("filter_%s.mat", fTag);

    % Check availability across subjects
    hasFilter = false(nSubjects, 1);
    for s = 1:nSubjects
        hasFilter(s) = isfile(fullfile(analysisRoot, subjectNames(s), fFile));
    end
    nFilterSubj = sum(hasFilter);

    if nFilterSubj == 0
        fprintf('Filter %-12s: not found — skipping.\n', filterLabels(fi));
        filterGroup.(fTag).available = false;
        continue;
    end
    fprintf('Filter %-12s: %d / %d subjects\n', filterLabels(fi), nFilterSubj, nSubjects);

    % Load first available for dimensions & metadata
    firstIdx  = find(hasFilter, 1);
    refFilter = load(fullfile(analysisRoot, subjectNames(firstIdx), fFile));
    nScalesF     = refFilter.filter.nScales;
    scaleLabelsF = refFilter.filter.scaleLabels;
    nBandsF      = refFilter.meta.nBands;
    bandNamesF   = refFilter.meta.bandNames;

    % Pre-allocate: per-subject scale-band mean power [nScales × nBands × nSubjects]
    scalePowerL = NaN(nScalesF, nBandsF, nSubjects);
    scalePowerR = NaN(nScalesF, nBandsF, nSubjects);

    for s = 1:nSubjects
        if ~hasFilter(s), continue; end
        fData = load(fullfile(analysisRoot, subjectNames(s), fFile));

        % Mean vertex power per scale per band
        scalePowerL(:, :, s) = squeeze(mean(fData.srcPowerL, 1));  % [nScales × nBands]
        scalePowerR(:, :, s) = squeeze(mean(fData.srcPowerR, 1));
        fprintf('  %s  [%d scales × %d bands]\n', subjectNames(s), nScalesF, nBandsF);
    end

    % Store in filterGroup
    filterGroup.(fTag).available    = true;
    filterGroup.(fTag).hasFilter    = hasFilter;
    filterGroup.(fTag).nSubjects    = nFilterSubj;
    filterGroup.(fTag).scalePowerL  = scalePowerL;
    filterGroup.(fTag).scalePowerR  = scalePowerR;
    filterGroup.(fTag).scaleLabels  = scaleLabelsF;
    filterGroup.(fTag).nScales      = nScalesF;
    filterGroup.(fTag).bandNames    = bandNamesF;
    filterGroup.(fTag).nBands       = nBandsF;
    filterGroup.(fTag).allWeightsL  = refFilter.filter.allWeightsL;
    filterGroup.(fTag).allWeightsR  = refFilter.filter.allWeightsR;
    filterGroup.(fTag).eigenvaluesL = refFilter.filter.eigenvaluesL;
    filterGroup.(fTag).eigenvaluesR = refFilter.filter.eigenvaluesR;
    filterGroup.(fTag).kernelName   = refFilter.filter.kernelName;
end

fprintf('\n');

%% 3) Stack per-subject data into group arrays

% Frequency analysis — joint PSD [nJoint × nFreqs × nSubjects]
groupJointPsd   = zeros(nJoint, nFreqs, nSubjects);
groupJointLambda = zeros(nJoint, nSubjects);

% Frequency analysis — binned PSD
nBins = numel(ref.frequency.binRankCenters);
groupBinnedPsd  = zeros(nBins, nFreqs, nSubjects);
groupBinLambda  = zeros(nBins, nSubjects);

% Per-hemisphere PSD [nModes × nFreqs × nSubjects]
groupPsdL = zeros(nModesL, nFreqs, nSubjects);
groupPsdR = zeros(nModesR, nFreqs, nSubjects);

% Band power — signed [nModes × nBands × nSubjects]
groupSignedL = zeros(nModesL, nBands, nSubjects);
groupSignedR = zeros(nModesR, nBands, nSubjects);

% Band power — envelope [nModes × nBands × nSubjects]
groupEnvL = zeros(nModesL, nBands, nSubjects);
groupEnvR = zeros(nModesR, nBands, nSubjects);

for s = 1:nSubjects
    r = allResults{s};

    % Joint PSD (already sorted by eigenvalue within each subject)
    groupJointPsd(:, :, s)   = r.frequency.jointPsd;
    groupJointLambda(:, s)   = r.frequency.jointLambda;

    % Binned PSD
    groupBinnedPsd(:, :, s)  = r.frequency.binnedPsd;
    groupBinLambda(:, s)     = r.frequency.binLambdaMean;

    % Per-hemisphere (sorted)
    groupPsdL(:, :, s) = r.frequency.sortedPsdL;
    groupPsdR(:, :, s) = r.frequency.sortedPsdR;

    % Band power — signed
    groupSignedL(:, :, s) = r.signedBand.avgPowerL;
    groupSignedR(:, :, s) = r.signedBand.avgPowerR;

    % Band power — envelope
    groupEnvL(:, :, s) = r.envelope.avgPowerL;
    groupEnvR(:, :, s) = r.envelope.avgPowerR;
end

fprintf('\nGroup arrays assembled.\n');

%% 3a) Per-subject PSD normalization
%
%  Normalize each subject's PSD by its total power so that every subject
%  contributes equally to the grand average.  Without this, subjects with
%  higher absolute power (due to noise floor, head position) dominate.
%
%  After normalization, PSD values represent relative spectral density
%  (proportion of total power at each mode–frequency bin).

normJointPsd  = zeros(size(groupJointPsd));
normPsdL      = zeros(size(groupPsdL));
normPsdR      = zeros(size(groupPsdR));

for s = 1:nSubjects
    totalPower = sum(groupJointPsd(:, :, s), 'all');
    if totalPower == 0, totalPower = 1; end
    normJointPsd(:, :, s) = groupJointPsd(:, :, s) / totalPower;
    normPsdL(:, :, s)     = groupPsdL(:, :, s) / totalPower;
    normPsdR(:, :, s)     = groupPsdR(:, :, s) / totalPower;
end

fprintf('PSD normalized: each subject divided by total power.\n');
fprintf('  Units: relative spectral density (proportion of total power)\n');

%% ================================================================
%  ANALYSIS & VISUALIZATION
%% ================================================================

%% 3b) Load fsaverage5 mesh & eigenmodes for wavelength and surface plots

fsav = load(fullfile(analysisRoot, "group", "fsaverage5.mat"));
V_lh = fsav.fsaverage5.lh.vertices;                      % [nVertL × 3]
F_lh = fsav.fsaverage5.lh.faces;                          % [nFacesL × 3]
U_lh = fsav.fsaverage5.lh.eigen.eigenvectors.value;       % [nVertL × nModesL]
U_rh = fsav.fsaverage5.rh.eigen.eigenvectors.value;       % [nVertR × nModesR]

% Grand-average eigenvalues per hemisphere (for wavelength)
grandLambdaL = mean(groupJointLambda(1:nModesL, :), 2);   % [nModesL × 1]

% Compute wavelengths for select eigenmodes
selectModes  = [20, 200, 500, 1000];
selectModes  = selectModes(selectModes <= nModesL);

% Build wavelength markers struct for plotEigenmodeSpectrogram
wlMarkers = struct('eigenvalue', {}, 'wavelength', {}, 'label', {}, 'rank', {});
for mi = 1:numel(selectModes)
    mIdx = selectModes(mi);
    lam  = grandLambdaL(mIdx);
    wl   = 2*pi / sqrt(max(lam, eps));   % mm (mesh units)
    wlMarkers(mi).eigenvalue  = lam;
    wlMarkers(mi).wavelength  = wl;
    wlMarkers(mi).rank        = mIdx;
    wlMarkers(mi).label       = sprintf('#%d  \\ell=%.0f mm', mIdx, wl);
    fprintf('  Mode %3d:  \\lambda=%.2f  wavelength=%.0f mm\n', mIdx, lam, wl);
end

%% 4) Grand-average eigenmode spectrogram (normalized PSD)
%
%  Y-axis = eigenvalue (or eigenmode index), full spectrum
%  X-axis = temporal frequency (Hz)
%  Uses per-subject normalized PSD (relative spectral density).
%  Delegates to plotEigenmodeSpectrogram() function.

bandBounds = [4 8 12 30];   % band boundary lines in Hz

% 4a) Standard orientation (freq on X, eigenvalue on Y) — normalized, dB
plotEigenmodeSpectrogram(normJointPsd, groupJointLambda, freqs, ...
    Binning=useBinning, ModesPerBin=modesPerBin, ...
    LogEigenvalue=useLogScale, CDataScale="dB", ...
    NSubjects=nSubjects, ...
    BandLines=bandBounds, WavelengthMarkers=wlMarkers, ...
    Title="Grand-Average Eigenmode PSD (normalized)");

% 4b) Transposed (eigenvalue on X, freq on Y) — normalized
plotEigenmodeSpectrogram(normJointPsd, groupJointLambda, freqs, ...
    Binning=useBinning, ModesPerBin=modesPerBin, ...
    LogEigenvalue=useLogScale, CDataScale="dB", ...
    NSubjects=nSubjects, Transpose=true, ...
    BandLines=bandBounds, WavelengthMarkers=wlMarkers, ...
    Title="Grand-Average Eigenmode PSD (normalized, transposed)");

% 4c) Rank-based Y-axis (matching eigenmodeFrequencyAnalysis §6)
plotEigenmodeSpectrogram(normJointPsd, groupJointLambda, freqs, ...
    Binning=false, CDataScale="dB", YAxis="rank", ...
    NSubjects=nSubjects, ...
    BandLines=bandBounds, WavelengthMarkers=wlMarkers, ...
    Title="Grand-Average Eigenmode PSD (rank)");

% 4d) Rank-based, binned (matching eigenmodeFrequencyAnalysis §7)
plotEigenmodeSpectrogram(normJointPsd, groupJointLambda, freqs, ...
    Binning=useBinning, ModesPerBin=modesPerBin, ...
    CDataScale="dB", YAxis="rank", ...
    NSubjects=nSubjects, ...
    BandLines=bandBounds, WavelengthMarkers=wlMarkers, ...
    Title="Grand-Average Eigenmode PSD (rank, binned)");

% 4e) z-score scaling (highlights relative spectral structure)
plotEigenmodeSpectrogram(normJointPsd, groupJointLambda, freqs, ...
    Binning=useBinning, ModesPerBin=modesPerBin, ...
    CDataScale="zscore", CLim=[-2 4], ...
    NSubjects=nSubjects, ...
    BandLines=bandBounds, WavelengthMarkers=wlMarkers, ...
    Title="Grand-Average Eigenmode PSD (z-score)");
%%

% 4b) Transposed (eigenvalue on X, freq on Y) — normalized
plotEigenmodeSpectrogram(normJointPsd, groupJointLambda, freqs, ...
    Binning=useBinning, ModesPerBin=20, ...
    LogEigenvalue=0, CDataScale="log10", ...
    YAxis="rank",...
     Transpose=true, ...
         BandLines=bandBounds, WavelengthMarkers=wlMarkers, ...
    NSubjects=nSubjects,  Title="Grand-Average Eigenmode PSD ");
colormap turbo
clim([-8 -3])

%%
% 4b) Transposed (eigenvalue on X, freq on Y) — normalized
fig=plotEigenmodeSpectrogram(normJointPsd, groupJointLambda, freqs, ...
    Binning=useBinning, ModesPerBin=20, ...
    LogEigenvalue=useLogScale, CDataScale="dB", ...
        YAxis="rank",...
    NSubjects=nSubjects,  Title="Grand-Average Eigenmode PSD ");

%%
colormap turbo
%%
clim([ 0.000067206963222458 0.000167206963222458])
%%


% 4b) Transposed (eigenvalue on X, freq on Y) — normalized
plotEigenmodeSpectrogram(normJointPsd, groupJointLambda, freqs, ...
    Binning=useBinning, ModesPerBin=20, ...
    LogEigenvalue=0, CDataScale="linear", ...
    YAxis="rank",...
    NSubjects=nSubjects,  Title="Grand-Average Eigenmode PSD ");
%%


% 4b) Transposed (eigenvalue on X, freq on Y) — normalized
plotEigenmodeSpectrogram(normJointPsd, groupJointLambda, freqs, ...
    Binning=useBinning, ModesPerBin=modesPerBin, ...
    LogEigenvalue=useLogScale, CDataScale="log10", ...
    NSubjects=nSubjects,  Title="Grand-Average Eigenmode PSD ");
%% 4f) Surface projection of select eigenmodes
%
%  Project eigenmodes at the selected ranks onto the fsaverage5 cortical
%  surface to visualize the spatial scale each eigenmode represents.

nSelect = numel(selectModes);
fig4f = figure('Name', 'Select Eigenmodes on Cortical Surface', ...
    'NumberTitle', 'off', 'Position', [50 50 400*nSelect 350]);
tiledlayout(1, nSelect, 'TileSpacing', 'compact', 'Padding', 'compact');

for mi = 1:nSelect
    mIdx = selectModes(mi);
    phi  = U_lh(:, mIdx);   % eigenmode vector on LH surface

    nexttile;
    trisurf(F_lh, V_lh(:,1), V_lh(:,2), V_lh(:,3), phi, ...
        'EdgeColor', 'none', 'FaceColor', 'interp');
    axis equal off;
    colormap(gca, seismicColormap(256));
    cLim = max(abs(phi));
    clim([-cLim cLim]);
    colorbar;
    lam = grandLambdaL(mIdx);
    wl  = 2*pi / sqrt(max(lam, eps));
    title(sprintf('Mode %d  (\\ell \\approx %.0f mm)', mIdx, wl));
    view([-90 10]);
    lighting gouraud;
    camlight headlight;
end

sgtitle('Select Eigenmodes — fsaverage5 LH', 'FontSize', 16, 'FontWeight', 'bold');
applyPlotDefaults(fig4f);

%% 5) Average eigenmode PSD — overlay per subject
%
%  Shows the total eigenmode power spectrum per subject to visualize
%  inter-subject variability.  Uses raw (un-normalized) PSD so that
%  absolute power differences between subjects are visible.

% Sum across all modes for each subject → sensor-level-like total PSD
totalPsdPerSubj = squeeze(sum(groupJointPsd, 1));   % [nFreqs × nSubjects]

figure('Name', 'Total Eigenmode PSD per Subject', 'NumberTitle', 'off', ...
    'Position', [100 100 700 400]);

co = lines(nSubjects);
hold on;
for s = 1:nSubjects
    plot(freqs, 10*log10(totalPsdPerSubj(:, s)), ...
        'Color', [co(s,:), 0.6], 'LineWidth', 1.0, ...
        'DisplayName', subjectNames(s));
end
% Grand average
grandTotal = mean(totalPsdPerSubj, 2);
plot(freqs, 10*log10(grandTotal), 'k-', 'LineWidth', 2.5, 'DisplayName', 'Grand Mean');
hold off;
xlabel('Frequency (Hz)');
ylabel('Total Power (dB, raw PSD)');
title('Total Eigenmode PSD  —  per subject + grand mean');
legend('Location', 'northeast', 'FontSize', 14);
applyPlotDefaults(gcf);
%%

plotBandPowerProfile(groupSignedL, groupSignedR, bandNames);

%% 6) Per-band eigenmode power profiles (grand average)
%
%  For each frequency band, plot mean eigenmode power vs eigenmode rank
%  across subjects.  LH and RH overlaid on a shared 1–nModes axis.
%  Shared Y-axis for cross-band comparison.

% Pre-compute global Y limits across all bands (per-hemi)
globalYmax_band = 0;
globalYmin_band = Inf;
for bi = 1:nBands
    for hData = {groupSignedL(:, bi, :), groupSignedR(:, bi, :)}
        hp = squeeze(hData{1});  % [nModes × nSubjects]
        sm = movmean(mean(hp, 2), smoothN);
        se = movmean(std(hp, 0, 2) / sqrt(nSubjects), smoothN);
        globalYmax_band = max(globalYmax_band, max(sm + se));
        globalYmin_band = min(globalYmin_band, min(sm - se));
    end
end
globalYmin_band = max(0, globalYmin_band);   % power is non-negative

figure('Name', 'Band Power vs Eigenmode Rank', 'NumberTitle', 'off', ...
    'Position', [100 100 900 600]);
tiledlayout(2, ceil(nBands/2), 'TileSpacing', 'compact', 'Padding', 'compact');

modeRank = (1:nModesL)';   % both hemis have the same number of modes

for bi = 1:nBands
    nexttile;

    % LH
    powerL = squeeze(groupSignedL(:, bi, :));   % [nModesL × nSubjects]
    meanL  = movmean(mean(powerL, 2), smoothN);
    semL   = movmean(std(powerL, 0, 2) / sqrt(nSubjects), smoothN);

    fill([modeRank; flipud(modeRank)], ...
         [meanL - semL; flipud(meanL + semL)], ...
         [0.7 0.7 1], 'EdgeColor', 'none', 'FaceAlpha', 0.4);
    hold on;
    plot(modeRank, meanL, 'b-', 'LineWidth', 1.5, 'DisplayName', 'LH');

    % RH
    powerR = squeeze(groupSignedR(:, bi, :));   % [nModesR × nSubjects]
    meanR  = movmean(mean(powerR, 2), smoothN);
    semR   = movmean(std(powerR, 0, 2) / sqrt(nSubjects), smoothN);

    fill([modeRank; flipud(modeRank)], ...
         [meanR - semR; flipud(meanR + semR)], ...
         [1 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.4);
    plot(modeRank, meanR, 'r-', 'LineWidth', 1.5, 'DisplayName', 'RH');
    hold off;

    xlabel('Eigenmode rank');
    ylabel('Power (a.u.)');
    title(bandNames(bi));
    legend('Location', 'best');
    xlim([1 nModesL]);
    ylim([globalYmin_band, globalYmax_band * 1.05]);
end
sgtitle(sprintf('Band Power vs Eigenmode Rank  (N = %d, signed band, smoothed %d)', ...
    nSubjects, smoothN), 'FontWeight', 'bold');
applyPlotDefaults(gcf);

%% 7) Eigenmode power concentration — which modes carry each band?
%
%  For each band, compute the cumulative fraction of total power
%  as you include more modes (sorted by power).
%  Steeper curve = more concentrated in fewer modes.

figure('Name', 'Eigenmode Power Concentration', 'NumberTitle', 'off', ...
    'Position', [100 100 600 450]);

co = lines(nBands);
hold on;
for bi = 1:nBands
    % Average across subjects
    jointPower = mean([groupSignedL(:, bi, :); groupSignedR(:, bi, :)], 3);  % [nJoint × 1]
    sortedPower = sort(jointPower, 'descend');
    cumFrac = cumsum(sortedPower) / sum(sortedPower);

    plot(1:nJoint, cumFrac, 'Color', co(bi,:), 'LineWidth', 1.5, ...
        'DisplayName', bandNames(bi));
end
hold off;
xlabel('Number of modes included (sorted by power)');
ylabel('Cumulative fraction of total power');
title(sprintf('Eigenmode Power Concentration  (N = %d)', nSubjects));
legend('Location', 'southeast');
applyPlotDefaults(gcf);
xlim([1 500]);
yline(0.5, '--k', '50%', 'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');
yline(0.9, '--k', '90%', 'LabelHorizontalAlignment', 'left', 'HandleVisibility', 'off');

%% 8) Per-band eigenmode power — inter-subject coefficient of variation
%
%  CV = std / mean across subjects, per mode.
%  Low CV = consistent across subjects; high CV = variable.

% Pre-compute global CV limits (per-hemi)
globalCVmax = 0;
for bi = 1:nBands
    for hData = {groupSignedL(:, bi, :), groupSignedR(:, bi, :)}
        hp = squeeze(hData{1});
        cv_ = std(hp, 0, 2) ./ max(mean(hp, 2), eps);
        globalCVmax = max(globalCVmax, max(movmean(cv_, 50)));
    end
end

figure('Name', 'Inter-Subject CV per Band', 'NumberTitle', 'off', ...
    'Position', [100 100 900 600]);
tiledlayout(2, ceil(nBands/2), 'TileSpacing', 'compact', 'Padding', 'compact');

modeRankCV = (1:nModesL)';

for bi = 1:nBands
    nexttile;

    % LH
    powerL = squeeze(groupSignedL(:, bi, :));
    cvL = std(powerL, 0, 2) ./ max(mean(powerL, 2), eps);
    plot(modeRankCV, movmean(cvL, 50), 'b-', 'LineWidth', 1.2, 'DisplayName', 'LH');
    hold on;

    % RH
    powerR = squeeze(groupSignedR(:, bi, :));
    cvR = std(powerR, 0, 2) ./ max(mean(powerR, 2), eps);
    plot(modeRankCV, movmean(cvR, 50), 'r-', 'LineWidth', 1.2, 'DisplayName', 'RH');
    hold off;

    xlabel('Eigenmode rank');
    ylabel('CV');
    title(bandNames(bi));
    legend('Location', 'best');
    xlim([1 nModesL]);
    ylim([0, globalCVmax * 1.05]);
end
sgtitle(sprintf('Inter-Subject Coefficient of Variation  (N = %d, smoothed 50)', ...
    nSubjects), 'FontWeight', 'bold');
applyPlotDefaults(gcf);

%% 9) Cross-subject correlation matrix of eigenmode power profiles
%
%  For each pair of subjects, compute Pearson correlation of their
%  eigenmode power profile (joint L+R) per band.
%  High correlation = similar spatial-scale organization.

figure('Name', 'Cross-Subject Correlation', 'NumberTitle', 'off', ...
    'Position', [100 100 300*nBands 300]);
tiledlayout(1, nBands, 'TileSpacing', 'compact', 'Padding', 'compact');

for bi = 1:nBands
    nexttile;
    jointPower = squeeze([groupSignedL(:, bi, :); groupSignedR(:, bi, :)]);  % [nJoint × nSubjects]
    R = corr(jointPower);   % [nSubjects × nSubjects]

    imagesc(R);
    caxis([0 1]);
    colormap(gca, hot(256));
    colorbar;
    axis equal tight;
    xticks(1:nSubjects);
    yticks(1:nSubjects);

    % Short labels
    shortLabels = extractAfter(subjectNames, "sub-");
    xticklabels(shortLabels);
    yticklabels(shortLabels);
    xtickangle(45);
    title(sprintf('%s  (mean r=%.2f)', bandNames(bi), ...
        mean(R(triu(true(nSubjects), 1)))));
end
sgtitle('Cross-Subject Eigenmode Power Correlation', ...
    'FontWeight', 'bold');
applyPlotDefaults(gcf);

%% 10) Signed vs Envelope comparison — grand average
%
%  Overlay the signed-band and envelope eigenmode power profiles
%  to see how much structure is in the instantaneous signal vs amplitude.

% Pre-compute global Y limits for signed vs envelope
globalYmax_se = 0;
for bi = 1:nBands
    sp = movmean(mean(squeeze([groupSignedL(:, bi, :); groupSignedR(:, bi, :)]), 2), smoothN);
    ep = movmean(mean(squeeze([groupEnvL(:, bi, :);    groupEnvR(:, bi, :)]),    2), smoothN);
    globalYmax_se = max(globalYmax_se, max([sp; ep]));
end

figure('Name', 'Signed vs Envelope Power', 'NumberTitle', 'off', ...
    'Position', [100 100 900 600]);
tiledlayout(2, ceil(nBands/2), 'TileSpacing', 'compact', 'Padding', 'compact');

for bi = 1:nBands
    nexttile;

    signedPower = mean(squeeze([groupSignedL(:, bi, :); groupSignedR(:, bi, :)]), 2);
    envPower    = mean(squeeze([groupEnvL(:, bi, :);    groupEnvR(:, bi, :)]),    2);

    plot(1:nJoint, movmean(signedPower, smoothN), 'b-', 'LineWidth', 1.5, ...
        'DisplayName', 'Signed');
    hold on;
    plot(1:nJoint, movmean(envPower, smoothN), 'r-', 'LineWidth', 1.5, ...
        'DisplayName', 'Envelope');
    hold off;

    xlabel('Eigenmode rank');
    ylabel('Power (a.u.)');
    title(bandNames(bi));
    legend('Location', 'best');
    xlim([1 nJoint]);
    ylim([0, globalYmax_se * 1.05]);
end
sgtitle(sprintf('Signed vs Envelope Eigenmode Power  (N = %d, smoothed %d)', ...
    nSubjects, smoothN), 'FontWeight', 'bold');
applyPlotDefaults(gcf);

%% 11) Alpha-band peak frequency per eigenmode (group)
%
%  For each eigenmode, find the peak frequency in the alpha range (8-13 Hz).
%  Consistent peak frequency across modes = standing pattern.
%  Systematic shift with eigenvalue = dispersive / traveling.

alphaRange = [8 13];   % Hz
alphaIdx   = freqs >= alphaRange(1) & freqs <= alphaRange(2);
alphaFreqs = freqs(alphaIdx);

% Grand-average joint PSD
grandJointPsd = mean(groupJointPsd, 3);   % [nJoint × nFreqs]
alphaPsd      = grandJointPsd(:, alphaIdx);   % [nJoint × nAlphaFreqs]

[~, peakIdx]  = max(alphaPsd, [], 2);
peakFreq      = alphaFreqs(peakIdx)';   % [nJoint × 1]

grandLambda   = mean(groupJointLambda, 2);

figure('Name', 'Alpha Peak Frequency vs Eigenmode', 'NumberTitle', 'off', ...
    'Position', [100 100 700 400]);

scatter(grandLambda, peakFreq, 8, 'filled', 'MarkerFaceAlpha', 0.4);
xlabel('\lambda  (eigenvalue)');
ylabel('Peak \alpha frequency (Hz)');
title(sprintf('Alpha Peak Frequency vs Eigenvalue  (N = %d)', nSubjects));
ylim(alphaRange);
applyPlotDefaults(gcf);

% Add smoothed trend
[sortedLam, si] = sort(grandLambda);
smoothPeak = movmean(peakFreq(si), 50);
hold on;
plot(sortedLam, smoothPeak, 'r-', 'LineWidth', 2);
hold off;
legend({'Per mode', 'Smoothed trend'}, 'Location', 'best');

%% 12) Statistical analysis — eigenmode PSD significance
%
%  Test whether eigenmode power differs significantly from a flat
%  (uniform) distribution across modes, per frequency bin.
%  Uses one-sample t-tests with FDR correction (Benjamini-Hochberg).

fprintf('\n--- Statistical analysis ---\n');

% 12a) Per-frequency-bin: test whether power varies across modes
%      H0: all modes have equal power at frequency f
%      Test: Kruskal-Wallis across mode-rank terciles per subject,
%            then combine p-values across subjects (Fisher's method).

% Split modes into terciles
tercileBounds = round(linspace(1, nJoint, 4));
nTerciles = 3;
tercileLabels = ["Low modes", "Mid modes", "High modes"];

% Per frequency: test power difference across terciles
pValues_tercile = zeros(nFreqs, 1);
fStatistic      = zeros(nFreqs, 1);

for fi = 1:nFreqs
    % Pool across subjects: each subject contributes 3 tercile means
    tercileMeans = zeros(nSubjects, nTerciles);
    for s = 1:nSubjects
        for ti = 1:nTerciles
            rows = tercileBounds(ti):tercileBounds(ti+1)-1;
            tercileMeans(s, ti) = mean(groupJointPsd(rows, fi, s));
        end
    end

    % Repeated-measures ANOVA approximation via one-way within-subject F
    % Use Friedman test (non-parametric) for robustness
    if nSubjects >= 3
        pValues_tercile(fi) = friedman(tercileMeans, 1, 'off');
    else
        % Not enough subjects for Friedman — use Kruskal-Wallis
        allVals  = tercileMeans(:);
        allGroup = repmat(1:nTerciles, nSubjects, 1);
        pValues_tercile(fi) = kruskalwallis(allVals, allGroup(:), 'off');
    end
end

% FDR correction (Benjamini-Hochberg)
[pSorted, sortIdx] = sort(pValues_tercile);
nTests = nFreqs;
fdrThreshold = 0.05;
bhCritical = (1:nTests)' / nTests * fdrThreshold;
sigMask_sorted = pSorted <= bhCritical;
% Find largest k where p(k) <= k/m * q
lastSig = find(sigMask_sorted, 1, 'last');
if isempty(lastSig)
    sigMask = false(nFreqs, 1);
else
    sigMask = false(nFreqs, 1);
    sigMask(sortIdx(1:lastSig)) = true;
end

nSigFreqs = sum(sigMask);
fprintf('Tercile test: %d / %d frequency bins significant (FDR q=%.2f)\n', ...
    nSigFreqs, nFreqs, fdrThreshold);
if nSigFreqs > 0
    sigFreqRanges = freqs(sigMask);
    fprintf('  Significant freq range: %.1f – %.1f Hz\n', ...
        min(sigFreqRanges), max(sigFreqRanges));
end

% Plot p-values and significance
figure('Name', 'Eigenmode Power Tercile Test', 'NumberTitle', 'off', ...
    'Position', [100 100 800 400]);

subplot(2,1,1);
semilogy(freqs, pValues_tercile, 'b-', 'LineWidth', 1.2);
hold on;
yline(fdrThreshold, '--r', sprintf('FDR q=%.2f', fdrThreshold));
% Shade significant regions
if nSigFreqs > 0
    sigRegions = diff([0; sigMask; 0]);
    starts = find(sigRegions == 1);
    stops  = find(sigRegions == -1) - 1;
    yl = ylim;
    for ri = 1:numel(starts)
        fill([freqs(starts(ri)) freqs(stops(ri)) freqs(stops(ri)) freqs(starts(ri))], ...
            [yl(1) yl(1) yl(2) yl(2)], [0.9 1 0.9], ...
            'EdgeColor', 'none', 'FaceAlpha', 0.4, 'HandleVisibility', 'off');
    end
end
hold off;
xlabel('Frequency (Hz)');
ylabel('p-value');
title(sprintf('Mode Power Varies Across Spatial Scales?  (N=%d, Friedman test)', nSubjects));
legend('p-value', 'FDR threshold', 'Location', 'best');

% 12b) Grand-average tercile power profiles
subplot(2,1,2);
co = lines(nTerciles);
hold on;
for ti = 1:nTerciles
    rows = tercileBounds(ti):tercileBounds(ti+1)-1;
    tercilePsd = mean(grandJointPsd(rows, :), 1);   % [1 × nFreqs]
    plot(freqs, 10*log10(tercilePsd), 'Color', co(ti,:), 'LineWidth', 1.5, ...
        'DisplayName', tercileLabels(ti));
end
hold off;
xlabel('Frequency (Hz)');
ylabel('Power (dB, raw PSD)');
title('Grand-Average PSD by Mode Tercile');
legend('Location', 'best');
applyPlotDefaults(gcf);

% 12c) Per-band test: does eigenmode power profile differ from uniform?
%      Kolmogorov-Smirnov test per band per subject vs uniform distribution.
fprintf('\nPer-band uniformity test (KS vs uniform):\n');
for bi = 1:nBands
    ksP = zeros(nSubjects, 1);
    for s = 1:nSubjects
        jp = [groupSignedL(:, bi, s); groupSignedR(:, bi, s)];
        jp = jp / sum(jp);   % normalize to pseudo-distribution
        [~, ksP(s)] = kstest2(jp, ones(nJoint,1)/nJoint);
    end
    medP = median(ksP);
    nSig = sum(ksP < 0.05);
    fprintf('  %8s:  median p = %.2e,  %d/%d subjects p<0.05\n', ...
        bandNames(bi), medP, nSig, nSubjects);
end

%% ================================================================
%  FILTER GROUP ANALYSIS
%% ================================================================

%% 13) Filter kernel response curves
%
%  Visualize h_j(λ) for each scale in the filterbank.
%  These are deterministic (depend only on fsaverage5 eigenvalues).

for fi = 1:nFilterTypes
    fTag = filterTypes(fi);
    if ~filterGroup.(fTag).available, continue; end

    fg = filterGroup.(fTag);

    figure('Name', sprintf('Filter Kernels — %s', filterLabels(fi)), ...
        'NumberTitle', 'off', 'Position', [100 100 800 400]);
    tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    for hi = 1:2
        nexttile;
        if hi == 1
            lam = fg.eigenvaluesL;  W = fg.allWeightsL;  hStr = 'LH';
        else
            lam = fg.eigenvaluesR;  W = fg.allWeightsR;  hStr = 'RH';
        end

        co = lines(fg.nScales);
        hold on;
        for si = 1:fg.nScales
            plot(lam, W(:, si), 'Color', co(si,:), 'LineWidth', 1.5, ...
                'DisplayName', fg.scaleLabels(si));
        end
        hold off;
        xlabel('\lambda (eigenvalue)');
        ylabel('h(\lambda)');
        title(sprintf('%s — %s', fg.kernelName, hStr));
        legend('Location', 'best');
    end

    sgtitle(sprintf('Spectral Filter Kernels — %s', filterLabels(fi)), ...
        'FontWeight', 'bold');
    applyPlotDefaults(gcf);
end

%% 14) Scale-Band energy heatmap
%
%  Group-average [nScales × nBands] total source power at each spatial
%  scale and frequency band. One heatmap per kernel type.

for fi = 1:nFilterTypes
    fTag = filterTypes(fi);
    if ~filterGroup.(fTag).available, continue; end

    fg = filterGroup.(fTag);

    % Average across subjects (NaN-safe) and hemispheres
    avgL = mean(fg.scalePowerL, 3, 'omitnan');  % [nScales × nBands]
    avgR = mean(fg.scalePowerR, 3, 'omitnan');
    avgPower = (avgL + avgR) / 2;

    figure('Name', sprintf('Scale-Band Energy — %s', filterLabels(fi)), ...
        'NumberTitle', 'off', 'Position', [100 100 600 400]);

    imagesc(avgPower);
    colorbar;
    colormap(parula(256));
    xlabel('Frequency Band');
    ylabel('Spatial Scale');
    xticks(1:fg.nBands);
    xticklabels(fg.bandNames);
    yticks(1:fg.nScales);
    yticklabels(fg.scaleLabels);
    title(sprintf('Scale-Band Energy — %s  (N = %d)', ...
        filterLabels(fi), fg.nSubjects));
    applyPlotDefaults(gcf);
end

%% 15) Per-band scale energy fraction
%
%  Stacked bars showing what fraction of total filtered power
%  lives at each spatial scale, per frequency band.

for fi = 1:nFilterTypes
    fTag = filterTypes(fi);
    if ~filterGroup.(fTag).available, continue; end

    fg = filterGroup.(fTag);

    avgPower = (mean(fg.scalePowerL, 3, 'omitnan') + ...
                mean(fg.scalePowerR, 3, 'omitnan')) / 2;   % [nScales × nBands]

    fracPower = avgPower ./ sum(avgPower, 1);               % normalised per band

    figure('Name', sprintf('Scale Fraction — %s', filterLabels(fi)), ...
        'NumberTitle', 'off', 'Position', [100 100 700 400]);

    bar(fracPower', 'stacked');
    xlabel('Frequency Band');
    ylabel('Fraction of Total Power');
    xticks(1:fg.nBands);
    xticklabels(fg.bandNames);
    legend(fg.scaleLabels, 'Location', 'bestoutside');
    title(sprintf('Scale Energy Fraction per Band — %s  (N = %d)', ...
        filterLabels(fi), fg.nSubjects));
    ylim([0 1]);
    applyPlotDefaults(gcf);
end

%% 16) Cross-kernel comparison
%
%  If both kernels are available, overlay their fractional scale
%  distributions to reveal kernel-dependent energy allocation.

if filterGroup.mxhat.available && filterGroup.heat.available

    fgM = filterGroup.mxhat;
    fgH = filterGroup.heat;

    avgM = (mean(fgM.scalePowerL, 3, 'omitnan') + mean(fgM.scalePowerR, 3, 'omitnan')) / 2;
    avgH = (mean(fgH.scalePowerL, 3, 'omitnan') + mean(fgH.scalePowerR, 3, 'omitnan')) / 2;

    fracM = avgM ./ sum(avgM, 1);
    fracH = avgH ./ sum(avgH, 1);

    figure('Name', 'Cross-Kernel Comparison', 'NumberTitle', 'off', ...
        'Position', [100 100 900 500]);
    tiledlayout(2, ceil(fgM.nBands / 2), 'TileSpacing', 'compact', 'Padding', 'compact');

    for bi = 1:fgM.nBands
        nexttile;
        bar([fracM(:, bi), fracH(:, bi)]);
        xticks(1:fgM.nScales);
        xticklabels(fgM.scaleLabels);
        xtickangle(45);
        ylabel('Fraction');
        title(fgM.bandNames(bi));
        legend('Mexican Hat', 'Heat', 'Location', 'best');
        ylim([0, max([fracM(:); fracH(:)]) * 1.1]);
    end

    sgtitle('Cross-Kernel Scale Distribution Comparison', ...
        'FontWeight', 'bold');
    applyPlotDefaults(gcf);
end

%% ================================================================
%  SAVE ALL FIGURES
%% ================================================================

figDir = fullfile(analysisRoot, "group", "figures");
if ~isfolder(figDir), mkdir(figDir); end

fprintf('\n--- Saving figures to %s ---\n', figDir);

% Collect all open figures
allFigs = findobj('Type', 'figure');

% Map figure names → filenames and format (vector PDF vs raster PNG)
% Figures with imagesc/pcolor get PNG; line plots get PDF.
rasterNames = [ ...
    "Grand-Average Eigenmode", ...
    "Select Eigenmodes", ...
    "Cross-Subject Correlation", ...
    "Scale-Band Energy"];  % partial match for filter-specific figures

for fi = 1:numel(allFigs)
    fig = allFigs(fi);
    figName = string(fig.Name);
    if figName == "", continue; end

    % Sanitize filename: remove special characters, limit length
    fname = regexprep(figName, '[^a-zA-Z0-9_\- ]', '');
    fname = regexprep(strtrim(fname), '\s+', '_');
    if strlength(fname) > 80, fname = extractBefore(fname, 81); end

    % Decide format: PNG for raster-heavy figures, PDF for vector
    isRaster = false;
    for ri = 1:numel(rasterNames)
        if contains(figName, rasterNames(ri))
            isRaster = true;
            break;
        end
    end

    if isRaster
        outFile = fullfile(figDir, fname + ".png");
        exportgraphics(fig, outFile, 'Resolution', 300);
    else
        outFile = fullfile(figDir, fname + ".pdf");
        exportgraphics(fig, outFile, 'ContentType', 'vector');
    end

    % Save editable MATLAB .fig
    figFile = fullfile(figDir, fname + ".fig");
    savefig(fig, figFile, 'compact');

    fprintf('  %s\n', outFile);
end

fprintf('\n=== Group analysis complete ===\n');
fprintf('Subjects: %d\n', nSubjects);
fprintf('Figures saved: %d  →  %s\n', numel(allFigs), figDir);

%% ===== Local Functions =====

function subjects = findSubjects(analysisRoot)
%FINDSUBJECTS  Auto-detect subject directories with eigenmodeAnalysis.mat.
    d = dir(fullfile(analysisRoot, "sub-*"));
    d = d([d.isdir]);
    subjects = string({d.name})';

    hasAnalysis = false(numel(subjects), 1);
    for i = 1:numel(subjects)
        hasAnalysis(i) = isfile(fullfile(analysisRoot, subjects(i), "eigenmodeAnalysis.mat"));
    end
    subjects = subjects(hasAnalysis);

    if isempty(subjects)
        error('findSubjects:none', 'No subject directories with eigenmodeAnalysis.mat found in %s', analysisRoot);
    end
end
