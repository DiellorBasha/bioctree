%% Joint Time-Vertex Diffusion Filter — Single Window Exploration
%
%  Applies a JTV diffusion filter in eigenmode space (Approach A).
%  Unlike eigenmodeFilter which uses a spatial-only kernel and
%  time-averages, this script applies a spatiotemporal kernel:
%
%    g(lambda_m, t_k) = exp( -tau * t_k * lambda_m / lambda_max )
%
%  The filter is separable in (lambda, t): high-eigenvalue modes decay
%  faster over time.  At t=0 the filter is identity (no smoothing);
%  at t=T the finest modes are strongly damped.
%
%  This matches GSPBox's gsp_jtv_design_diffusion.
%
%  A single window is loaded so we can inspect the raw time-varying
%  filtered output before committing to windowed averaging.
%
%  Prerequisite: run buildEigenProjection() once per subject.

%% 1) Configuration
analysisRoot = "Z:\brainstorm_protocols_analysis\TutorialOmega2";
subjectName  = "sub-0002";
subjectPath  = fullfile(analysisRoot, subjectName);

bandNames  = ["delta", "theta", "alpha", "beta", "gamma1"];
nBands     = numel(bandNames);

% Diffusion parameters — multiple tau to compare
taus       = [0.1, 10, 100, 500];
nTaus      = numel(taus);

windowSec  = 4;
overlapSec = 2;
windowIdx  = 1;         % which window to load (1-based)

bandToPlot = 3;          % alpha band for visualization

fprintf('=== JTV Diffusion Filter (Single Window) ===\n');
fprintf('Subject:  %s\n', subjectName);
fprintf('Taus:     %s\n', join(string(taus), ", "));
fprintf('Window:   #%d  (%.0f s, %.0f%% overlap)\n', ...
    windowIdx, windowSec, overlapSec/windowSec*100);

%% 2) Load subject data & fsaverage5 eigenvectors
meta  = load(fullfile(subjectPath, "provenance.mat")).provenance;
eigen = load(fullfile(subjectPath, "eigen.mat")).eigen;

load(fullfile(analysisRoot, "group", "fsaverage5.mat"));
U_lh = fsaverage5.lh.eigen.eigenvectors.value;   % [nVertL x nModesL]
U_rh = fsaverage5.rh.eigen.eigenvectors.value;   % [nVertR x nModesR]

lambdaL = eigen.lh.eigenvalues;   % [nModesL x 1]
lambdaR = eigen.rh.eigenvalues;   % [nModesR x 1]
lmaxL   = max(lambdaL);
lmaxR   = max(lambdaR);

nVertL  = size(U_lh, 1);
nVertR  = size(U_rh, 1);
nModesL = numel(lambdaL);
nModesR = numel(lambdaR);

fprintf('Eigen:    lh [%d modes],  rh [%d modes]\n', nModesL, nModesR);
fprintf('Verts:    lh %d,  rh %d\n', nVertL, nVertR);
fprintf('lmax:     lh %.4f,  rh %.4f\n', lmaxL, lmaxR);

%% 3) Load a single window
[segDs, winTbl] = makeWindowedDatastore( ...
    fullfile(subjectPath, "bands.mat"), meta.sfreq, meta.nSamples, ...
    WindowSec=windowSec, OverlapSec=overlapSec);

% Advance to the requested window
reset(segDs);
for k = 1:windowIdx
    w = read(segDs);
end

[nCh, winSamp, ~] = size(w.X);
tAxis = (0:winSamp-1) / meta.sfreq;   % time axis within window [s]

fprintf('Window %d:  %.1f–%.1f s  (%d samples at %.0f Hz)\n', ...
    windowIdx, w.tStartSec, w.tStopSec, winSamp, meta.sfreq);

%% 4) Project to eigenmodes — all bands at once
%
%  w.X is [nCh x winSamp x nBands].
%  Reshape to [nCh x winSamp*nBands], project, then reshape back.

