function plotBandPowerProfile(groupSignedL, groupSignedR, bandNames, opts)
%PLOTBANDPOWERPROFILE  Eigenmode power vs rank — overlaid bands
%
%   plotBandPowerProfile(groupSignedL, groupSignedR, bandNames)
%   plotBandPowerProfile(__, Name=Value)
%
%   Plots mean eigenmode power vs eigenmode rank across subjects.
%   By default, LH and RH power are summed into a single combined curve
%   and all frequency bands are overlaid on one figure.
%
%   Inputs
%   ------
%   groupSignedL : [nModes × nBands × nSubjects]
%       Per-mode signed-band power for left hemisphere.
%   groupSignedR : [nModes × nBands × nSubjects]
%       Per-mode signed-band power for right hemisphere.
%   bandNames    : string array [1 × nBands]
%       Labels for each frequency band (e.g. ["delta","theta","alpha",...]).
%
%   Name-Value Options
%   ------------------
%   SmoothN        : double (default = 20)
%       Moving-average smoothing window (number of modes).
%   SeparateHemis  : logical (default = false)
%       If true, plot LH and RH as separate curves per band (original
%       section-6 style tiled layout, one tile per band).
%       If false (default), sum L+R and overlay all bands on one axis.
%   ShowSEM        : logical (default = true)
%       Show SEM shading across subjects.
%   LogScale       : logical (default = false)
%       Use log scale on the Y-axis.
%   NormalizeByBand : logical (default = false)
%       Normalize each band's power to its own maximum (peak = 1),
%       making relative spectral shape comparable across bands.
%
%   Examples
%   --------
%   % Combined L+R, all bands overlaid (default)
%   plotBandPowerProfile(groupSignedL, groupSignedR, bandNames);
%
%   % Separate hemispheres, tiled per band
%   plotBandPowerProfile(groupSignedL, groupSignedR, bandNames, ...
%       SeparateHemis=true);
%
%   % Normalized overlay to compare spectral shapes
%   plotBandPowerProfile(groupSignedL, groupSignedR, bandNames, ...
%       NormalizeByBand=true);

    arguments
        groupSignedL  (:,:,:) double
        groupSignedR  (:,:,:) double
        bandNames     (1,:) string
        opts.SmoothN        (1,1) double {mustBePositive, mustBeInteger} = 20
        opts.SeparateHemis  (1,1) logical = false
        opts.ShowSEM        (1,1) logical = true
        opts.LogScale       (1,1) logical = false
        opts.NormalizeByBand (1,1) logical = false
    end

    [nModes, nBands, nSubjects] = size(groupSignedL);
    smoothN = opts.SmoothN;
    modeRank = (1:nModes)';

    %% ---- Separate hemispheres mode (tiled, one band per tile) ----

    if opts.SeparateHemis
        % Pre-compute global Y limits
        globalYmax = 0;
        globalYmin = Inf;
        for bi = 1:nBands
            for hData = {groupSignedL(:, bi, :), groupSignedR(:, bi, :)}
                hp = squeeze(hData{1});
                sm = movmean(mean(hp, 2), smoothN);
                se = movmean(std(hp, 0, 2) / sqrt(nSubjects), smoothN);
                globalYmax = max(globalYmax, max(sm + se));
                globalYmin = min(globalYmin, min(sm - se));
            end
        end
        globalYmin = max(0, globalYmin);

        figure('Name', 'Band Power vs Eigenmode Rank (LH/RH)', ...
            'NumberTitle', 'off', 'Position', [100 100 900 600]);
        tiledlayout(2, ceil(nBands/2), 'TileSpacing', 'compact', 'Padding', 'compact');

        for bi = 1:nBands
            nexttile;

            % LH
            powerL = squeeze(groupSignedL(:, bi, :));
            meanL  = movmean(mean(powerL, 2), smoothN);
            semL   = movmean(std(powerL, 0, 2) / sqrt(nSubjects), smoothN);
            if opts.ShowSEM
                fill([modeRank; flipud(modeRank)], ...
                     [meanL - semL; flipud(meanL + semL)], ...
                     [0.7 0.7 1], 'EdgeColor', 'none', 'FaceAlpha', 0.4);
            end
            hold on;
            plot(modeRank, meanL, 'b-', 'LineWidth', 1.5, 'DisplayName', 'LH');

            % RH
            powerR = squeeze(groupSignedR(:, bi, :));
            meanR  = movmean(mean(powerR, 2), smoothN);
            semR   = movmean(std(powerR, 0, 2) / sqrt(nSubjects), smoothN);
            if opts.ShowSEM
                fill([modeRank; flipud(modeRank)], ...
                     [meanR - semR; flipud(meanR + semR)], ...
                     [1 0.7 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.4);
            end
            plot(modeRank, meanR, 'r-', 'LineWidth', 1.5, 'DisplayName', 'RH');
            hold off;

            xlabel('Eigenmode rank');
            ylabel('Power');
            title(bandNames(bi));
            legend('Location', 'best', 'FontSize', 14);
            xlim([1 nModes]);
            ylim([globalYmin, globalYmax * 1.05]);
            if opts.LogScale, set(gca, 'YScale', 'log'); end
        end
        applyPlotDefaults(gcf);
        sgtitle(sprintf('Band Power vs Eigenmode Rank  (N = %d, smoothed %d)', ...
            nSubjects, smoothN), 'FontSize', 16, 'FontWeight', 'bold');
        return;
    end

    %% ---- Combined L+R, all bands overlaid ----

    % Sum hemispheres: [nModes × nBands × nSubjects]
    groupCombined = groupSignedL + groupSignedR;

    co = lines(nBands);

    figure('Name', 'Band Power vs Eigenmode Rank (combined)', ...
        'NumberTitle', 'off', 'Position', [100 100 800 450]);
    hold on;

    for bi = 1:nBands
        power = squeeze(groupCombined(:, bi, :));    % [nModes × nSubjects]
        mu    = movmean(mean(power, 2), smoothN);
        se    = movmean(std(power, 0, 2) / sqrt(nSubjects), smoothN);

        if opts.NormalizeByBand
            peakVal = max(mu);
            mu = mu / peakVal;
            se = se / peakVal;
        end

        % SEM shading
        if opts.ShowSEM
            fill([modeRank; flipud(modeRank)], ...
                 [mu - se; flipud(mu + se)], ...
                 co(bi,:), 'EdgeColor', 'none', 'FaceAlpha', 0.15, ...
                 'HandleVisibility', 'off');
        end

        plot(modeRank, mu, '-', 'Color', co(bi,:), 'LineWidth', 1.8, ...
            'DisplayName', bandNames(bi));
    end
    hold off;

    xlabel('Eigenmode rank');
    if opts.NormalizeByBand
        ylabel('Normalized power (peak = 1)');
    else
        ylabel('Power (LH + RH)');
    end
    title(sprintf('Band Power vs Eigenmode Rank  (N = %d, smoothed %d)', ...
        nSubjects, smoothN));
    legend('Location', 'best', 'FontSize', 14);
    xlim([1 nModes]);
    if opts.LogScale, set(gca, 'YScale', 'log'); end
    applyPlotDefaults(gcf);
end
