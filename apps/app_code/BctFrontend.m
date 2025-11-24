classdef BctFilterDesigner < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        GridLayout              matlab.ui.container.GridLayout
        LeftPanel               matlab.ui.container.Panel
        TextArea                matlab.ui.control.TextArea
        ResolutionLabel         matlab.ui.control.Label
        kmodesEditField         matlab.ui.control.NumericEditField
        kmodesEditFieldLabel    matlab.ui.control.Label
        FourierButton           matlab.ui.control.Button
        SpectralLabel           matlab.ui.control.Label
        LoadButton              matlab.ui.control.Button
        ScanButton              matlab.ui.control.Button
        Tree                    matlab.ui.container.Tree
        DataNode                matlab.ui.container.TreeNode
        Node2                   matlab.ui.container.TreeNode
        Node3                   matlab.ui.container.TreeNode
        Node4                   matlab.ui.container.TreeNode
        CenterPanel             matlab.ui.container.Panel
        TabGroup                matlab.ui.container.TabGroup
        JointTab                matlab.ui.container.Tab
        FilterDesignPanel       matlab.ui.container.Panel
        BandwidthSliderLabel    matlab.ui.control.Label
        BandwidthSlider         matlab.ui.control.Slider
        FrequencySliderLabel    matlab.ui.control.Label
        FrequencySlider         matlab.ui.control.Slider
        kbandwidthSliderLabel   matlab.ui.control.Label
        kbandwidthSlider        matlab.ui.control.Slider
        WavenumberSliderLabel   matlab.ui.control.Label
        WavenumberSlider        matlab.ui.control.Slider
        SynthesizeButton        matlab.ui.control.Button
        KernelDropDown          matlab.ui.control.DropDown
        KernelDropDownLabel     matlab.ui.control.Label
        UIAxesKernel            matlab.ui.control.UIAxes
        UIAxesResponse          matlab.ui.control.UIAxes
        SpatialTab              matlab.ui.container.Tab
        SigmaEditField          matlab.ui.control.NumericEditField
        SigmaEditFieldLabel     matlab.ui.control.Label
        Centerk0EditField       matlab.ui.control.NumericEditField
        Centerk0EditFieldLabel  matlab.ui.control.Label
        SpatialparametersLabel  matlab.ui.control.Label
        ShowlambdaButton        matlab.ui.control.Button
        UIAxes                  matlab.ui.control.UIAxes
        MeshPanel               matlab.ui.container.Panel
        Panel_2                 matlab.ui.container.Panel
        GridLayout3             matlab.ui.container.GridLayout
        PlayButton              matlab.ui.control.Button
        BackButton              matlab.ui.control.Button
        SignalPanel             matlab.ui.container.Panel
        ShowMeshButton          matlab.ui.control.Button
        vDeltaEditField         matlab.ui.control.NumericEditField
        vDeltaEditFieldLabel    matlab.ui.control.Label
        SignalDropDown          matlab.ui.control.DropDown
        SignalDropDownLabel     matlab.ui.control.Label
        ViewerPanel             matlab.ui.container.Panel
        GridLayout2             matlab.ui.container.GridLayout
    end

    % Properties that correspond to apps with auto-reflow
    properties (Access = private)
        onePanelWidth = 576;
        twoPanelWidth = 768;
    end

    
    properties (Access = public)
        BCTObjects struct
        CurrentBCT bct.bct% Description
        FilterDesigner
        CurrentFilter
        KronDelta                   % bct.Signal - Kronecker delta on Manifold_Time
        IRSignal                    % bct.Signal - Impulse response after filtering
        CurrentTimePoint
    end

   

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
                        % Startup sequence: scan workspace and load default BCT
            
            % Scan workspace for existing BCT objects
            BctBackend.scanWorkspace(app);
            
            % Load default BCT object if no objects found in workspace
            if isempty(fieldnames(app.BCTObjects))
                BctBackend.loadDefaultBCT(app);
            end
        end

        % Button pushed function: LoadButton
        function LoadButtonPushed(app, event)

            node = app.Tree.SelectedNodes;

            if isempty(node)
                uialert(app.UIFigure, 'Please select a BCT object.', 'No Selection');
                return;
            end

            varName = node.NodeData;

            if isempty(varName) || ~isfield(app.BCTObjects, varName)
                uialert(app.UIFigure, 'Selected node is invalid.', 'Invalid Selection');
                return;
            end

            % Load object
            app.CurrentBCT = app.BCTObjects.(varName);

            % Initialize FilterDesigner for this BCT object
            app.FilterDesigner = bct.filters.FilterDesigner(app.CurrentBCT);

            % Create default Joint filter (Lambda × Omega) - delegated to backend
            BctBackend.createDefaultFilter(app);

            % Single high-level update - delegated to backend
            BctBackend.updateUIAfterLoad(app);

        end

        % Button pushed function: ScanButton
        function ScanButtonPushed(app, event)
             BctBackend.scanWorkspace(app);
        end

        % Button pushed function: ShowMeshButton
        function ShowMeshButtonPushed(app, event)
            BctBackend.attachViewer(app, app.CurrentBCT);
        end

        % Button pushed function: FourierButton
        function FourierButtonPushed(app, event)

            % Ensure a BCT object is loaded
            if isempty(app.CurrentBCT)
                uialert(app.UIFigure, 'Please load a BCT object first.', 'No BCT object');
                return;
            end

            B = app.CurrentBCT;

            % Read k from UI
            k = app.kmodesEditField.Value;

            % Validate k
            if ~isscalar(k) || k <= 0 || k > B.Manifold.N
                uialert(app.UIFigure, ...
                    sprintf('k must be between 1 and %d.', B.Manifold.N), ...
                    'Invalid eigenmode count');
                return;
            end

            % Progress dialog
            msg = sprintf('Computing %d Laplace-Beltrami modes... Please wait.', k);
            d = uiprogressdlg(app.UIFigure, 'Message', msg, ...
                'Title', 'Computing Fourier Modes', 'Indeterminate', 'on');

            % Compute eigenbasis using Bct orchestration
            try
                B = B.computeEigenbasis(k);
                app.CurrentBCT = B;  % Update reference
            catch ME
                close(d);
                uialert(app.UIFigure, ME.message, 'Eigenbasis Error');
                return;
            end

            close(d);

            % Update UI (text area, axes, etc.)
            BctBackend.updateUIAfterLoad(app);

            % Now that eigenvalues exist → update slider ranges
            BctBackend.updateKernelSliders(app, B);

            uialert(app.UIFigure, ...
                sprintf('Successfully computed %d eigenmodes.', k), ...
                'Done');

        end

        % Button pushed function: SynthesizeButton
        function SynthesizeButtonPushed(app, event)
         
            % Compute impulse response by filtering KronDelta signal
            % Transforms delta from Manifold_Time → Lambda_Omega → apply filter → Manifold_Time
            
            B = app.CurrentBCT;
            
            % Verify Joint domain exists
            if isempty(B.Joint)
                uialert(app.UIFigure, ...
                    'Joint domain not available. Assign Time domain to BCT first.', ...
                    'No Joint Domain');
                return;
            end
            
            % Verify filter exists
            if isempty(app.CurrentFilter)
                uialert(app.UIFigure, ...
                    'No filter available. Filter should be created on app load.', ...
                    'No Filter');
                return;
            end
            
            % Progress dialog
            d = uiprogressdlg(app.UIFigure, 'Message', 'Creating impulse signal...', ...
                'Title', 'Computing Impulse Response', 'Indeterminate', 'on');
            
            try
                % Create KronDelta signal if it doesn't exist
                if isempty(app.KronDelta)
                    app.KronDelta = BctBackend.createKronDelta(app, B);
                end
                
                % Update progress
                d.Message = 'Applying filter to delta signal...';
                
                % Compute impulse response through filter
                app.IRSignal = BctBackend.impulseResponse(app, B);
                
                % Update progress
                d.Message = 'Updating UI...';
                
                % Update signal dropdown with new signals
         %       BctBackend.updateSignalDropDown(app);
                
                % Visualize filter kernel on actual Lambda-Omega eigenmode grid
                BctBackend.visualizeFilterOnLambdaOmega(app, B, app.UIAxesResponse);
                
                % Update progress
                d.Message = 'Rendering on mesh...';
                
                % Show IRSignal on the mesh viewer (time point 1)
                % Use existing viewer or create if it doesn't exist
                if isempty(B.Viewer) || ~isvalid(B.Viewer)
                    BctBackend.attachViewer(app, B);
                end
                
                % Update the existing viewer with the signal (don't create new one)
                B.Viewer.Children.Color = bct.show.x2rgb(abs(app.IRSignal.Data(:, 1)), 'colormap', 'hot');  % Show first time point
                
                close(d);
                
            catch ME
                close(d);
                uialert(app.UIFigure, ME.message, 'Error Computing Impulse Response');
                rethrow(ME);
            end
            
            fprintf('[SynthesizeButton] Impulse response computed and visualized\n');
       

      

        end

        % Value changed function: FrequencySlider
        function FrequencySliderValueChanged(app, event)
             BctBackend.updateKernelPreview(app);
            
        end

        % Value changed function: BandwidthSlider
        function BandwidthSliderValueChanged(app, event)
             BctBackend.updateKernelPreview(app);
            
        end

        % Value changed function: WavenumberSlider
        function WavenumberSliderValueChanged(app, event)
             BctBackend.updateKernelPreview(app);
            
        end

        % Value changed function: kbandwidthSlider
        function kbandwidthSliderValueChanged(app, event)
             BctBackend.updateKernelPreview(app);
            
        end

        % Callback function: not associated with a component
        function PlayButtonPushed(app, event)
            if isempty(app.IRSignal)
                warning('BctBackend:NoIRSignal', 'No impulse response signal to step through.');
                return;
            end

            % Use CurrentBCT object and its viewer
            B = app.CurrentBCT;

            if isempty(B) || isempty(B.Viewer) || ~isvalid(B.Viewer)
                warning('BctBackend:NoViewer', 'Viewer not available. Create viewer first.');
                return;
            end

            % Get number of time points
            nTimePoints = size(app.IRSignal.Data, 2);

            % Initialize CurrentTimePoint if it doesn't exist
            if ~isprop(app, 'CurrentTimePoint') || isempty(app.CurrentTimePoint)
                app.CurrentTimePoint = 1;
            end

            % Advance to next time point (wrap around at end)
            app.CurrentTimePoint = app.CurrentTimePoint + 1;
            if app.CurrentTimePoint > nTimePoints
                app.CurrentTimePoint = 1;  % Loop back to start
            end
            dd=app.IRSignal.Data(:, app.CurrentTimePoint);
            % Update viewer with current time point
             app.CurrentBCT.Viewer.Children.Color = bct.show.x2rgb(abs(dd), 'colormap', 'hot');
            drawnow;

            fprintf('[stepSignal] Time point: %d / %d\n', app.CurrentTimePoint, nTimePoints);

        end

        % Changes arrangement of the app based on UIFigure width
        function updateAppLayout(app, event)
            currentFigureWidth = app.UIFigure.Position(3);
            if(currentFigureWidth <= app.onePanelWidth)
                % Change to a 3x1 grid
                app.GridLayout.RowHeight = {746, 746, 746};
                app.GridLayout.ColumnWidth = {'1x'};
                app.CenterPanel.Layout.Row = 1;
                app.CenterPanel.Layout.Column = 1;
                app.LeftPanel.Layout.Row = 2;
                app.LeftPanel.Layout.Column = 1;
                app.MeshPanel.Layout.Row = 3;
                app.MeshPanel.Layout.Column = 1;
            elseif (currentFigureWidth > app.onePanelWidth && currentFigureWidth <= app.twoPanelWidth)
                % Change to a 2x2 grid
                app.GridLayout.RowHeight = {746, 746};
                app.GridLayout.ColumnWidth = {'1x', '1x'};
                app.CenterPanel.Layout.Row = 1;
                app.CenterPanel.Layout.Column = [1,2];
                app.LeftPanel.Layout.Row = 2;
                app.LeftPanel.Layout.Column = 1;
                app.MeshPanel.Layout.Row = 2;
                app.MeshPanel.Layout.Column = 2;
            else
                % Change to a 1x3 grid
                app.GridLayout.RowHeight = {'1x'};
                app.GridLayout.ColumnWidth = {220, '1x', 592};
                app.LeftPanel.Layout.Row = 1;
                app.LeftPanel.Layout.Column = 1;
                app.CenterPanel.Layout.Row = 1;
                app.CenterPanel.Layout.Column = 2;
                app.MeshPanel.Layout.Row = 1;
                app.MeshPanel.Layout.Column = 3;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Position = [100 100 1340 746];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @updateAppLayout, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {220, '1x', 592};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Scrollable = 'on';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create Tree
            app.Tree = uitree(app.LeftPanel);
            app.Tree.Position = [19 535 186 174];

            % Create DataNode
            app.DataNode = uitreenode(app.Tree);
            app.DataNode.Text = 'Data';

            % Create Node2
            app.Node2 = uitreenode(app.DataNode);
            app.Node2.Text = 'Node2';

            % Create Node3
            app.Node3 = uitreenode(app.DataNode);
            app.Node3.Text = 'Node3';

            % Create Node4
            app.Node4 = uitreenode(app.DataNode);
            app.Node4.Text = 'Node4';

            % Create ScanButton
            app.ScanButton = uibutton(app.LeftPanel, 'push');
            app.ScanButton.ButtonPushedFcn = createCallbackFcn(app, @ScanButtonPushed, true);
            app.ScanButton.Position = [19 507 87 22];
            app.ScanButton.Text = 'Scan';

            % Create LoadButton
            app.LoadButton = uibutton(app.LeftPanel, 'push');
            app.LoadButton.ButtonPushedFcn = createCallbackFcn(app, @LoadButtonPushed, true);
            app.LoadButton.Position = [119 507 86 22];
            app.LoadButton.Text = 'Load';

            % Create SpectralLabel
            app.SpectralLabel = uilabel(app.LeftPanel);
            app.SpectralLabel.Position = [30 149 52 22];
            app.SpectralLabel.Text = 'Spectral ';

            % Create FourierButton
            app.FourierButton = uibutton(app.LeftPanel, 'push');
            app.FourierButton.ButtonPushedFcn = createCallbackFcn(app, @FourierButtonPushed, true);
            app.FourierButton.Position = [89 109 100 22];
            app.FourierButton.Text = 'Fourier';

            % Create kmodesEditFieldLabel
            app.kmodesEditFieldLabel = uilabel(app.LeftPanel);
            app.kmodesEditFieldLabel.HorizontalAlignment = 'right';
            app.kmodesEditFieldLabel.Position = [24 129 50 22];
            app.kmodesEditFieldLabel.Text = 'k modes';

            % Create kmodesEditField
            app.kmodesEditField = uieditfield(app.LeftPanel, 'numeric');
            app.kmodesEditField.Position = [89 129 100 22];
            app.kmodesEditField.Value = 300;

            % Create ResolutionLabel
            app.ResolutionLabel = uilabel(app.LeftPanel);
            app.ResolutionLabel.Position = [24 471 62 22];
            app.ResolutionLabel.Text = 'Resolution';

            % Create TextArea
            app.TextArea = uitextarea(app.LeftPanel);
            app.TextArea.Position = [24 219 181 244];

            % Create CenterPanel
            app.CenterPanel = uipanel(app.GridLayout);
            app.CenterPanel.Layout.Row = 1;
            app.CenterPanel.Layout.Column = 2;

            % Create TabGroup
            app.TabGroup = uitabgroup(app.CenterPanel);
            app.TabGroup.Position = [6 6 516 735];

            % Create JointTab
            app.JointTab = uitab(app.TabGroup);
            app.JointTab.Title = 'Joint';

            % Create UIAxesResponse
            app.UIAxesResponse = uiaxes(app.JointTab);
            title(app.UIAxesResponse, 'Title')
            xlabel(app.UIAxesResponse, 'Frequency (Hz)')
            ylabel(app.UIAxesResponse, 'Wavenumber (k)')
            zlabel(app.UIAxesResponse, 'Z')
            app.UIAxesResponse.Position = [15 5 484 386];

            % Create FilterDesignPanel
            app.FilterDesignPanel = uipanel(app.JointTab);
            app.FilterDesignPanel.Title = 'Filter Design';
            app.FilterDesignPanel.Position = [5 407 508 297];

            % Create UIAxesKernel
            app.UIAxesKernel = uiaxes(app.FilterDesignPanel);
            title(app.UIAxesKernel, 'Title')
            xlabel(app.UIAxesKernel, 'X')
            ylabel(app.UIAxesKernel, 'Y')
            zlabel(app.UIAxesKernel, 'Z')
            app.UIAxesKernel.Position = [216 56 272 210];

            % Create KernelDropDownLabel
            app.KernelDropDownLabel = uilabel(app.FilterDesignPanel);
            app.KernelDropDownLabel.HorizontalAlignment = 'right';
            app.KernelDropDownLabel.Position = [15 242 40 22];
            app.KernelDropDownLabel.Text = 'Kernel';

            % Create KernelDropDown
            app.KernelDropDown = uidropdown(app.FilterDesignPanel);
            app.KernelDropDown.Items = {'Gaussian', 'Heat', 'Mexican Hat', 'Gabor', 'Velocity Gabor'};
            app.KernelDropDown.Position = [70 242 100 22];
            app.KernelDropDown.Value = 'Gaussian';

            % Create SynthesizeButton
            app.SynthesizeButton = uibutton(app.FilterDesignPanel, 'push');
            app.SynthesizeButton.ButtonPushedFcn = createCallbackFcn(app, @SynthesizeButtonPushed, true);
            app.SynthesizeButton.Position = [388 18 100 22];
            app.SynthesizeButton.Text = 'Synthesize';

            % Create WavenumberSlider
            app.WavenumberSlider = uislider(app.FilterDesignPanel);
            app.WavenumberSlider.ValueChangedFcn = createCallbackFcn(app, @WavenumberSliderValueChanged, true);
            app.WavenumberSlider.Position = [108 199 70 3];

            % Create WavenumberSliderLabel
            app.WavenumberSliderLabel = uilabel(app.FilterDesignPanel);
            app.WavenumberSliderLabel.HorizontalAlignment = 'right';
            app.WavenumberSliderLabel.Position = [10 190 76 22];
            app.WavenumberSliderLabel.Text = 'Wavenumber';

            % Create kbandwidthSlider
            app.kbandwidthSlider = uislider(app.FilterDesignPanel);
            app.kbandwidthSlider.ValueChangedFcn = createCallbackFcn(app, @kbandwidthSliderValueChanged, true);
            app.kbandwidthSlider.Position = [101 152 74 3];

            % Create kbandwidthSliderLabel
            app.kbandwidthSliderLabel = uilabel(app.FilterDesignPanel);
            app.kbandwidthSliderLabel.HorizontalAlignment = 'right';
            app.kbandwidthSliderLabel.Position = [10 143 69 22];
            app.kbandwidthSliderLabel.Text = 'k bandwidth';

            % Create FrequencySlider
            app.FrequencySlider = uislider(app.FilterDesignPanel);
            app.FrequencySlider.ValueChangedFcn = createCallbackFcn(app, @FrequencySliderValueChanged, true);
            app.FrequencySlider.Position = [106 99 61 3];

            % Create FrequencySliderLabel
            app.FrequencySliderLabel = uilabel(app.FilterDesignPanel);
            app.FrequencySliderLabel.HorizontalAlignment = 'right';
            app.FrequencySliderLabel.Position = [22 90 62 22];
            app.FrequencySliderLabel.Text = 'Frequency';

            % Create BandwidthSlider
            app.BandwidthSlider = uislider(app.FilterDesignPanel);
            app.BandwidthSlider.ValueChangedFcn = createCallbackFcn(app, @BandwidthSliderValueChanged, true);
            app.BandwidthSlider.Position = [105 54 74 3];

            % Create BandwidthSliderLabel
            app.BandwidthSliderLabel = uilabel(app.FilterDesignPanel);
            app.BandwidthSliderLabel.HorizontalAlignment = 'right';
            app.BandwidthSliderLabel.Position = [22 45 61 22];
            app.BandwidthSliderLabel.Text = 'Bandwidth';

            % Create SpatialTab
            app.SpatialTab = uitab(app.TabGroup);
            app.SpatialTab.Title = 'Spatial ';

            % Create UIAxes
            app.UIAxes = uiaxes(app.SpatialTab);
            title(app.UIAxes, 'Title')
            xlabel(app.UIAxes, 'Frequency (Hz)')
            ylabel(app.UIAxes, 'Wavenumber (k)')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [15 245 484 435];

            % Create ShowlambdaButton
            app.ShowlambdaButton = uibutton(app.SpatialTab, 'push');
            app.ShowlambdaButton.Position = [145 103 100 22];
            app.ShowlambdaButton.Text = 'Show lambda';

            % Create SpatialparametersLabel
            app.SpatialparametersLabel = uilabel(app.SpatialTab);
            app.SpatialparametersLabel.Position = [67 192 106 22];
            app.SpatialparametersLabel.Text = 'Spatial parameters';

            % Create Centerk0EditFieldLabel
            app.Centerk0EditFieldLabel = uilabel(app.SpatialTab);
            app.Centerk0EditFieldLabel.HorizontalAlignment = 'right';
            app.Centerk0EditFieldLabel.Position = [73 139 57 22];
            app.Centerk0EditFieldLabel.Text = 'Center k0';

            % Create Centerk0EditField
            app.Centerk0EditField = uieditfield(app.SpatialTab, 'numeric');
            app.Centerk0EditField.Position = [145 139 100 22];

            % Create SigmaEditFieldLabel
            app.SigmaEditFieldLabel = uilabel(app.SpatialTab);
            app.SigmaEditFieldLabel.HorizontalAlignment = 'right';
            app.SigmaEditFieldLabel.Position = [91 159 39 22];
            app.SigmaEditFieldLabel.Text = 'Sigma';

            % Create SigmaEditField
            app.SigmaEditField = uieditfield(app.SpatialTab, 'numeric');
            app.SigmaEditField.Position = [145 159 100 22];

            % Create MeshPanel
            app.MeshPanel = uipanel(app.GridLayout);
            app.MeshPanel.Layout.Row = 1;
            app.MeshPanel.Layout.Column = 3;

            % Create ViewerPanel
            app.ViewerPanel = uipanel(app.MeshPanel);
            app.ViewerPanel.AutoResizeChildren = 'off';
            app.ViewerPanel.Title = 'Viewer';
            app.ViewerPanel.Position = [11 353 572 388];

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.ViewerPanel);
            app.GridLayout2.RowHeight = {'1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x'};

            % Create SignalPanel
            app.SignalPanel = uipanel(app.MeshPanel);
            app.SignalPanel.Title = 'Signal';
            app.SignalPanel.Position = [11 20 564 233];

            % Create SignalDropDownLabel
            app.SignalDropDownLabel = uilabel(app.SignalPanel);
            app.SignalDropDownLabel.HorizontalAlignment = 'right';
            app.SignalDropDownLabel.Position = [13 144 38 22];
            app.SignalDropDownLabel.Text = 'Signal';

            % Create SignalDropDown
            app.SignalDropDown = uidropdown(app.SignalPanel);
            app.SignalDropDown.Position = [66 144 211 22];

            % Create vDeltaEditFieldLabel
            app.vDeltaEditFieldLabel = uilabel(app.SignalPanel);
            app.vDeltaEditFieldLabel.HorizontalAlignment = 'right';
            app.vDeltaEditFieldLabel.Position = [375 33 39 22];
            app.vDeltaEditFieldLabel.Text = 'vDelta';

            % Create vDeltaEditField
            app.vDeltaEditField = uieditfield(app.SignalPanel, 'numeric');
            app.vDeltaEditField.Position = [429 33 100 22];

            % Create ShowMeshButton
            app.ShowMeshButton = uibutton(app.SignalPanel, 'push');
            app.ShowMeshButton.ButtonPushedFcn = createCallbackFcn(app, @ShowMeshButtonPushed, true);
            app.ShowMeshButton.Position = [13 174 270 26];
            app.ShowMeshButton.Text = 'Show Mesh';

            % Create Panel_2
            app.Panel_2 = uipanel(app.MeshPanel);
            app.Panel_2.AutoResizeChildren = 'off';
            app.Panel_2.Position = [12 265 564 65];

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.Panel_2);
            app.GridLayout3.RowHeight = {'1x'};

            % Create BackButton
            app.BackButton = uibutton(app.GridLayout3, 'push');
            app.BackButton.Layout.Row = 1;
            app.BackButton.Layout.Column = 1;
            app.BackButton.Text = 'Back';

            % Create PlayButton
            app.PlayButton = uibutton(app.GridLayout3, 'push');
            app.PlayButton.Layout.Row = 1;
            app.PlayButton.Layout.Column = 2;
            app.PlayButton.Text = 'Play';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = BctFilterDesigner

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end