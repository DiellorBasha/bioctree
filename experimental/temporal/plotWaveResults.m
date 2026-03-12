function plotWaveResults(result, opts)
%PLOTWAVERESULTS  Plot all visualizations for eigenmodeWaveFilter results
%
%   plotWaveResults(result)
%   plotWaveResults(result, Name=Value)
%
%   Takes the result struct from eigenmodeWaveFilter_function and produces
%   all standard diagnostic plots.  Each plot section can be enabled or
%   disabled individually.
%
%   Inputs
%   ------
%   result : struct from eigenmodeWaveFilter_function
%
%   Name-Value Options
%   ------------------
%   Hemi             : "lh" | "rh"  (default "lh")
%   SourceExplorer   : logical  (default true)   Interactive 3D viewer
%   KernelPlot       : logical  (default true)   2D kernel heatmap
%   DispersionPlot   : logical  (default true)   omega vs lambda
%   TimeAvgMaps      : logical  (default true)   Time-averaged source maps
%   SpectralEnergy   : logical  (default true)   Mode energy over time
%   DirichletEnergy  : logical  (default true)   Surface Dirichlet energy
%   KernelTimeMs     : double   (default 500)    Kernel plot time span (ms)
%
%   See also eigenmodeWaveFilter_function

    arguments
        result    (1,1) struct
        opts.Hemi            (1,1) string {mustBeMember(opts.Hemi, ["lh","rh"])} = "lh"
        opts.SourceExplorer  (1,1) logical = true
        opts.KernelPlot      (1,1) logical = true
        opts.DispersionPlot  (1,1) logical = true
        opts.TimeAvgMaps     (1,1) logical = true
        opts.SpectralEnergy  (1,1) logical = true
        opts.DirichletEnergy (1,1) logical = true
        opts.KernelTimeMs    (1,1) double {mustBePositive} = 500
    end

    % Unpack based on hemisphere
    if opts.Hemi == "lh"
        filtSrc   = result.filtSrcL;
        srcOrig   = result.srcOrigL;
        kernel    = result.kernelL;
        omega     = result.omegaL;
        coeffs    = result.coeffsL;
        lambda    = result.filter.eigenvaluesL;
        lmax      = result.filter.lmaxL;
        V         = result.fsaverage5.lh.vertices;
        F         = result.fsaverage5.lh.faces;
        hemiLabel = "LH";
    else
        filtSrc   = result.filtSrcR;
        srcOrig   = result.srcOrigR;
        kernel    = result.kernelR;
        omega     = result.omegaR;
        coeffs    = result.coeffsR;
        lambda    = result.filter.eigenvaluesR;
        lmax      = result.filter.lmaxR;
        V         = result.fsaverage5.rh.vertices;
        F         = result.fsaverage5.rh.faces;
        hemiLabel = "RH";
    end

    alphas   = result.filter.alphas;
    beta     = result.filter.beta;
    isDamped = result.filter.isDamped;
    nAlphas  = numel(alphas);

    bandName = result.meta.bandFiltered;
    tAxis    = result.meta.tAxis;
    tWin     = result.meta.tWin;
    sfreq    = result.meta.sfreq;
    winSamp  = result.meta.winSamp;
    nModes   = numel(lambda);

    bandIdx  = result.meta.bandToFilter;
    cL       = coeffs(:, :, bandIdx);   % [nModes x winSamp]

    if isDamped
        filterLabel = "Damped Wave";
    else
        filterLabel = "Wave";
    end

    bwr = interp1([0 0.5 1], [0 0 1; 1 1 1; 1 0 0], linspace(0,1,256));

    %% SourceExplorer
    if opts.SourceExplorer
        M = bct.Manifold(V, F);

        % Unfiltered — magnitude
        SourceExplorer(M, abs(srcOrig), tWin, ...
            TimePoint=tWin(round(end/2)), ...
            Title=sprintf("Unfiltered |source| — %s %s band", hemiLabel, bandName));

        % Filtered at each alpha — magnitude
        for j = 1:nAlphas
            SourceExplorer(M, abs(filtSrc{j}), tWin, ...
                TimePoint=tWin(round(end/2)), ...
                Title=sprintf("%s |source| \\alpha=%g — %s %s band", ...
                    filterLabel, alphas(j), hemiLabel, bandName));
        end
    end

    %% Kernel heatmap: g(lambda, t)
    if opts.KernelPlot
        tShow     = min(winSamp, round(opts.KernelTimeMs/1000 * sfreq));
        tSampShow = 0:tShow-1;
        lambdaGrid = linspace(0, lmax, 200);

        figure('Name', sprintf('JTV %s Kernel g(lambda, t)', filterLabel), ...
            'NumberTitle', 'off', 'Position', [100 100 300*nAlphas 300]);
        tiledlayout(1, nAlphas, 'TileSpacing', 'compact', 'Padding', 'compact');

        for j = 1:nAlphas
            nexttile;
            omegaGrid = acos(1 - alphas(j)^2 * lambdaGrid(:) / (2*lmax));
            K = cos(omegaGrid * tSampShow);
            if isDamped
                dampEnv = exp(-beta * tSampShow / sfreq);
                K = K .* dampEnv;
            end
            imagesc(tSampShow / sfreq * 1000, lambdaGrid, K);
            set(gca, 'YDir', 'normal');
            xlabel('Time (ms)');
            ylabel('\lambda');
            title(sprintf('\\alpha = %g', alphas(j)));
            colorbar;
            caxis([-1 1]);
            colormap(gca, bwr);
        end

        if isDamped
            sgtitle(sprintf('JTV Damped Wave Kernel  (\\beta = %g)  —  %s band', ...
                beta, bandName), 'FontSize', 16, 'FontWeight', 'bold');
        else
            sgtitle(sprintf('JTV Wave Kernel  g(\\lambda, t) = cos(\\omega_m \\cdot t)  \u2014  %s band', ...
                bandName), 'FontSize', 16, 'FontWeight', 'bold');
        end
        applyPlotDefaults(gcf);
    end

    %% Dispersion relation
    if opts.DispersionPlot
        figure('Name', 'Dispersion Relation', 'NumberTitle', 'off', ...
            'Position', [100 100 600 400]);
        hold on;
        co = lines(nAlphas);
        for j = 1:nAlphas
            plot(lambda, omega{j}, 'Color', co(j,:), 'LineWidth', 1.5, ...
                'DisplayName', sprintf('\\alpha = %g', alphas(j)));
        end
        hold off;
        xlabel('\lambda  (eigenvalue)');
        ylabel('\omega_m  (rad/sample)');
        title(sprintf('%s Dispersion:  \\omega_m = acos(1 - \\alpha^2 \\lambda_m / 2\\lambda_{max})', ...
            filterLabel));
        legend('Location', 'best');

        % Secondary axis: frequency in Hz
        yyaxis right;
        ylabel('f_m  (Hz)');
        ylim(ylim(gca) / (2*pi) * sfreq);
        applyPlotDefaults(gcf);
    end

    %% Time-averaged source maps
    if opts.TimeAvgMaps
        avgOrig = abs(mean(srcOrig, 2));

        figure('Name', sprintf('Time-Averaged Source Maps — %s', hemiLabel), ...
            'NumberTitle', 'off', ...
            'Position', [100 50 400*(nAlphas+1) 350]);
        tiledlayout(1, nAlphas+1, 'TileSpacing', 'compact', 'Padding', 'compact');

        % Unfiltered
        nexttile;
        trisurf(F, V(:,1), V(:,2), V(:,3), avgOrig, ...
            'EdgeColor', 'none', 'FaceColor', 'interp');
        axis equal off; colorbar; lighting gouraud; camlight headlight; material dull;
        mu = mean(avgOrig); sd = std(avgOrig);
        if sd > 0; caxis([max(0, mu-4*sd), mu+4*sd]); end
        title('Unfiltered');

        % Filtered at each alpha
        for j = 1:nAlphas
            nexttile;
            avgFilt = abs(mean(filtSrc{j}, 2));
            trisurf(F, V(:,1), V(:,2), V(:,3), avgFilt, ...
                'EdgeColor', 'none', 'FaceColor', 'interp');
            axis equal off; colorbar; lighting gouraud; camlight headlight; material dull;
            mu = mean(avgFilt); sd = std(avgFilt);
            if sd > 0; caxis([max(0, mu-4*sd), mu+4*sd]); end
            title(sprintf('\\alpha = %g', alphas(j)));
        end
        applyPlotDefaults(gcf);
        sgtitle(sprintf('Time-Averaged |Source|  \u2014  %s  %s band  (%s)', ...
            hemiLabel, bandName, filterLabel), 'FontSize', 16, 'FontWeight', 'bold');
    end

    %% Spectral energy over time
    if opts.SpectralEnergy
        modeBands = {1:round(nModes*0.1), ...
                     round(nModes*0.1)+1:round(nModes*0.5), ...
                     round(nModes*0.5)+1:nModes};
        modeBandLabels = ["Low modes (0-10%)", "Mid modes (10-50%)", "High modes (50-100%)"];

        figure('Name', sprintf('Spectral Energy Over Time (%s)', filterLabel), ...
            'NumberTitle', 'off', 'Position', [100 100 500 700]);
        tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

        for mb = 1:3
            nexttile;
            modes = modeBands{mb};
            E_orig = sum(cL(modes, :).^2, 1);
            plot(tAxis * 1000, E_orig, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Unfiltered');
            hold on;
            co = lines(nAlphas);
            for j = 1:nAlphas
                filtC = kernel{j}(modes, :) .* cL(modes, :);
                E_filt = sum(filtC.^2, 1);
                plot(tAxis * 1000, E_filt, 'Color', co(j,:), 'LineWidth', 1.2, ...
                    'DisplayName', sprintf('\\alpha=%g', alphas(j)));
            end
            hold off;
            xlabel('Time (ms)');
            ylabel('Energy');
            title(modeBandLabels(mb));
            legend('Location', 'best', 'FontSize', 14);
        end
        applyPlotDefaults(gcf);
        sgtitle(sprintf('Eigenmode Energy vs Time (%s)  \u2014  %s  %s band', ...
            filterLabel, hemiLabel, bandName), 'FontSize', 16, 'FontWeight', 'bold');
    end

    %% Surface Dirichlet energy
    if opts.DirichletEnergy
        figure('Name', sprintf('Surface Dirichlet Energy (%s)', filterLabel), ...
            'NumberTitle', 'off', 'Position', [100 100 600 350]);

        ED_orig = lambda' * cL.^2;
        plot(tAxis * 1000, ED_orig, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Unfiltered');
        hold on;
        co = lines(nAlphas);
        for j = 1:nAlphas
            filtC = kernel{j} .* cL;
            ED_filt = lambda' * filtC.^2;
            plot(tAxis * 1000, ED_filt, 'Color', co(j,:), 'LineWidth', 1.2, ...
                'DisplayName', sprintf('\\alpha=%g', alphas(j)));
        end
        hold off;
        xlabel('Time (ms)');
        ylabel('E_D(t) = \Sigma \lambda_m c_m(t)^2');
        title(sprintf('Surface Dirichlet Energy (%s)  —  %s  %s band', ...
            filterLabel, hemiLabel, bandName));
        legend('Location', 'best');
        applyPlotDefaults(gcf);
    end

end
