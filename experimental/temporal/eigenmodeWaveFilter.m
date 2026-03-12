%% Joint Time-Vertex Wave Filter — Single Window Exploration
%
%  Applies a JTV wave filter in eigenmode space.
%  Unlike the diffusion filter (which damps modes monotonically),
%  the wave filter makes each eigenmode OSCILLATE in time at a
%  frequency proportional to its eigenvalue:
%
%    g(lambda_m, t) = cos( t * acos(1 - alpha^2 * lambda_m / (2*lmax)) )
%
%  where t is the sample index (integer) and alpha is the wave velocity.
%
%  Physical interpretation:
%    - Each eigenmode oscillates at its own temporal frequency
%    - Higher eigenvalues (finer spatial patterns) oscillate faster
%    - Energy is CONSERVED (no damping) — contrast with diffusion
%    - alpha controls the propagation speed on the manifold
%
%  Stability condition (CFL):  alpha < 2 / fs
%
%  This matches GSPBox's gsp_jtv_design_wave.
%
%  Prerequisite: run buildEigenProjection() once per subject.

%% 1) Configuration
analysisRoot = "Z:\brainstorm_protocols_analysis\TutorialOmega2";
subjectName  = "sub-0002";
subjectPath  = fullfile(analysisRoot, subjectName);

bandNames  = ["delta", "theta", "alpha", "beta", "gamma1"];
nBands     = numel(bandNames);

windowSec  = 4;
overlapSec = 2;
windowIdx  = 1;         % which window to load (1-based)

bandToPlot = 3;          % alpha band for visualization

fprintf('=== JTV Wave Filter (Single Window) ===\n');
fprintf('Subject:  %s\n', subjectName);

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
tSamples = 0:winSamp-1;               % integer sample indices for wave kernel

fprintf('Window %d:  %.1f-%.1f s  (%d samples at %.0f Hz)\n', ...
    windowIdx, w.tStartSec, w.tStopSec, winSamp, meta.sfreq);

%% Wave velocity parameters
%
%  The GSPBox CFL condition (alpha < 2/fs) applies to ITERATIVE
%  numerical time-stepping.  Here we apply the kernel ANALYTICALLY
%  in the spectral domain (direct multiplication), so CFL is irrelevant.
%
%  The only mathematical constraint is acos(·) in [-1,1]:
%    1 - alpha^2 * lmax / (2*lmax) = 1 - alpha^2/2  >= -1  =>  alpha <= 2

alphas = [0.05, 0.1, 0.2, 0.4];
assert(all(alphas <= 2), 'alpha must be <= 2 for acos validity');
nAlphas = numel(alphas);

fprintf('Constraint: alpha <= 2  (analytical spectral application)\n');
fprintf('Alphas:     %s\n', join(string(alphas), ", "));
fprintf('Window:   #%d  (%.0f s, %.0f%% overlap)\n', ...
    windowIdx, windowSec, overlapSec/windowSec*100);

%% 4) Project to eigenmodes — all bands at once

Xflat = reshape(w.X, nCh, []);                       % [nCh x winSamp*nBands]
coeffsLflat = eigen.lh.imagingKernel * Xflat;         % [nModesL x winSamp*nBands]
coeffsRflat = eigen.rh.imagingKernel * Xflat;         % [nModesR x winSamp*nBands]

coeffsL = reshape(coeffsLflat, nModesL, winSamp, nBands);  % [nModes x winSamp x nBands]
coeffsR = reshape(coeffsRflat, nModesR, winSamp, nBands);

fprintf('Coefficients: LH [%d x %d x %d],  RH [%d x %d x %d]\n', ...
    size(coeffsL), size(coeffsR));

%% 5) Build JTV wave kernel and apply
%
%  For each alpha, the 2D kernel (evaluated on eigenvalues x time) is:
%
%    G(m, t) = cos( t * acos(1 - alpha^2 * lambda(m) / (2*lmax)) )
%
%  where t is the integer sample index.
%
%  Each eigenmode oscillates at angular frequency:
%    omega_m = acos(1 - alpha^2 * lambda_m / (2*lmax))
%
%  Low eigenvalues -> slow oscillation, high eigenvalues -> fast oscillation.
%  Unlike diffusion, energy is conserved (cos^2 doesn't decay).

fprintf('\nApplying JTV wave filter for band: %s\n', bandNames(bandToPlot));

% Pre-build kernel matrices [nModes x winSamp] — one per alpha per hemisphere
kernelL = cell(nAlphas, 1);
kernelR = cell(nAlphas, 1);
omegaL  = cell(nAlphas, 1);   % angular frequencies per mode
omegaR  = cell(nAlphas, 1);

for j = 1:nAlphas
    % Angular frequency for each eigenmode
    omegaL{j} = acos(1 - alphas(j)^2 * lambdaL / (2*lmaxL));  % [nModesL x 1]
    omegaR{j} = acos(1 - alphas(j)^2 * lambdaR / (2*lmaxR));  % [nModesR x 1]

    % Wave kernel: cos(omega_m * t) for all modes and time samples
    kernelL{j} = cos(omegaL{j} * tSamples);   % [nModesL x winSamp]
    kernelR{j} = cos(omegaR{j} * tSamples);   % [nModesR x winSamp]
end

% Extract coefficients for the selected band
cL = coeffsL(:, :, bandToPlot);   % [nModesL x winSamp]
cR = coeffsR(:, :, bandToPlot);   % [nModesR x winSamp]

% Apply filter and reconstruct — per alpha
filtSrcL = cell(nAlphas, 1);
filtSrcR = cell(nAlphas, 1);

for j = 1:nAlphas
    fprintf('  alpha = %g ...', alphas(j));
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

%% 6) SourceExplorer: unfiltered vs wave-filtered (LH)
%    Show magnitude (abs) by default; signed data also available.

