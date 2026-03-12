classdef SourceExplorer < handle
    %SOURCEEXPLORER Interactive sensor + source timecourse explorer.
    %
    %   Combines a sensor-space heatmap, a source-space heatmap, and a
    %   bct.ui.manifold.Viewer in one figure. Click on either heatmap to
    %   move the time cursor — the 3D cortical surface updates in sync.
    %
    %   The TimePoint property is observable: attach listeners to react
    %   to cursor changes from external code.
    %
    %   Usage:
    %       %% Build your data
    %       outPath = "Z:\...\sub-0004";
    %       meta = load(fullfile(outPath,"provenance.mat")).provenance;
    %       K = load(fullfile(outPath,"ImagingKernel.mat")).K;
    %       fs5root = "C:\...\fsaverage5\surf";
    %
    %       [destL,~] = mne_read_surface(fullfile(fs5root,'lh.sphere.reg'));
    %       [destR,~] = mne_read_surface(fullfile(fs5root,'rh.sphere.reg'));
    %       [W, pInfo] = buildProjectionMatrix(meta, destL, destR);
    %       WK = W * K;
    %       nDestL = pInfo.nDestL;
    %
    %       [alphaCWT,chans,~] = readCWTBand(fullfile(outPath,"cwt"),"alpha");
    %       [verts,faces] = mne_read_surface(fullfile(fs5root,'lh.pial'));
    %       Mleft = bct.Manifold(verts, faces);
    %
    %       %% Window
    %       sfreq = meta.sfreq;
    %       t1 = 10; t2 = 14;
    %       iWin = round(t1*sfreq)+1 : round(t2*sfreq)+1;
    %       tWin = (iWin-1)/sfreq;
    %       sensorWin = alphaCWT(:, iWin);
    %       sourceWin = WK * sensorWin;
    %       sourceLeftWin = sourceWin(1:nDestL, :);
    %
    %       %% Launch explorer
    %       ex = SourceExplorer(Mleft, sourceLeftWin, tWin, ...
    %           SensorData=sensorWin, ...
    %           ChannelNames=chans, ...
    %           Title="Alpha source explorer");
    %
    %       %% Read current time
    %       ex.TimePoint    % returns current time in seconds
    %
    %       %% Listen for changes
    %       addlistener(ex, 'TimePoint', 'PostSet', @(~,~) disp(ex.TimePoint));
    %
    %   See also: bct.ui.manifold.Viewer, plotSourceTimecourse,
    %             plotSensorTimecourse, buildProjectionMatrix

    properties (SetObservable)
        TimePoint (1,1) double = 0   % Current time in seconds (observable)
    end

    properties (SetAccess = private)
        Figure                       % uifigure handle
        Viewer                       % bct.ui.manifold.Viewer
        SourceAxes                   % axes for source heatmap
        SensorAxes                   % axes for sensor heatmap (may be empty)
        TimeVector (1,:) double      % full time vector in seconds
        SourceData (:,:) double      % [nVertices x nSamples]
        SensorData (:,:) double      % [nChannels x nSamples] (may be empty)
        Sfreq (1,1) double = 600     % sampling frequency
    end

    properties (Access = private)
        SourceCursor                 % xline handle
        SourceLabel                  % text handle
        SensorCursor                 % xline handle
        SensorLabel                  % text handle
        Manifold                     % bct.Manifold for the viewer
        InitialTimePoint (1,1) double = NaN
        InitTimer                    % timer for deferred viewer init
    end

    methods
        function obj = SourceExplorer(M, sourceData, tVec, opts)
            %SOURCEEXPLORER Construct the explorer.

            arguments
                M              (1,1) bct.Manifold
                sourceData     (:,:) double
                tVec           (1,:) double
                opts.SensorData    (:,:) double  = []
                opts.ChannelNames               = []
                opts.TimePoint  (1,1) double    = NaN
                opts.Title      (1,1) string    = "Source Explorer"
                opts.CLim       (1,:) double    = []
                opts.SensorCLim (1,:) double    = []
                opts.MaxVertices (1,1) double   = 500
                opts.Position   (1,:) double    = []
            end

            obj.Manifold   = M;
            obj.SourceData = sourceData;
            obj.TimeVector = tVec(:)';
            obj.Sfreq      = round(1 / median(diff(tVec)));

            tMin = tVec(1);
            tMax = tVec(end);

            hasSensor = ~isempty(opts.SensorData);
            if hasSensor
                obj.SensorData = opts.SensorData;
            end

            % ---- Figure ----
            if isempty(opts.Position)
                if hasSensor
                    figPos = [50 50 1400 800];
                else
                    figPos = [50 50 1200 700];
                end
            else
                figPos = opts.Position;
            end

            obj.Figure = uifigure('Name', opts.Title, 'Position', figPos);

            % ---- Main grid layout ----
            if hasSensor
                grid = uigridlayout(obj.Figure, [2 2]);
                grid.RowHeight   = {'1x', '1x'};
            else
                grid = uigridlayout(obj.Figure, [1 2]);
                grid.RowHeight   = {'1x'};
            end
            grid.ColumnWidth  = {'1x', '1x'};
            grid.Padding      = [5 5 5 5];
            grid.RowSpacing   = 5;
            grid.ColumnSpacing = 5;

            % ================================================================
            %  SENSOR HEATMAP (top-left)
            % ================================================================
            if hasSensor
                sensorPanel = uipanel(grid, 'Title', 'Sensor Data', ...
                    'FontSize', 11, 'FontWeight', 'bold');
                sensorPanel.Layout.Row = 1;
                sensorPanel.Layout.Column = 1;

                % Inner grid so axes fills panel
                sGrid = uigridlayout(sensorPanel, [1 1]);
                sGrid.Padding = [2 2 2 2];
                obj.SensorAxes = uiaxes(sGrid);
                obj.SensorAxes.Layout.Row = 1;
                obj.SensorAxes.Layout.Column = 1;

                [nChan, ~] = size(opts.SensorData);

                if isempty(opts.ChannelNames)
                    chanLabels = string(1:nChan);
                else
                    chanLabels = string(opts.ChannelNames(:));
                end

                if isempty(opts.SensorCLim)
                    cMaxS = prctile(abs(opts.SensorData(:)), 99);
                    if cMaxS == 0, cMaxS = 1; end
                    sensorCLim = [-cMaxS cMaxS];
                else
                    sensorCLim = opts.SensorCLim;
                end

                imagesc(obj.SensorAxes, tVec, 1:nChan, opts.SensorData, sensorCLim);
                axis(obj.SensorAxes, 'xy');
                obj.SensorAxes.XLim = [tMin tMax];
                obj.SensorAxes.YLim = [0.5 nChan + 0.5];
                xlabel(obj.SensorAxes, 'Time (s)');
                ylabel(obj.SensorAxes, 'Channel');
                colormap(obj.SensorAxes, obj.divergingColormap());

                if nChan <= 30
                    obj.SensorAxes.YTick = 1:nChan;
                    obj.SensorAxes.YTickLabel = chanLabels;
                else
                    nTicks = min(15, nChan);
                    tickIdx = round(linspace(1, nChan, nTicks));
                    obj.SensorAxes.YTick = tickIdx;
                    obj.SensorAxes.YTickLabel = chanLabels(tickIdx);
                    obj.SensorAxes.FontSize = 7;
                end

                hold(obj.SensorAxes, 'on');
                obj.SensorCursor = xline(obj.SensorAxes, tMin, 'r-', 'LineWidth', 2);
                obj.SensorLabel = text(obj.SensorAxes, tMin, nChan + 1, '', ...
                    'Color', 'r', 'FontSize', 9, 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'bottom', 'Clipping', 'off');
                hold(obj.SensorAxes, 'off');

                obj.installClickCallbacks(obj.SensorAxes);
            end

            % ================================================================
            %  SOURCE HEATMAP (bottom-left, or left if no sensor)
            % ================================================================
            if hasSensor
                srcRow = 2;
            else
                srcRow = 1;
            end

            sourcePanel = uipanel(grid, 'Title', 'Source Data', ...
                'FontSize', 11, 'FontWeight', 'bold');
            sourcePanel.Layout.Row = srcRow;
            sourcePanel.Layout.Column = 1;

            % Inner grid so axes fills panel
            srcGrid = uigridlayout(sourcePanel, [1 1]);
            srcGrid.Padding = [2 2 2 2];
            obj.SourceAxes = uiaxes(srcGrid);
            obj.SourceAxes.Layout.Row = 1;
            obj.SourceAxes.Layout.Column = 1;

            [nVert, ~] = size(sourceData);
            if nVert > opts.MaxVertices
                step = ceil(nVert / opts.MaxVertices);
                dispSource = sourceData(1:step:end, :);
            else
                dispSource = sourceData;
            end
            nDispVert = size(dispSource, 1);

            if isempty(opts.CLim)
                cMaxV = prctile(abs(dispSource(:)), 99);
                if cMaxV == 0, cMaxV = 1; end
                srcCLim = [-cMaxV cMaxV];
            else
                srcCLim = opts.CLim;
            end

            imagesc(obj.SourceAxes, tVec, 1:nDispVert, dispSource, srcCLim);
            axis(obj.SourceAxes, 'xy');
            obj.SourceAxes.XLim = [tMin tMax];
            obj.SourceAxes.YLim = [0.5 nDispVert + 0.5];
            xlabel(obj.SourceAxes, 'Time (s)');
            ylabel(obj.SourceAxes, 'Vertex');
            colormap(obj.SourceAxes, obj.divergingColormap());

            hold(obj.SourceAxes, 'on');
            obj.SourceCursor = xline(obj.SourceAxes, tMin, 'r-', 'LineWidth', 2);
            obj.SourceLabel = text(obj.SourceAxes, tMin, nDispVert + 1, '', ...
                'Color', 'r', 'FontSize', 9, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', 'Clipping', 'off');
            hold(obj.SourceAxes, 'off');

            obj.installClickCallbacks(obj.SourceAxes);

            % ================================================================
            %  3D VIEWER (right column, spanning all rows)
            % ================================================================
            viewerPanel = uipanel(grid, 'Title', '3D Surface', ...
                'FontSize', 11, 'FontWeight', 'bold');
            if hasSensor
                viewerPanel.Layout.Row = [1 2];
            else
                viewerPanel.Layout.Row = 1;
            end
            viewerPanel.Layout.Column = 2;

            viewerGrid = uigridlayout(viewerPanel, [1 1]);
            viewerGrid.Padding = 0;
            obj.Viewer = bct.ui.manifold.Viewer(viewerGrid);
            obj.Viewer.Layout.Row = 1;
            obj.Viewer.Layout.Column = 1;

            % ---- Determine initial time point ----
            if isnan(opts.TimePoint)
                obj.InitialTimePoint = tVec(1);
            else
                obj.InitialTimePoint = opts.TimePoint;
            end

            % ---- Defer mesh + scalar to let HTML/JS load ----
            drawnow;
            obj.InitTimer = timer( ...
                'StartDelay', 2.0, ...
                'TimerFcn', @(~,~) obj.deferredInit(), ...
                'ExecutionMode', 'singleShot', ...
                'Tag', 'SourceExplorerInit');
            start(obj.InitTimer);
        end

        function setTime(obj, tSec)
            %SETTIME Move cursor to a specific time and update viewer.
            %   obj.setTime(12.5)

            [~, idx] = min(abs(obj.TimeVector - tSec));
            tSnapped = obj.TimeVector(idx);

            % Source cursor
            obj.SourceCursor.Value = tSnapped;
            obj.SourceLabel.String = sprintf('t = %.3f s', tSnapped);
            obj.SourceLabel.Position(1) = tSnapped;

            % Sensor cursor
            if ~isempty(obj.SensorCursor)
                obj.SensorCursor.Value = tSnapped;
                obj.SensorLabel.String = sprintf('t = %.3f s', tSnapped);
                obj.SensorLabel.Position(1) = tSnapped;
            end

            % 3D viewer
            obj.Viewer.setScalar(obj.SourceData(:, idx));

            % Observable property
            obj.TimePoint = tSnapped;
        end

        function idx = timeToIndex(obj, tSec)
            %TIMETOINDEX Convert seconds to sample index.
            [~, idx] = min(abs(obj.TimeVector - tSec));
        end

        function tSec = indexToTime(obj, idx)
            %INDEXTOTIME Convert sample index to seconds.
            tSec = obj.TimeVector(idx);
        end

        function delete(obj)
            %DELETE Clean up timer on destruction.
            if ~isempty(obj.InitTimer)
                try
                    stop(obj.InitTimer);
                    delete(obj.InitTimer);
                catch
                end
            end
        end

        function deferredInit(obj)
            %DEFERREDINIT Send mesh and initial data after JS has loaded.
            try
                if isvalid(obj.Figure)
                    obj.Viewer.setMesh(obj.Manifold);
                    drawnow;
                    pause(0.5);
                    obj.setTime(obj.InitialTimePoint);
                end
            catch ME
                warning('SourceExplorer:DeferredInitFailed', ...
                    'Deferred init error: %s', ME.message);
            end
            % Clean up timer
            try
                if ~isempty(obj.InitTimer) && isvalid(obj.InitTimer)
                    stop(obj.InitTimer);
                    delete(obj.InitTimer);
                    obj.InitTimer = [];
                end
            catch
            end
        end

        function installClickCallbacks(obj, ax)
            %INSTALLCLICKCALLBACKS Set up click-to-seek on axes and children.
            ax.ButtonDownFcn = @(src,~) obj.onAxesClickPos(src);
            ch = ax.Children;
            for ci = 1:numel(ch)
                if isprop(ch(ci), 'ButtonDownFcn') && ...
                   ~isa(ch(ci), 'matlab.graphics.chart.decoration.ConstantLine')
                    ch(ci).HitTest = 'on';
                    ch(ci).ButtonDownFcn = @(~,~) obj.onAxesClickPos(ax);
                end
            end
        end

        function onAxesClickPos(obj, ax)
            %ONAXESCLICKPOS Handle click using axes CurrentPoint.
            cp = ax.CurrentPoint;
            tClicked = cp(1,1);
            tRange = obj.TimeVector([1 end]);
            if tClicked >= tRange(1) && tClicked <= tRange(2)
                obj.setTime(tClicked);
            end
        end
    end

    methods (Static, Access = private)
        function cmap = divergingColormap()
            n = 256;
            r = [linspace(0.2, 1, n/2), ones(1, n/2)];
            g = [linspace(0.2, 1, n/2), linspace(1, 0.2, n/2)];
            b = [ones(1, n/2), linspace(1, 0.2, n/2)];
            cmap = [r' g' b'];
        end
    end
end