Xflat = reshape(w.X, nCh, []);                       % [nCh x winSamp*nBands]
coeffsLflat = eigen.lh.imagingKernel * Xflat;         % [nModesL x winSamp*nBands]
coeffsRflat = eigen.rh.imagingKernel * Xflat;         % [nModesR x winSamp*nBands]

coeffsL = reshape(coeffsLflat, nModesL, winSamp, nBands);  % [nModes x winSamp x nBands]
coeffsR = reshape(coeffsRflat, nModesR, winSamp, nBands);

fprintf('Coefficients: LH [%d x %d x %d],  RH [%d x %d x %d]\n', ...
    size(coeffsL), size(coeffsR));

%% 5) Build JTV diffusion kernel and apply
%
%  For each tau, the 2D kernel (evaluated on eigenvalues x time) is:
%
%    G(m, t) = exp( -tau * t * lambda(m) / lmax )
%
%  Filtering is element-wise: filtC(m,t) = G(m,t) .* C(m,t)
%
%  Output: filtSrcL{tau}(:,:,band) = U * filtC  → [nVert x winSamp x nBands]
%  That's large, so we only reconstruct the band specified by bandToPlot.

fprintf('\nApplying JTV diffusion filter for band: %s\n', bandNames(bandToPlot));

% Pre-build kernel matrices [nModes x winSamp] — one per tau per hemisphere
kernelL = cell(nTaus, 1);
kernelR = cell(nTaus, 1);
for j = 1:nTaus
    kernelL{j} = exp(-taus(j) * tAxis .* (lambdaL / lmaxL));   % [nModesL x winSamp]
    kernelR{j} = exp(-taus(j) * tAxis .* (lambdaR / lmaxR));   % [nModesR x winSamp]
end

% Extract coefficients for the selected band
cL = coeffsL(:, :, bandToPlot);   % [nModesL x winSamp]
cR = coeffsR(:, :, bandToPlot);   % [nModesR x winSamp]

% Apply filter and reconstruct — per tau
%  filtSrcL{j} = U_lh * (kernel .* coeffs)  →  [nVertL x winSamp]
filtSrcL = cell(nTaus, 1);
filtSrcR = cell(nTaus, 1);

for j = 1:nTaus
    fprintf('  tau = %g ...', taus(j));
    filtSrcL{j} = U_lh * (kernelL{j} .* cL);   % [nVertL x winSamp]
    filtSrcR{j} = U_rh * (kernelR{j} .* cR);   % [nVertR x winSamp]
    fprintf('  done\n');
end

% Also reconstruct the unfiltered signal for comparison
srcL_orig = U_lh * cL;   % [nVertL x winSamp]
srcR_orig = U_rh * cR;   % [nVertR x winSamp]

fprintf('Reconstruction complete.\n');

%% 5b) Build Manifold for SourceExplorer
Mleft = bct.Manifold(fsaverage5.lh.vertices, fsaverage5.lh.faces);

% Time axis for the window (absolute time in seconds)
tWin = w.tStartSec + tAxis;

%% ================================================================
%  VISUALIZATION
%% ================================================================

%% 6) SourceExplorer: unfiltered vs diffusion-filtered (LH)
%    Show magnitude (abs) by default; signed data also available.

% Unfiltered — magnitude
SourceExplorer(Mleft, abs(srcL_orig), tWin, ...
    TimePoint=tWin(round(end/2)), ...
    Title=sprintf("Unfiltered |source| — LH %s band", bandNames(bandToPlot)));

% Filtered at each tau — magnitude
for j = 1:nTaus
    SourceExplorer(Mleft, abs(filtSrcL{j}), tWin, ...
        TimePoint=tWin(round(end/2)), ...
        Title=sprintf("Diffusion |source| \\tau=%g — LH %s band", taus(j), bandNames(bandToPlot)));
end

% --- Optional: signed source maps (uncomment to compare) ---
% SourceExplorer(Mleft, srcL_orig, tWin, ...
%     TimePoint=tWin(round(end/2)), ...
%     Title=sprintf("Unfiltered signed — LH %s band", bandNames(bandToPlot)));
% for j = 1:nTaus
%     SourceExplorer(Mleft, filtSrcL{j}, tWin, ...
%         TimePoint=tWin(round(end/2)), ...
%         Title=sprintf("Diffusion signed \\tau=%g — LH %s band", taus(j), bandNames(bandToPlot)));
% end

