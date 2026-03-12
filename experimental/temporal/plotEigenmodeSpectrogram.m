function [fig, ax] = plotEigenmodeSpectrogram(psd, eigenvalues, freqs, opts)
%PLOTEIGENMODESPECTROGRAM  Eigenmode × frequency power spectrogram
%
%   plotEigenmodeSpectrogram(psd, eigenvalues, freqs)
%   plotEigenmodeSpectrogram(psd, eigenvalues, freqs, Name=Value)
%   [fig, ax] = plotEigenmodeSpectrogram(__)
%
%   Displays a 2-D heatmap of power spectral density with eigenvalues
%   (spatial scale) on the Y-axis and temporal frequency on the X-axis.
%
%   Inputs
%   ------
%   psd         : [nModes × nFreqs]  or  [nModes × nFreqs × nSubjects]
%       Power spectral density.  If 3-D, averaged across dim-3 first.
%   eigenvalues : [nModes × 1]  or  [nModes × nSubjects]
%       Eigenvalues for the Y-axis.  If 2-D, averaged across dim-2.
%   freqs       : [1 × nFreqs] or [nFreqs × 1]
%       Temporal frequency axis in Hz.
%
%   Name-Value Options
%   ------------------
%   Binning      : logical (default = true)
%       Bin eigenmodes by rank for a smoother image.
%   ModesPerBin  : double  (default = 10)
%       Number of modes per bin (ignored when Binning=false).
%   LogEigenvalue : logical (default = false)
%       Use log₁₀ eigenvalue axis (pcolor + shading flat).
%   LogFrequency  : logical (default = false)
%       Use log₁₀ frequency axis.
%   CDataScale   : "dB" | "linear" | "log10" | "zscore"  (default = "dB")
%       Scaling for the color-mapped values.
%   CLim         : [1×2] double (default = [])
%       Manual color limits [cmin cmax].  Empty = auto.
%   Colormap     : (default = parula(256))
%       Colormap matrix or name string.
%   FreqRange    : [1×2] double (default = [])
%       Restrict display to [fmin fmax] Hz.  Empty = full range.
%   EigenRange   : [1×2] double (default = [])
%       Restrict display to [λmin λmax].  Empty = full range.
%   Title        : string (default = "Eigenmode PSD Spectrogram")
%       Figure title.
%   NSubjects    : double (default = NaN)
%       If provided, appended to title as "(N = ...)".
%   Transpose    : logical (default = false)
%       If true, eigenvalues on X-axis and frequency on Y-axis.
%   YAxis        : "eigenvalue" | "rank"  (default = "eigenvalue")
%       Y-axis type: eigenvalue magnitude or eigenmode rank index.
%   BandLines    : [1×N] double (default = [])
%       Draw vertical (or horizontal if transposed) band-boundary lines
%       at these frequencies (Hz), e.g. [4 8 12 30].
%   WavelengthMarkers : struct array (default = [])
%       Lines at specific eigenmodes with wavelength annotation.
%       Each element must have fields:
%         .eigenvalue  — eigenvalue λ
%         .wavelength  — wavelength in mm (ell = 2π/sqrt(λ))
%         .label       — string label (e.g. "#5  ℓ=120 mm")
%         .rank        — (optional) eigenmode rank for YAxis="rank"
%
%   Outputs (optional)
%   -------
%   fig : figure handle
%   ax  : axes handle
%
%   Examples
%   --------
%   % Default binned dB spectrogram
%   plotEigenmodeSpectrogram(grandPsd, grandLambda, freqs);
%
%   % Log eigenvalue axis, z-score scaling, custom color limits
%   plotEigenmodeSpectrogram(grandPsd, grandLambda, freqs, ...
%       LogEigenvalue=true, CDataScale="zscore", CLim=[-2 4]);
%
%   % Raw (unbinned), linear power, restricted frequency range
%   plotEigenmodeSpectrogram(grandPsd, grandLambda, freqs, ...
%       Binning=false, CDataScale="linear", FreqRange=[4 30]);
%
%   See also eigenmodeGroupAnalysis, eigenmodeAnalysis

    arguments
        psd          double
        eigenvalues  double
        freqs        (:,1) double
        opts.Binning       (1,1) logical = true
        opts.ModesPerBin   (1,1) double {mustBePositive, mustBeInteger} = 10
        opts.LogEigenvalue (1,1) logical = false
        opts.LogFrequency  (1,1) logical = false
        opts.CDataScale    (1,1) string {mustBeMember(opts.CDataScale, ...
                                  ["dB","linear","log10","zscore"])} = "dB"
        opts.CLim          double = []
        opts.Colormap               = parula(256)
        opts.FreqRange     double   = []
        opts.EigenRange    double   = []
        opts.Title         (1,1) string = "Eigenmode PSD Spectrogram"
        opts.NSubjects     (1,1) double = NaN
        opts.Transpose     (1,1) logical = false
        opts.YAxis         (1,1) string {mustBeMember(opts.YAxis, ...
                                  ["eigenvalue","rank"])} = "eigenvalue"
        opts.BandLines     (1,:) double = []
        opts.WavelengthMarkers         = []
    end

    freqs = freqs(:);

    %% ---- Average across subjects if 3-D ----

    if ndims(psd) == 3
        psd = mean(psd, 3);
    end
    if size(eigenvalues, 2) > 1
        eigenvalues = mean(eigenvalues, 2);
    end
    eigenvalues = eigenvalues(:);

    %% ---- Sort by eigenvalue ----

    [eigenvalues, sortOrd] = sort(eigenvalues, 'ascend');
    psd = psd(sortOrd, :);

    %% ---- Optional frequency range restriction ----

    if ~isempty(opts.FreqRange)
        fMask = freqs >= opts.FreqRange(1) & freqs <= opts.FreqRange(2);
        freqs = freqs(fMask);
        psd   = psd(:, fMask);
    end

    %% ---- Optional eigenvalue range restriction ----

    if ~isempty(opts.EigenRange)
        eMask = eigenvalues >= opts.EigenRange(1) & eigenvalues <= opts.EigenRange(2);
        eigenvalues = eigenvalues(eMask);
        psd = psd(eMask, :);
    end

    nFreqs = numel(freqs);

    %% ---- Binning ----

    if opts.Binning
        nModes  = numel(eigenvalues);
        nBins   = ceil(nModes / opts.ModesPerBin);
        specPsd = zeros(nBins, nFreqs);
        specLam = zeros(nBins, 1);
        specRank = zeros(nBins, 1);
        for bi = 1:nBins
            r1 = (bi-1) * opts.ModesPerBin + 1;
            r2 = min(bi * opts.ModesPerBin, nModes);
            specPsd(bi, :) = mean(psd(r1:r2, :), 1);
            specLam(bi)    = mean(eigenvalues(r1:r2));
            specRank(bi)   = mean(r1:r2);
        end
        if opts.YAxis == "rank"
            yLabel = sprintf('Eigenmode rank (binned, %d/bin)', opts.ModesPerBin);
        else
            yLabel = sprintf('Eigenvalue (binned, %d modes/bin)', opts.ModesPerBin);
        end
    else
        specPsd  = psd;
        specLam  = eigenvalues;
        specRank = (1:numel(eigenvalues))';
        if opts.YAxis == "rank"
            yLabel = 'Eigenmode rank';
        else
            yLabel = 'Eigenvalue';
        end
    end

    % Select y-axis values based on YAxis option
    if opts.YAxis == "rank"
        specY = specRank;
    else
        specY = specLam;
    end

    %% ---- CData scaling ----

    switch opts.CDataScale
        case "dB"
            Z = 10 * log10(max(specPsd, eps));
            cbLabel = 'Power (dB)';
        case "linear"
            Z = specPsd;
            cbLabel = 'Power';
        case "log10"
            Z = log10(max(specPsd, eps));
            cbLabel = 'log_{10}(Power)';
        case "zscore"
            Z = (specPsd - mean(specPsd, 'all')) / std(specPsd, 0, 'all');
            cbLabel = 'z-score';
    end

    %% ---- Create figure ----

    fig = figure('Name', char(opts.Title), 'NumberTitle', 'off', ...
        'Position', [100 100 900 550]);

    % Determine rendering method based on log axes
    usePC = (opts.YAxis == "eigenvalue" && opts.LogEigenvalue) || opts.LogFrequency;

    % Prepare axis vectors
    xAx = freqs;  yAx = specY;
    if opts.YAxis == "eigenvalue" && opts.LogEigenvalue
        yAx = log10(max(yAx, eps));
    end
    if opts.LogFrequency,  xAx = log10(max(xAx, eps)); end

    % Build labels
    if opts.YAxis == "eigenvalue" && opts.LogEigenvalue
        eLabelStr = sprintf('log_{10}(%s)', yLabel);
    else
        eLabelStr = yLabel;
    end
    if opts.LogFrequency
        fLabelStr = 'log_{10}(Frequency) (Hz)';
    else
        fLabelStr = 'Frequency (Hz)';
    end

    % Transpose: swap eigenvalue ↔ frequency axes
    if opts.Transpose
        plotX = yAx;  plotY = xAx;  plotZ = Z';
        xLabelStr = eLabelStr;  yLabelStr = fLabelStr;
    else
        plotX = xAx;  plotY = yAx;  plotZ = Z;
        xLabelStr = fLabelStr;  yLabelStr = eLabelStr;
    end

    if usePC
        pcolor(plotX, plotY, plotZ);
        shading flat;
    else
        imagesc(plotX, plotY, plotZ);
        set(gca, 'YDir', 'normal');
    end
    xlabel(xLabelStr);
    ylabel(yLabelStr);

    %% ---- Color limits, colorbar, colormap ----

    if ~isempty(opts.CLim)
        caxis(opts.CLim);
    end

    cb = colorbar;
    cb.Label.String = cbLabel;

    if ischar(opts.Colormap) || isstring(opts.Colormap)
        colormap(gca, feval(opts.Colormap, 256));
    else
        colormap(gca, opts.Colormap);
    end

    %% ---- Title ----

    if ~isnan(opts.NSubjects)
        titleStr = sprintf('%s  (N = %d)', opts.Title, opts.NSubjects);
    else
        titleStr = opts.Title;
    end
    title(titleStr);

    %% ---- Band boundary lines ----

    if ~isempty(opts.BandLines)
        hold on;
        for bi = 1:numel(opts.BandLines)
            bFreq = opts.BandLines(bi);
            if opts.LogFrequency, bFreq = log10(max(bFreq, eps)); end
            if opts.Transpose
                % Frequency on y-axis → horizontal line
                yline(bFreq, '-', 'Color', 'w', 'LineWidth', 0.8, 'Alpha', 0.6);
            else
                % Frequency on x-axis → vertical line
                xline(bFreq, '-', 'Color', 'w', 'LineWidth', 0.8, 'Alpha', 0.6);
            end
        end
        hold off;
    end

    %% ---- Wavelength markers ----

    if ~isempty(opts.WavelengthMarkers)
        hold on;
        for wi = 1:numel(opts.WavelengthMarkers)
            mk = opts.WavelengthMarkers(wi);

            % Determine position on the eigenvalue/rank axis
            if opts.YAxis == "rank"
                if isfield(mk, 'rank') && ~isempty(mk.rank)
                    lamPos = mk.rank;
                else
                    % Find nearest rank by eigenvalue match
                    [~, nearIdx] = min(abs(eigenvalues - mk.eigenvalue));
                    lamPos = nearIdx;
                end
            else
                lamPos = mk.eigenvalue;
                if opts.LogEigenvalue
                    lamPos = log10(max(lamPos, eps));
                end
            end
            if opts.Transpose
                % Eigenvalue on x-axis → vertical line
                xline(lamPos, '-w', 'LineWidth', 1.5, 'Alpha', 0.9);
                text(lamPos, plotY(end), sprintf('  %s', mk.label), ...
                    'Color', 'w', 'FontSize', 14, 'FontWeight', 'bold', ...
                    'VerticalAlignment', 'top', 'HorizontalAlignment', 'left');
            else
                % Eigenvalue on y-axis → horizontal line
                yline(lamPos, '-w', 'LineWidth', 1.5, 'Alpha', 0.9);
                text(plotX(end), lamPos, sprintf('  %s', mk.label), ...
                    'Color', 'w', 'FontSize', 14, 'FontWeight', 'bold', ...
                    'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right');
            end
        end
        hold off;
    end

    applyPlotDefaults(fig);
    ax = gca;
end
