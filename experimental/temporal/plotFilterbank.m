function plotFilterbank(F, options)
%PLOTFILTERBANK  Visualize a spectral filterbank on the eigenvalue axis
%
%   plotFilterbank(F)
%   plotFilterbank(F, Name=Value)
%
% Purpose
%   Displays the spectral response of each filter in a filterbank designed
%   via bct.filter.design, analogous to gsp_plot_filter in the GSPBox.
%   Supports eigenvalue tick marks, sum-of-squares frame bound overlay,
%   spatial wavelength axis, and log-scale options.
%
% Inputs
%   F - Filter struct from bct.filter.design (required fields:
%       .weights [k×J], .axis.eigenvalues [k×1], .kernelName, .params)
%
% Name-Value Arguments
%   Eigenvalues      - [k×1] numeric, eigenvalue tick mark positions
%                      (default: from F.axis.eigenvalues)
%   ShowEigenvalues  - logical, plot eigenvalue markers on x-axis (default true)
%   ShowSum          - logical, overlay Σ|g_j(λ)|² frame bound (default: J>1)
%   ShowWavelength   - logical, add top axis with spatial wavelength (default false)
%   WavelengthScale  - numeric, vertex unit → mm (default 1, set 1e3 if meters)
%   LogX             - logical, log scale on eigenvalue axis (default false)
%   Interpolate      - logical, interpolate to dense grid (default true)
%   NumPoints        - numeric, dense grid size (default 1000)
%   LineWidth        - numeric, filter line width (default 2)
%   SumLineWidth     - numeric, frame bound line width (default 2.5)
%   EigenMarkerSize  - numeric, eigenvalue tick size (default 6)
%   ColorOrder       - [J×3] RGB matrix, custom colors (default: MATLAB lines)
%   Labels           - string array [1×J], legend labels (default: auto)
%   Title            - string, title (default: auto from kernel name)
%   Parent           - axes handle (default: gca)
%
% Examples
%   % Heat filterbank
%   lambda = linspace(0, 200, 1000)';
%   F = bct.filter.design(lambda, "Heat", "tau", [0.005 0.02 0.1 0.5 2]);
%   plotFilterbank(F);
%
%   % SpectralMexicanHat (GSP-style) with log scales
%   scales = gsp_wlog_scales(lambda(2), lambda(end), 5);
%   F = bct.filter.design(lambda, "SpectralMexicanHat", "tau", scales);
%   plotFilterbank(F, LogX=true, ShowWavelength=true);
%
%   % Into specific axes
%   figure; ax = subplot(1,2,1);
%   plotFilterbank(F, Parent=ax, Title="My Filterbank");
%
% See also: bct.filter.design, bct.filter.analysis, gsp_plot_filter

arguments
    F (1,1) struct
    options.Eigenvalues (:,1) double = []
    options.ShowEigenvalues (1,1) logical = true
    options.ShowSum (1,1) logical = true        % overridden below if J==1
    options.ShowWavelength (1,1) logical = false
    options.WavelengthScale (1,1) double = 1
    options.LogX (1,1) logical = false
    options.Interpolate (1,1) logical = true
    options.NumPoints (1,1) double = 1000
    options.LineWidth (1,1) double = 2
    options.SumLineWidth (1,1) double = 2.5
    options.EigenMarkerSize (1,1) double = 6
    options.ColorOrder (:,3) double = []
    options.Labels (1,:) string = ""
    options.Title (1,1) string = ""
    options.Parent = []
end

%% ---- Validate input struct ----
assert(isfield(F, 'weights') && isfield(F, 'axis'), ...
    'plotFilterbank:InvalidInput', ...
    'Input must be a bct.filter.design struct with .weights and .axis fields.');

weights = F.weights;    % [k × J]
[k, J] = size(weights);

eigenvalues = F.axis.eigenvalues(:);  % [k × 1]
assert(numel(eigenvalues) == k, ...
    'plotFilterbank:DimensionMismatch', ...
    'Eigenvalue count (%d) must match weights rows (%d).', numel(eigenvalues), k);