%% 7) Plot the 2D kernel g(lambda, t) for each tau
figure('Name', 'JTV Diffusion Kernel g(lambda, t)', 'NumberTitle', 'off', ...
    'Position', [100 100 300*nTaus 300]);
tiledlayout(1, nTaus, 'TileSpacing', 'compact', 'Padding', 'compact');

lambdaGrid = linspace(0, lmaxL, 200);
for j = 1:nTaus
    nexttile;
    K = exp(-taus(j) * tAxis .* (lambdaGrid(:) / lmaxL));   % [200 x winSamp]
    imagesc(tAxis * 1000, lambdaGrid, K);
    set(gca, 'YDir', 'normal');
    xlabel('Time (ms)');
    ylabel('\lambda');
    title(sprintf('\\tau = %g', taus(j)));
    colorbar;
    caxis([0 1]);
end
sgtitle(sprintf('JTV Diffusion Kernel  g(\\lambda, t) = exp(-\\tau \\cdot t \\cdot \\lambda/\\lambda_{max})  —  %s band', ...
    bandNames(bandToPlot)), 'FontSize', 12, 'FontWeight', 'bold');

%% 8) Time-averaged source maps: compare unfiltered vs filtered (LH)
%
%  Take abs(mean over time) to see the spatial pattern after diffusion

avgOrig = abs(mean(srcL_orig, 2));   % [nVertL x 1]

figure('Name', 'Time-Averaged Source Maps — LH', 'NumberTitle', 'off', ...
    'Position', [100 50 400*(nTaus+1) 350]);
tiledlayout(1, nTaus+1, 'TileSpacing', 'compact', 'Padding', 'compact');

V = fsaverage5.lh.vertices;
F = fsaverage5.lh.faces;

% Unfiltered
nexttile;
trisurf(F, V(:,1), V(:,2), V(:,3), avgOrig, ...
    'EdgeColor', 'none', 'FaceColor', 'interp');
axis equal off; colorbar; lighting gouraud; camlight headlight; material dull;
mu = mean(avgOrig); sd = std(avgOrig);
if sd > 0; caxis([max(0, mu-4*sd), mu+4*sd]); end
title('Unfiltered', 'FontSize', 11);

% Filtered at each tau
for j = 1:nTaus
    nexttile;
    avgFilt = abs(mean(filtSrcL{j}, 2));
    trisurf(F, V(:,1), V(:,2), V(:,3), avgFilt, ...
        'EdgeColor', 'none', 'FaceColor', 'interp');
    axis equal off; colorbar; lighting gouraud; camlight headlight; material dull;
    mu = mean(avgFilt); sd = std(avgFilt);
    if sd > 0; caxis([max(0, mu-4*sd), mu+4*sd]); end
    title(sprintf('\\tau = %g', taus(j)), 'FontSize', 11);
end
sgtitle(sprintf('Time-Averaged |Source|  —  LH  %s band', bandNames(bandToPlot)), ...
    'FontSize', 12, 'FontWeight', 'bold');

%% 9) Snapshots at specific time points: show diffusion progression (LH)
%
%  Pick a few time indices to see spatial patterns at different moments

snapTimes = [0.0, 0.5, 1.0, 2.0, 3.0];   % seconds into window
snapTimes = snapTimes(snapTimes < tAxis(end));
nSnaps = numel(snapTimes);
tauForSnap = taus(min(3, nTaus));   % pick a mid-range tau for detail
jSnap = find(taus == tauForSnap, 1);

figure('Name', sprintf('Snapshots tau=%g — LH', tauForSnap), ...
    'NumberTitle', 'off', 'Position', [100 50 400*nSnaps 700]);
tiledlayout(2, nSnaps, 'TileSpacing', 'compact', 'Padding', 'compact');