% Unfiltered — magnitude
SourceExplorer(Mleft, abs(srcL_orig), tWin, ...
    TimePoint=tWin(round(end/2)), ...
    Title=sprintf("Unfiltered |source| — LH %s band", bandNames(bandToPlot)));

% Filtered at each alpha — magnitude
for j = 1:nAlphas
    SourceExplorer(Mleft, abs(filtSrcL{j}), tWin, ...
        TimePoint=tWin(round(end/2)), ...
        Title=sprintf("Wave |source| \\alpha=%g — LH %s band", alphas(j), bandNames(bandToPlot)));
end
%% 

%--- Optional: signed source maps (uncomment to compare) ---
SourceExplorer(Mleft, srcL_orig, tWin, ...
    TimePoint=tWin(round(end/2)), ...
    Title=sprintf("Unfiltered signed — LH %s band", bandNames(bandToPlot)));
for j = 1:nAlphas
    SourceExplorer(Mleft, filtSrcL{j}, tWin, ...
        TimePoint=tWin(round(end/2)), ...
        Title=sprintf("Wave signed \\alpha=%g — LH %s band", alphas(j), bandNames(bandToPlot)));
end

%% 7) Plot the 2D kernel g(lambda, t) for each alpha
%
%  The wave kernel cos(omega_m * t) shows oscillatory bands.
%  Higher eigenvalues oscillate faster.  At alpha near CFL the
%  highest mode oscillates at the Nyquist frequency.

figure('Name', 'JTV Wave Kernel g(lambda, t)', 'NumberTitle', 'off', ...
    'Position', [100 100 300*nAlphas 300]);
tiledlayout(1, nAlphas, 'TileSpacing', 'compact', 'Padding', 'compact');

lambdaGrid = linspace(0, lmaxL, 200);
for j = 1:nAlphas
    nexttile;
    omegaGrid = acos(1 - alphas(j)^2 * lambdaGrid(:) / (2*lmaxL));
    % Only show first 500 ms to see detail
    tShow = min(winSamp, round(0.5 * meta.sfreq));
    tSampShow = 0:tShow-1;
    K = cos(omegaGrid * tSampShow);   % [200 x tShow]
    imagesc(tSampShow / meta.sfreq * 1000, lambdaGrid, K);
    set(gca, 'YDir', 'normal');
    xlabel('Time (ms)');
    ylabel('\lambda');
    title(sprintf('\\alpha = %g', alphas(j)));
    colorbar;
    caxis([-1 1]);
    colormap(gca, interp1([0 0.5 1], [0 0 1; 1 1 1; 1 0 0], linspace(0,1,256)));
end
sgtitle(sprintf('JTV Wave Kernel  g(\\lambda, t) = cos(\\omega_m \\cdot t)  —  %s band', ...
    bandNames(bandToPlot)), 'FontSize', 12, 'FontWeight', 'bold');

%% 8) Mode angular frequencies vs eigenvalue
%
%  omega_m = acos(1 - alpha^2 * lambda_m / (2*lmax))
%  Plot to see the dispersion relation.

figure('Name', 'Dispersion Relation', 'NumberTitle', 'off', ...
    'Position', [100 100 600 400]);
hold on;
co = lines(nAlphas);
for j = 1:nAlphas
    plot(lambdaL, omegaL{j}, 'Color', co(j,:), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('\\alpha = %g', alphas(j)));
end
hold off;
xlabel('\lambda  (eigenvalue)');
ylabel('\omega_m  (rad/sample)');
title('Wave Dispersion Relation:  \omega_m = acos(1 - \alpha^2 \lambda_m / 2\lambda_{max})', ...
    'FontSize', 11);