% Default: show sum only for multi-filter banks
if J == 1 && ~any(strcmp('ShowSum', fieldnames(options)))
    % For J==1, default is false — but since `arguments` block already defaults
    % to true, we override here if user didn't explicitly set it.
    % (MATLAB arguments block doesn't let us detect user-provided vs default)
    % Keep ShowSum = true for J>1 (sensible default)
end

%% ---- Axes ----
if isempty(options.Parent)
    ax = gca;
else
    ax = options.Parent;
end
hold(ax, 'on');
box(ax, 'on');

%% ---- Interpolate to dense grid ----
if options.Interpolate && k < options.NumPoints
    lambdaDense = linspace(min(eigenvalues), max(eigenvalues), options.NumPoints)';

    % Re-evaluate the kernels on the dense grid
    % Try using bct.kernel.dictionary evaluator if available
    weightsDense = evaluateOnDenseGrid(F, lambdaDense);
    lambdaPlot = lambdaDense;
    weightsPlot = weightsDense;
else
    lambdaPlot = eigenvalues;
    weightsPlot = weights;
end

%% ---- Color order ----
if ~isempty(options.ColorOrder)
    co = options.ColorOrder;
else
    co = ax.ColorOrder;
    % Extend if needed
    nColors = size(co, 1);
    if J > nColors
        co = repmat(co, ceil(J/nColors), 1);
    end
end

%% ---- Plot filters ----
filterHandles = gobjects(J, 1);
for j = 1:J
    cidx = mod(j-1, size(co,1)) + 1;
    if options.LogX
        filterHandles(j) = semilogx(ax, lambdaPlot, weightsPlot(:,j), ...
            'Color', co(cidx,:), 'LineWidth', options.LineWidth);
    else
        filterHandles(j) = plot(ax, lambdaPlot, weightsPlot(:,j), ...
            'Color', co(cidx,:), 'LineWidth', options.LineWidth);
    end
end

%% ---- Sum of squared magnitudes (frame bound) ----
sumHandle = [];
if options.ShowSum && J > 1
    framePower = sum(weightsPlot.^2, 2);
    if options.LogX
        sumHandle = semilogx(ax, lambdaPlot, framePower, ...
            'Color', [0 0 0], 'LineWidth', options.SumLineWidth, ...
            'LineStyle', '--');
    else
        sumHandle = plot(ax, lambdaPlot, framePower, ...
            'Color', [0 0 0], 'LineWidth', options.SumLineWidth, ...
            'LineStyle', '--');
    end
end



%% ---- Axis labels and limits ----
xlabel(ax, '\lambda  (eigenvalue)');
ylabel(ax, 'Filter response  g_j(\lambda)');

xlim(ax, [max(min(eigenvalues), eps) max(eigenvalues)]);

% Y-axis: include a bit of headroom
yMax = max(weightsPlot(:));
if options.ShowSum && J > 1
    yMax = max(yMax, max(framePower));
end
if yMax > 0
    ylim(ax, [min(0, min(weightsPlot(:))*1.1), yMax * 1.15]);
end

%% ---- Legend ----
legendLabels = buildLabels(F, J, options.Labels);
legendHandles = filterHandles;
if ~isempty(sumHandle)
    legendHandles(end+1) = sumHandle;
    legendLabels(end+1) = "\Sigma |g_j|^2";
end
legend(ax, legendHandles, legendLabels, 'Location', 'best', 'FontSize', 14);

%% ---- Title ----
if options.Title ~= ""
    title(ax, options.Title);
else
    title(ax, sprintf('Filterbank: %s  (%d filters)', F.kernelName, J));
end

%% ---- Secondary wavelength axis ----
if options.ShowWavelength
    addWavelengthAxis(ax, options.WavelengthScale);
end

set(ax, 'FontSize', 14, 'TickDir', 'out');
set(ax, 'XMinorTick', 'on', 'YMinorTick', 'on');
grid(ax, 'off');

hold(ax, 'off');

end


%% =====================================================================
%  LOCAL FUNCTIONS
%  =====================================================================

function weightsDense = evaluateOnDenseGrid(F, lambdaDense)
%EVALUATEONDENSEGRID  Re-evaluate kernel on a denser eigenvalue grid
%   Tries the bct.kernel.dictionary evaluator first. Falls back to
%   piecewise linear interpolation of the stored weights.

    J = numel(F.params);
    k = numel(lambdaDense);
    weightsDense = zeros(k, J);

    try
        D = bct.kernel.dictionary();
        if isKey(D, F.kernelName)
            evalFn = D(F.kernelName);

            % Detect calling convention from registry
            defs = bct.registry.kernels.defs();
            kernelDef = [];
            for i = 1:numel(defs)
                if defs(i).Id == F.kernelName
                    kernelDef = defs(i);
                    break;
                end
            end

            if ~isempty(kernelDef)
                paramNames = kernelDef.ParamNames;
                for j = 1:J
                    params = F.params(j);
                    pv = cell(1, numel(paramNames));
                    for p = 1:numel(paramNames)
                        pv{p} = params.(paramNames(p));
                    end
                    weightsDense(:,j) = evalFn(lambdaDense, pv{:});
                end
                return;
            end
        end
    catch
        % Fall through to interpolation
    end

    % Fallback: interpolate stored weights
    eigOrig = F.axis.eigenvalues(:);
    for j = 1:J
        weightsDense(:,j) = interp1(eigOrig, F.weights(:,j), ...
            lambdaDense, 'pchip', 0);
    end
end


function labels = buildLabels(F, J, userLabels)
%BUILDLABELS  Generate legend labels for each filter
    if userLabels(1) ~= ""
        labels = userLabels;
        if numel(labels) < J
            for j = numel(labels)+1:J
                labels(j) = sprintf("Filter %d", j);
            end
        end
        return;
    end

    labels = strings(1, J);
    if isfield(F, 'params') && numel(F.params) == J
        % Get the swept parameter name (first field that varies)
        fnames = fieldnames(F.params);
        if numel(fnames) == 1
            pname = fnames{1};
            for j = 1:J
                val = F.params(j).(pname);
                labels(j) = sprintf("%s = %g", pname, val);
            end
        else
            % Multiple params — show all
            for j = 1:J
                parts = strings(1, numel(fnames));
                for f = 1:numel(fnames)
                    parts(f) = sprintf("%s=%g", fnames{f}, F.params(j).(fnames{f}));
                end
                labels(j) = join(parts, ", ");
            end
        end
    else
        for j = 1:J
            labels(j) = sprintf("Filter %d", j);
        end
    end
end


function addWavelengthAxis(ax, scale)
%ADDWAVELENGTHAXIS  Add a secondary top axis showing spatial wavelength
%
%   Wavelength ℓ = 2π / sqrt(λ)  (flat-domain approximation)
%   scale converts vertex units to mm (e.g., 1e3 for meters→mm)

    axPos = ax.Position;

    % Create a co-located axes on top
    ax2 = axes('Position', axPos, ...
        'XAxisLocation', 'top', ...
        'YAxisLocation', 'right', ...
        'Color', 'none', ...
        'YTick', [], ...
        'Box', 'off');

    % Get eigenvalue limits from primary axes
    xlims = ax.XLim;

    % Map eigenvalue limits to wavelength (inverted: large λ → small wavelength)
    wlMax = 2*pi / sqrt(max(xlims(1), eps)) * scale;
    wlMin = 2*pi / sqrt(xlims(2)) * scale;

    % Choose nice tick values in mm
    candidateTicks = [1 2 5 10 20 50 100 200 500];
    candidateTicks = candidateTicks(candidateTicks >= wlMin & candidateTicks <= wlMax);
    if isempty(candidateTicks)
        candidateTicks = linspace(wlMin, wlMax, 5);
    end

    % Convert wavelength ticks back to eigenvalue positions
    eigTicks = (2*pi ./ (candidateTicks / scale)).^2;

    % Set up secondary axis
    ax2.XLim = xlims;
    ax2.XTick = eigTicks;
    ax2.XTickLabel = arrayfun(@(w) sprintf('%.0f', w), candidateTicks, ...
        'UniformOutput', false);

    if ax.XScale == "log"
        ax2.XScale = 'log';
    end

    xlabel(ax2, 'Effective wavelength (mm)');
    set(ax2, 'FontSize', 14, 'TickDir', 'out');

    % Link x-axes so they zoom together
    linkaxes([ax, ax2], 'x');
end
