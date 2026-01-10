classdef Fplot < matlab.ui.componentcontainer.ComponentContainer
%BCT.UI.COMPONENT.FPLOT  High-performance 1D function plot view (sampling-based)
%
% Purpose
%   A lightweight rendering primitive for plotting y = f(x) with fast updates.
%   Intended as the reusable plotting "View" used by higher-level inspectors
%   (e.g., KernelInspector) that manage kernel selection and parameter controls.
%
% Design
%   - Owns UIAxes and graphics handles (line + optional zero line)
%   - Accepts an X axis vector and a function handle
%   - Supports parameter binding via either:
%       (A) Function is already bound:     fn = @(x) ...
%       (B) Function takes params:         fn = @(x,p) ...
%     and the component provides Params and refresh() to re-render.
%   - Uses sampled evaluation and line YData updates (not MATLAB fplot object)
%     for performance and compatibility with discrete axes (lambda, frequency).
%
% Key properties for future KernelInspector integration
%   - XAxis, Params, Function
%   - ComplexMode: how to display complex-valued kernels (real/abs/phase)
%   - Normalize: normalize output for consistent display
%   - AutoYLim and YLim: control axes limits (important for interactive sliders)
%   - Status: optional message when evaluation fails
%
% Example
%   fp = bct.ui.component.Fplot(parentGrid);
%   fp.XAxis = linspace(-5,5,512);
%   fp.Function = @(x,p) exp(-(x-p.mu).^2/(2*p.sigma^2));
%   fp.Params = struct("mu",0,"sigma",1);
%   fp.refresh();
%
% Notes
%   - This component is purely a View. It does not know about kernel registries.
%   - Call refresh() after changing Params if you use fn(x,p).
%
% See also: matlab.ui.componentcontainer.ComponentContainer

    %% ----------------------------
    % Public API
    %% ----------------------------
    properties
        % XAxis - Sampling support for plot evaluation
        % Default: linspace(-5,5,512)
        XAxis (1,:) double = linspace(-5,5,512);

        % Function - Function handle used to evaluate y.
        % Allowed signatures:
        %   y = fn(x)         OR
        %   y = fn(x, params) OR
        %   y = fn(x, params, comp)  (rare; for advanced use)
        %
        % The component detects which signature is supported.
        Function (1,1) function_handle = @(x) zeros(size(x));

        % Params - Parameter struct passed to Function if supported.
        Params (1,1) struct = struct();

        % Title / labels
        TitleText (1,1) string = "Function";
        XLabelText (1,1) string = "x";
        YLabelText (1,1) string = "f(x)";

        % ComplexMode - Display rule for complex-valued y
        %   "real"  : plot real(y)
        %   "imag"  : plot imag(y)
        %   "abs"   : plot abs(y)
        %   "phase" : plot angle(y)
        ComplexMode (1,1) string {mustBeMember(ComplexMode, ["real","imag","abs","phase"])} = "real";

        % Normalize - Optional normalization of y for display
        %   "none"     : no normalization
        %   "maxabs"   : y = y / max(abs(y))
        %   "l2"       : y = y / norm(y)
        Normalize (1,1) string {mustBeMember(Normalize, ["none","maxabs","l2"])} = "none";

        % AutoYLim - If true, updates YLim automatically after render.
        % If false, uses YLimValue.
        AutoYLim (1,1) logical = true;

        % YLimValue - Manual Y limits when AutoYLim is false
        YLimValue (1,2) double = [-1 1];

        % ShowZeroLine - Draw horizontal y=0 reference line
        ShowZeroLine (1,1) logical = true;

        % Enabled - Master enable flag (useful for inspectors disabling updates)
        Enabled (1,1) logical = true;

        % ErrorPolicy - what to do if evaluation fails
        %   "message" : set StatusText and do not throw
        %   "error"   : rethrow error
        ErrorPolicy (1,1) string {mustBeMember(ErrorPolicy, ["message","error"])} = "message";
    end

    properties (SetAccess = private)
        % LastY - last evaluated (post-processed) y values
        LastY (1,:) double = double.empty(1,0);

        % StatusText - last status / error message
        StatusText (1,1) string = "";
    end

    %% ----------------------------
    % UI internals
    %% ----------------------------
    properties (Access = private, Transient, NonCopyable)
        GridLayout  matlab.ui.container.GridLayout
        UIAxes      matlab.ui.control.UIAxes
        Line        matlab.graphics.chart.primitive.Line
        ZeroLine    matlab.graphics.primitive.ConstantLine
    end

    properties (Access = private)
        IsReady (1,1) logical = false
        NeedsRender (1,1) logical = true
    end

    %% ----------------------------
    % ComponentContainer overrides
    %% ----------------------------
    methods (Access = protected)

        function setup(comp)
            % Basic geometry (caller layout typically overrides)
            comp.Position = [1 1 380 260];

            comp.GridLayout = uigridlayout(comp);
            comp.GridLayout.RowHeight = {'1x'};
            comp.GridLayout.ColumnWidth = {'1x'};
            comp.GridLayout.Padding = [6 6 6 6];

            comp.UIAxes = uiaxes(comp.GridLayout);
            comp.UIAxes.Layout.Row = 1;
            comp.UIAxes.Layout.Column = 1;

            % Minimal axes policy for a plotting primitive
            grid(comp.UIAxes, 'on');
            box(comp.UIAxes, 'on');

            title(comp.UIAxes, comp.TitleText);
            xlabel(comp.UIAxes, comp.XLabelText);
            ylabel(comp.UIAxes, comp.YLabelText);

            % Create line once and update YData for performance
            comp.Line = plot(comp.UIAxes, comp.XAxis, zeros(size(comp.XAxis)));
            comp.Line.PickableParts = "none"; % view only; tool layers can be added later

            if comp.ShowZeroLine
                comp.ZeroLine = yline(comp.UIAxes, 0, '-');
                comp.ZeroLine.PickableParts = "none";
            end

            comp.IsReady = true;
            comp.NeedsRender = true;

            % Initial render
            comp.refresh();
        end

        function update(comp)
            % Called when any public property changes
            if ~comp.IsReady
                return;
            end

            % Update axes labels/titles
            title(comp.UIAxes, comp.TitleText);
            xlabel(comp.UIAxes, comp.XLabelText);
            ylabel(comp.UIAxes, comp.YLabelText);

            % Zero line toggling
            comp.updateZeroLine();

            % Manual y-lims if requested
            if ~comp.AutoYLim
                comp.UIAxes.YLim = comp.YLimValue;
            end

            % Render if required
            if comp.NeedsRender
                comp.refresh();
            end
        end
    end

    %% ----------------------------
    % Public methods
    %% ----------------------------
    methods
        function refresh(comp)
            %REFRESH Evaluate Function on XAxis and update plot
            if ~comp.IsReady || ~comp.Enabled
                return;
            end

            x = comp.XAxis;

            try
                y = comp.evaluateFunction(x);
                y = comp.postprocessY(y);

                comp.LastY = y;
                comp.StatusText = "";

                % Ensure line exists (safety)
                if isempty(comp.Line) || ~isvalid(comp.Line)
                    comp.Line = plot(comp.UIAxes, x, y);
                    comp.Line.PickableParts = "none";
                else
                    comp.Line.XData = x;
                    comp.Line.YData = y;
                end

                % XLim follows axis support
                comp.UIAxes.XLim = [min(x) max(x)];

                if comp.AutoYLim
                    comp.applyAutoYLim(y);
                end

            catch ME
                comp.LastY = double.empty(1,0);

                switch comp.ErrorPolicy
                    case "message"
                        comp.StatusText = string(ME.message);
                        % Render a safe fallback line
                        if ~isempty(comp.Line) && isvalid(comp.Line)
                            comp.Line.XData = x;
                            comp.Line.YData = zeros(size(x));
                        end
                    case "error"
                        rethrow(ME);
                end
            end

            comp.NeedsRender = false;
        end

        function setAxis(comp, x)
            %SETAXIS Set XAxis and mark for render
            arguments
                comp
                x (1,:) double
            end
            comp.XAxis = x;
            comp.NeedsRender = true;
            comp.refresh();
        end

        function setFunction(comp, fn)
            %SETFUNCTION Set Function and mark for render
            arguments
                comp
                fn (1,1) function_handle
            end
            comp.Function = fn;
            comp.NeedsRender = true;
            comp.refresh();
        end

        function setParams(comp, p)
            %SETPARAMS Set Params struct and mark for render
            arguments
                comp
                p (1,1) struct
            end
            comp.Params = p;
            comp.NeedsRender = true;
            comp.refresh();
        end

        function ax = axesHandle(comp)
            %AXESHANDLE Return the UIAxes handle (useful for inspectors)
            ax = comp.UIAxes;
        end
    end

    %% ----------------------------
    % Internal helpers
    %% ----------------------------
    methods (Access = private)

        function y = evaluateFunction(comp, x)
            %EVALUATEFUNCTION Call Function using best-effort signature matching

            fn = comp.Function;

            % Try fn(x) first
            try
                y = fn(x);
                return;
            catch
                % continue
            end

            % Try fn(x, params)
            try
                y = fn(x, comp.Params);
                return;
            catch
                % continue
            end

            % Try fn(x, params, comp) (advanced)
            y = fn(x, comp.Params, comp);
        end

        function y = postprocessY(comp, y)
            %POSTPROCESSY Apply complex handling + normalization + ensure real double vector

            % Ensure vector shape matches x
            y = y(:).'; % force row

            % Complex handling
            switch comp.ComplexMode
                case "real"
                    y = real(y);
                case "imag"
                    y = imag(y);
                case "abs"
                    y = abs(y);
                case "phase"
                    y = angle(y);
            end

            % Convert to double
            y = double(y);

            % Replace non-finite with 0 to keep graphics stable
            y(~isfinite(y)) = 0;

            % Normalize if requested
            switch comp.Normalize
                case "none"
                    % no-op
                case "maxabs"
                    m = max(abs(y));
                    if m > 0
                        y = y ./ m;
                    end
                case "l2"
                    n = norm(y);
                    if n > 0
                        y = y ./ n;
                    end
            end
        end

        function applyAutoYLim(comp, y)
            %APPLYAUTOYLIM Robust y-lim policy for interactive updates
            if isempty(y)
                return;
            end

            ymin = min(y);
            ymax = max(y);

            if ymin == ymax
                % Flat line: pad around it
                pad = 1;
                comp.UIAxes.YLim = [ymin - pad, ymax + pad];
                return;
            end

            % Add small padding
            pad = 0.05 * (ymax - ymin);
            comp.UIAxes.YLim = [ymin - pad, ymax + pad];
        end

        function updateZeroLine(comp)
            if comp.ShowZeroLine
                if isempty(comp.ZeroLine) || ~isvalid(comp.ZeroLine)
                    comp.ZeroLine = yline(comp.UIAxes, 0, '-');
                    comp.ZeroLine.PickableParts = "none";
                end
            else
                if ~isempty(comp.ZeroLine) && isvalid(comp.ZeroLine)
                    delete(comp.ZeroLine);
                end
                comp.ZeroLine = matlab.graphics.primitive.ConstantLine.empty;
            end
        end
    end
end