for s = 1:nSnaps
    [~, tidx] = min(abs(tAxis - snapTimes(s)));

    % Unfiltered
    nexttile(s);
    trisurf(F, V(:,1), V(:,2), V(:,3), abs(srcL_orig(:, tidx)), ...
        'EdgeColor', 'none', 'FaceColor', 'interp');
    axis equal off; colorbar; lighting gouraud; camlight headlight; material dull;
    title(sprintf('Orig  t=%.1fs', tAxis(tidx)), 'FontSize', 10);

    % Filtered
    nexttile(nSnaps + s);
    trisurf(F, V(:,1), V(:,2), V(:,3), abs(filtSrcL{jSnap}(:, tidx)), ...
        'EdgeColor', 'none', 'FaceColor', 'interp');
    axis equal off; colorbar; lighting gouraud; camlight headlight; material dull;
    title(sprintf('Filt  t=%.1fs', tAxis(tidx)), 'FontSize', 10);
end
sgtitle(sprintf('Unfiltered (top) vs Diffusion \\tau=%g (bottom)  —  LH  %s', ...
    tauForSnap, bandNames(bandToPlot)), 'FontSize', 12, 'FontWeight', 'bold');

%% 10) Spectral energy over time: show mode decay
%
%  Plot the energy in eigenmodes as a function of time for unfiltered
%  vs filtered, grouped into low/mid/high eigenvalue bands.

modeBands = {1:round(nModesL*0.1), ...           % lowest 10% modes
             round(nModesL*0.1)+1:round(nModesL*0.5), ...  % mid
             round(nModesL*0.5)+1:nModesL};       % highest 50%
modeBandLabels = ["Low modes (0-10%)", "Mid modes (10-50%)", "High modes (50-100%)"];

figure('Name', 'Spectral Energy Over Time', 'NumberTitle', 'off', ...
    'Position', [100 100 500 700]);
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

for mb = 1:3
    nexttile;
    modes = modeBands{mb};

    % Unfiltered energy
    E_orig = sum(cL(modes, :).^2, 1);   % [1 x winSamp]
    plot(tAxis * 1000, E_orig, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Unfiltered');
    hold on;

    co = lines(nTaus);
    for j = 1:nTaus
        filtC = kernelL{j}(modes, :) .* cL(modes, :);
        E_filt = sum(filtC.^2, 1);
        plot(tAxis * 1000, E_filt, 'Color', co(j,:), 'LineWidth', 1.2, ...
            'DisplayName', sprintf('\\tau=%g', taus(j)));
    end
    hold off;
    xlabel('Time (ms)');
    ylabel('Energy');
    title(modeBandLabels(mb), 'FontSize', 11);
    legend('Location', 'best', 'FontSize', 8);
    grid on;
end
sgtitle(sprintf('Eigenmode Energy vs Time  —  LH  %s band', bandNames(bandToPlot)), ...
    'FontSize', 12, 'FontWeight', 'bold');

%% 11) Global smoothness metric over time
%
%  Surface Dirichlet energy:  E_D(t) = sum_m lambda_m * c_m(t)^2
%  = f'*S*f  (stiffness form), valid because eigenmodes are M-orthonormal.
%  Measures spatial roughness at each time point.

figure('Name', 'Surface Dirichlet Energy Over Time', 'NumberTitle', 'off', ...
    'Position', [100 100 600 350]);

ED_orig = lambdaL' * cL.^2;   % [1 x winSamp]
plot(tAxis * 1000, ED_orig, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Unfiltered');
hold on;
co = lines(nTaus);
for j = 1:nTaus
    filtC = kernelL{j} .* cL;
    ED_filt = lambdaL' * filtC.^2;
    plot(tAxis * 1000, ED_filt, 'Color', co(j,:), 'LineWidth', 1.2, ...
        'DisplayName', sprintf('\\tau=%g', taus(j)));
end
hold off;
xlabel('Time (ms)');
ylabel('E_D(t) = \Sigma \lambda_m c_m(t)^2');
title(sprintf('Surface Dirichlet Energy  —  LH  %s band', bandNames(bandToPlot)), ...
    'FontSize', 12);
legend('Location', 'best');
grid on;

fprintf('\n=== Done ===\n');
