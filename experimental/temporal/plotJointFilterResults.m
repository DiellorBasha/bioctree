function plotJointFilterResults(result, opts)
%PLOTJOINTFILTERRESULTS  Visualize eigenmodeJointFilter output
%
%   plotJointFilterResults(result)
%   plotJointFilterResults(result, Name=Value)
%
%   Creates a suite of diagnostic and interpretive plots for the
%   eigenmodeJointFilter result struct.
%
%   Name-Value Options
%   ------------------
%   Hemi             : "lh" | "rh"  (default = "lh")
%       Hemisphere for 3D surface plots.
%   JointKernelPlot  : logical (default = true)
%       Show 2D joint kernel K(λ, f) heatmaps.
%   SpatialKernelPlot : logical (default = true)
%       Show 1D spatial kernel h(λ) curves.
%   TemporalKernelPlot : logical (default = true)
%       Show 1D temporal kernel ψ(f) curve.
%   SpectrumPlot     : logical (default = true)
%       Show unfiltered eigenmode PSD spectrogram.
%   FilteredSpectrumPlot : logical (default = true)
%       Show filtered eigenmode PSD spectrogram.
%   ScalePowerPlot   : logical (default = true)
%       Show vertex-level source power per scale.
%   ExampleTimeSeries : logical (default = true)
%       Show reconstructed time series from example window.
%   SourceExplorerPlot : logical (default = false)
%       Launch SourceExplorer for example window (requires SourceExplorer).
%   FsaveragePath    : string (default = "")
%       Path to fsaverage5 surf directory (for SourceExplorer).

    arguments
        result (1,1) struct
        opts.Hemi               (1,1) string {mustBeMember(opts.Hemi, ["lh","rh"])} = "lh"
        opts.JointKernelPlot    (1,1) logical = true
        opts.SpatialKernelPlot  (1,1) logical = true
        opts.TemporalKernelPlot (1,1) logical = true
        opts.SpectrumPlot       (1,1) logical = true
        opts.FilteredSpectrumPlot (1,1) logical = true
        opts.ScalePowerPlot     (1,1) logical = true
        opts.ExampleTimeSeries  (1,1) logical = true
        opts.SourceExplorerPlot (1,1) logical = false
        opts.FsaveragePath      (1,1) string  = ""
    end

    hemi = opts.Hemi;
    sf   = result.spatialFilter;
    tf   = result.temporalFilter;
    freqs = tf.freqs;
    nScales = sf.nScales;

    if hemi == "lh"
        lambdas    = sf.eigenvaluesL;
        spatialW   = sf.weightsL;
        jointK     = result.jointKernelL;
        psd        = result.coeffSpectrumL;
        srcPower   = result.srcPowerL;
        exSrc      = result.example.srcL;
        hLabel     = 'LH';
    else
        lambdas    = sf.eigenvaluesR;
        spatialW   = sf.weightsR;
        jointK     = result.jointKernelR;
        psd        = result.coeffSpectrumR;
        srcPower   = result.srcPowerR;
        exSrc      = result.example.srcR;
        hLabel     = 'RH';
    end

    nModes = numel(lambdas);
    titleSuffix = sprintf('(%s — %s × %s @ %.0f Hz)', ...
        hLabel, sf.kernelName, tf.kernelType, tf.centerFreqHz);

    %% ---- 1. Joint kernel heatmap K(λ, f) ----

    if opts.JointKernelPlot
        figure('Name', sprintf('Joint Kernel %s', titleSuffix), ...
            'NumberTitle', 'off', 'Position', [50 50 1000 600]);
        tiledlayout(2, ceil(nScales/2), 'TileSpacing', 'compact', 'Padding', 'compact');

        globalMax = max(abs(jointK(:)));

        for si = 1:nScales
            nexttile;
            imagesc(freqs, 1:nModes, jointK(:, :, si));
            set(gca, 'YDir', 'normal');
            caxis([0, globalMax]);
            colormap(parula(256));
            xlabel('Frequency (Hz)');
            ylabel('Eigenmode index');
            title(sf.scaleLabels(si));
        end

        cb = colorbar;
        cb.Layout.Tile = 'east';
        cb.Label.String = 'K(\lambda, f)';

        applyPlotDefaults(gcf);
        sgtitle(sprintf('Joint Filter Kernel  %s', titleSuffix), ...
            'FontSize', 16, 'FontWeight', 'bold');
    end

    %% ---- 2. Spatial kernel curves h(λ) ----

    if opts.SpatialKernelPlot
        figure('Name', sprintf('Spatial Kernels %s', hLabel), ...
            'NumberTitle', 'off', 'Position', [50 50 600 400]);

        co = lines(nScales);
        hold on;
        for si = 1:nScales
            plot(lambdas, spatialW(:, si), 'Color', co(si,:), ...
                'LineWidth', 1.5, 'DisplayName', sf.scaleLabels(si));
        end
        hold off;

        xlabel('\lambda (eigenvalue)');
        ylabel('h(\lambda)');
        title(sprintf('Spatial Filter Bank  %s  (%s)', hLabel, sf.kernelName));
        legend('Location', 'best', 'FontSize', 14);
        applyPlotDefaults(gcf);
    end

    %% ---- 3. Temporal kernel curve ψ(f) ----

    if opts.TemporalKernelPlot
        figure('Name', 'Temporal Kernel', 'NumberTitle', 'off', ...
            'Position', [50 50 600 300]);

        plot(freqs, tf.weights, 'b-', 'LineWidth', 2);
        xlabel('Frequency (Hz)');
        ylabel('\psi(f)');
        title(sprintf('Temporal Kernel:  %s  (center=%.1f Hz, bw=%.1f Hz)', ...
            tf.kernelType, tf.centerFreqHz, tf.bandwidthHz));
        applyPlotDefaults(gcf);
        xlim([0, freqs(end)]);
        ylim([0, 1.1]);

        % Mark center frequency and FWHM
        hold on;
        xline(tf.centerFreqHz, '--r', sprintf('%.0f Hz', tf.centerFreqHz), ...
            'LabelHorizontalAlignment', 'left', 'LineWidth', 1.2);
        yline(0.5, ':k', 'FWHM', 'LineWidth', 0.8);
        hold off;
    end

    %% ---- 4. Unfiltered eigenmode PSD spectrogram ----

    if opts.SpectrumPlot
        figure('Name', sprintf('Eigenmode PSD %s', hLabel), ...
            'NumberTitle', 'off', 'Position', [50 50 800 500]);

        psdDb = 10*log10(max(psd, eps));
        imagesc(freqs, 1:nModes, psdDb);
        set(gca, 'YDir', 'normal');
        colorbar;
        colormap(parula(256));
        xlabel('Frequency (Hz)');
        ylabel('Eigenmode index');
        title(sprintf('Unfiltered Eigenmode PSD  %s  (dB)', hLabel));
        applyPlotDefaults(gcf);
    end

    %% ---- 5. Filtered eigenmode spectrum ----

    if opts.FilteredSpectrumPlot
        % Show filtered PSD for the scale with max energy
        [~, bestScale] = max(squeeze(sum(sum(jointK.^2, 1), 2)));

        filtPsd = jointK(:, :, bestScale).^2 .* psd;
        filtPsdDb = 10*log10(max(filtPsd, eps));

        figure('Name', sprintf('Filtered PSD %s', hLabel), ...
            'NumberTitle', 'off', 'Position', [50 50 800 500]);

        imagesc(freqs, 1:nModes, filtPsdDb);
        set(gca, 'YDir', 'normal');
        colorbar;
        colormap(parula(256));
        xlabel('Frequency (Hz)');
        ylabel('Eigenmode index');
        title(sprintf('Filtered Eigenmode PSD  %s — %s  (dB)', ...
            hLabel, sf.scaleLabels(bestScale)));
        applyPlotDefaults(gcf);
    end

    %% ---- 6. Source power per scale ----

    if opts.ScalePowerPlot
        figure('Name', sprintf('Scale Source Power %s', hLabel), ...
            'NumberTitle', 'off', 'Position', [50 50 700 350]);

        scaleTotals = sum(srcPower, 1);   % [1 × nScales]
        bar(scaleTotals);
        xticks(1:nScales);
        xticklabels(sf.scaleLabels);
        xtickangle(30);
        xlabel('Spatial Scale');
        ylabel('Total Source RMS Power');
        title(sprintf('Source Power per Scale  %s  %s', hLabel, titleSuffix));
        applyPlotDefaults(gcf);
    end

    %% ---- 7. Example window: reconstructed time series ----

    if opts.ExampleTimeSeries && ~isempty(exSrc)
        tAxis = result.example.tAxis;

        figure('Name', sprintf('Example Window %s', hLabel), ...
            'NumberTitle', 'off', 'Position', [50 50 900 500]);
        tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

        % Top: eigenmode-level (pick top 10 modes by absolute amplitude)
        if hemi == "lh"
            exScale = result.example.scaleIdx;
            jK = result.jointKernelL(:, :, exScale);
        else
            exScale = result.example.scaleIdx;
            jK = result.jointKernelR(:, :, exScale);
        end
        modePower = sum(jK.^2, 2);   % energy in joint filter per mode
        [~, topModes] = sort(modePower, 'descend');
        topN = min(10, numel(topModes));
        topModes = topModes(1:topN);

        nexttile;
        % RMS across vertices for the example time series
        rmsTimeCourse = rms(exSrc, 1);  % [1 × winSamp]
        plot(tAxis, rmsTimeCourse, 'b-', 'LineWidth', 1.5);
        xlabel('Time (s)');
        ylabel('RMS amplitude');
        title(sprintf('Filtered Source RMS — %s  (%s)', ...
            hLabel, result.example.scaleLabel));

        nexttile;
        % Show top-3 vertex time courses
        vertPower = sum(exSrc.^2, 2);
        [~, topVerts] = sort(vertPower, 'descend');
        topV = min(5, numel(topVerts));
        co = lines(topV);
        hold on;
        for vi = 1:topV
            plot(tAxis, exSrc(topVerts(vi), :), 'Color', [co(vi,:) 0.7], ...
                'LineWidth', 1.0, 'DisplayName', sprintf('v%d', topVerts(vi)));
        end
        hold off;
        xlabel('Time (s)');
        ylabel('Amplitude');
        title(sprintf('Top %d vertices by power — %s  (%s)', ...
            topV, hLabel, result.example.scaleLabel));
        legend('Location', 'best', 'FontSize', 14);

        applyPlotDefaults(gcf);
        sgtitle(sprintf('Example Reconstructed Window  %s', titleSuffix), ...
            'FontSize', 16, 'FontWeight', 'bold');
    end

    %% ---- 8. SourceExplorer (optional) ----

    if opts.SourceExplorerPlot && ~isempty(exSrc)
        if opts.FsaveragePath == ""
            warning('plotJointFilterResults:NoPath', ...
                'SourceExplorer requires FsaveragePath. Skipping.');
        else
            surfFile = fullfile(opts.FsaveragePath, sprintf('%s.pial', hemi));
            [verts, faces] = mne_read_surface(surfFile);
            M = bct.Manifold(verts, faces);

            SourceExplorer(M, abs(exSrc), result.example.tAxis, ...
                TimePoint=result.example.tAxis(1), ...
                Title=sprintf('JointFilter %s — %s', hLabel, result.example.scaleLabel));
        end
    end

    %% ---- 9. Joint filter passband summary ----

    figure('Name', 'Joint Filter Summary', 'NumberTitle', 'off', ...
        'Position', [50 50 700 450]);

    % 2D marginal view: sum across λ and sum across f
    marginalLambda = squeeze(sum(jointK, 2));   % [nModes × nScales]
    marginalFreq   = squeeze(sum(jointK, 1));   % [nFreqs × nScales]

    tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    co = lines(nScales);
    hold on;
    for si = 1:nScales
        plot(lambdas, marginalLambda(:, si), 'Color', co(si,:), ...
            'LineWidth', 1.5, 'DisplayName', sf.scaleLabels(si));
    end
    hold off;
    xlabel('\lambda (eigenvalue)');
    ylabel('\Sigma_f K(\lambda, f)');
    title('Spatial Marginal');
    legend('Location', 'best', 'FontSize', 14);

    nexttile;
    hold on;
    for si = 1:nScales
        plot(freqs, marginalFreq(:, si), 'Color', co(si,:), ...
            'LineWidth', 1.5, 'DisplayName', sf.scaleLabels(si));
    end
    hold off;
    xlabel('Frequency (Hz)');
    ylabel('\Sigma_\lambda K(\lambda, f)');
    title('Temporal Marginal');
    legend('Location', 'best', 'FontSize', 14);

    applyPlotDefaults(gcf);
    sgtitle(sprintf('Joint Filter Marginals  %s', titleSuffix), ...
        'FontSize', 16, 'FontWeight', 'bold');
end