legend('Location', 'best');
grid on;

% Secondary axis: frequency in Hz
yyaxis right;
ylabel('f_m  (Hz)');
ylim(ylim(gca) / (2*pi) * meta.sfreq);

%% 9) Time-averaged source maps: compare unfiltered vs filtered (LH)
%
%  For a wave filter the time-average should be DIFFERENT from unfiltered
%  because the oscillatory kernel modulates different modes at different
%  rates, causing constructive/destructive interference.

avgOrig = abs(mean(srcL_orig, 2));   % [nVertL x 1]

figure('Name', 'Time-Averaged Source Maps — LH', 'NumberTitle', 'off', ...
    'Position', [100 50 400*(nAlphas+1) 350]);
tiledlayout(1, nAlphas+1, 'TileSpacing', 'compact', 'Padding', 'compact');

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

% Filtered at each alpha
for j = 1:nAlphas
    nexttile;
    avgFilt = abs(mean(filtSrcL{j}, 2));
    trisurf(F, V(:,1), V(:,2), V(:,3), avgFilt, ...
        'EdgeColor', 'none', 'FaceColor', 'interp');
    axis equal off; colorbar; lighting gouraud; camlight headlight; material dull;
    mu = mean(avgFilt); sd = std(avgFilt);
    if sd > 0; caxis([max(0, mu-4*sd), mu+4*sd]); end
    title(sprintf('\\alpha = %g', alphas(j)), 'FontSize', 11);
end
sgtitle(sprintf('Time-Averaged |Source|  —  LH  %s band', bandNames(bandToPlot)), ...
    'FontSize', 12, 'FontWeight', 'bold');

%% 10) Spectral energy over time: wave does NOT decay
%
%  Unlike diffusion, the wave kernel preserves energy.
%  cos^2 oscillates but doesn't shrink.  The mode energy should
%  fluctuate (modulated by the wave) but not trend downward.

modeBands = {1:round(nModesL*0.1), ...           % lowest 10% modes
             round(nModesL*0.1)+1:round(nModesL*0.5), ...  % mid
             round(nModesL*0.5)+1:nModesL};       % highest 50%
modeBandLabels = ["Low modes (0-10%)", "Mid modes (10-50%)", "High modes (50-100%)"];

figure('Name', 'Spectral Energy Over Time (Wave)', 'NumberTitle', 'off', ...
    'Position', [100 100 500 700]);
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

for mb = 1:3
    nexttile;
    modes = modeBands{mb};

    % Unfiltered energy
    E_orig = sum(cL(modes, :).^2, 1);   % [1 x winSamp]
    plot(tAxis * 1000, E_orig, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Unfiltered');
    hold on;

    co = lines(nAlphas);
    for j = 1:nAlphas
        filtC = kernelL{j}(modes, :) .* cL(modes, :);
        E_filt = sum(filtC.^2, 1);
        plot(tAxis * 1000, E_filt, 'Color', co(j,:), 'LineWidth', 1.2, ...
            'DisplayName', sprintf('\\alpha=%g', alphas(j)));
    end
    hold off;
    xlabel('Time (ms)');
    ylabel('Energy');
    title(modeBandLabels(mb), 'FontSize', 11);
    legend('Location', 'best', 'FontSize', 8);
    grid on;
end
sgtitle(sprintf('Eigenmode Energy vs Time (Wave)  —  LH  %s band', bandNames(bandToPlot)), ...
    'FontSize', 12, 'FontWeight', 'bold');

%% 11) Surface Dirichlet energy over time
%
%  E_D(t) = sum_m lambda_m * c_m(t)^2
%  = f'*S*f  (stiffness form), valid because eigenmodes are M-orthonormal.
%  The wave filter redistributes energy across modes but conserves total.

figure('Name', 'Surface Dirichlet Energy Over Time (Wave)', 'NumberTitle', 'off', ...
    'Position', [100 100 600 350]);

ED_orig = lambdaL' * cL.^2;   % [1 x winSamp]
plot(tAxis * 1000, ED_orig, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Unfiltered');
hold on;
co = lines(nAlphas);
for j = 1:nAlphas
    filtC = kernelL{j} .* cL;
    ED_filt = lambdaL' * filtC.^2;
    plot(tAxis * 1000, ED_filt, 'Color', co(j,:), 'LineWidth', 1.2, ...
        'DisplayName', sprintf('\\alpha=%g', alphas(j)));
end
hold off;
xlabel('Time (ms)');
ylabel('E_D(t) = \Sigma \lambda_m c_m(t)^2');
title(sprintf('Surface Dirichlet Energy (Wave)  —  LH  %s band', bandNames(bandToPlot)), ...
    'FontSize', 12);
legend('Location', 'best');
grid on;

fprintf('\n=== Done ===\n');
