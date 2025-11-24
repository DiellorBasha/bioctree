classdef BctFilterDesignerCode < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        GridLayout               matlab.ui.container.GridLayout
        LeftPanel                matlab.ui.container.Panel
        SynthesizeButton         matlab.ui.control.Button
        DesignButton             matlab.ui.control.Button
        ShowMeshButton           matlab.ui.control.Button
        TextArea                 matlab.ui.control.TextArea
        ResolutionLabel          matlab.ui.control.Label
        kmodesEditField          matlab.ui.control.NumericEditField
        kmodesEditFieldLabel     matlab.ui.control.Label
        FourierButton            matlab.ui.control.Button
        SpectralLabel            matlab.ui.control.Label
        LoadButton               matlab.ui.control.Button
        ScanButton               matlab.ui.control.Button
        Tree                     matlab.ui.container.Tree
        DataNode                 matlab.ui.container.TreeNode
        Node2                    matlab.ui.container.TreeNode
        Node3                    matlab.ui.container.TreeNode
        Node4                    matlab.ui.container.TreeNode
        FilterTypeDropDown       matlab.ui.control.DropDown
        FilterTypeDropDownLabel  matlab.ui.control.Label
        FilterDesignLabel        matlab.ui.control.Label
        CenterPanel              matlab.ui.container.Panel
        TabGroup                 matlab.ui.container.TabGroup
        JointTab                 matlab.ui.container.Tab
        omegaSlider              matlab.ui.control.Slider
        omegaSliderLabel         matlab.ui.control.Label
        sigma_kSlider            matlab.ui.control.Slider
        sigma_kSliderLabel       matlab.ui.control.Label
        sigma_oSlider            matlab.ui.control.Slider
        sigma_oSliderLabel       matlab.ui.control.Label
        k0Slider                 matlab.ui.control.Slider
        k0SliderLabel            matlab.ui.control.Label
        UIAxesResponse           matlab.ui.control.UIAxes
        UIAxesKernel             matlab.ui.control.UIAxes
        SpatialTab               matlab.ui.container.Tab
        SigmaEditField           matlab.ui.control.NumericEditField
        SigmaEditFieldLabel      matlab.ui.control.Label
        Centerk0EditField        matlab.ui.control.NumericEditField
        Centerk0EditFieldLabel   matlab.ui.control.Label
        SpatialparametersLabel   matlab.ui.control.Label
        ShowlambdaButton         matlab.ui.control.Button
        UIAxes                   matlab.ui.control.UIAxes
        TemporalTab              matlab.ui.container.Tab
        SigmafEditField          matlab.ui.control.NumericEditField
        SigmafEditFieldLabel     matlab.ui.control.Label
        Centerf0EditField        matlab.ui.control.NumericEditField
        Centerf0EditFieldLabel   matlab.ui.control.Label
        TemporalparametersLabel  matlab.ui.control.Label
        ShowomegaButton          matlab.ui.control.Button
        UIAxes_2                 matlab.ui.control.UIAxes
        MeshPanel                matlab.ui.container.Panel
        GridLayout2              matlab.ui.container.GridLayout
    end

    % Properties that correspond to apps with auto-reflow
    properties (Access = private)
        onePanelWidth = 576;
        twoPanelWidth = 768;
    end

    
    properties (Access = private)
        BCTObjects struct
        CurrentBCT bct.bct          % Current BCT object
        FilterDesigner              % bct.filters.FilterDesigner instance
        CurrentFilter               % bct.filters.Filter instance
    end
    
    % All custom methods moved to BctAppBackend.m
    % This keeps the .mlapp file small and git-friendly
    methods (Access = private)
        % No custom methods - all logic delegated to BctAppBackend
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: LoadButton
        function LoadButtonPushed(app, ~)
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
    BctAppBackend.createDefaultFilter(app);

    % Single high-level update - delegated to backend
    BctAppBackend.updateUIAfterLoad(app);

    uialert(app.UIFigure, sprintf('Loaded BCT object: %s', varName), 'Success');
        end

        % Button pushed function: ScanButton
        function ScanButtonPushed(app, ~)
             BctAppBackend.scanWorkspace(app);
        end

        % Button pushed function: ShowMeshButton
        function ShowMeshButtonPushed(app, ~)
            BctAppBackend.attachViewer(app, app.CurrentBCT);
        end

        % Button pushed function: FourierButton (Eigenbasis)
        function FourierButtonPushed(app, ~)
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
    msg = sprintf('Computing eigenbasis (%d modes) for Lambda domain... Please wait.', k);
    d = uiprogressdlg(app.UIFigure, 'Message', msg, ...
        'Title', 'Computing Eigenbasis', 'Indeterminate', 'on');

    % Compute eigenbasis - fills Lambda.lambda and Lambda.U
    % Lambda already exists as Manifold's dual, this computes actual eigendecomposition
    try
        B = B.computeEigenbasis(k);
        app.CurrentBCT = B;  % Update stored reference
    catch ME
        close(d);
        uialert(app.UIFigure, ME.message, 'Eigenbasis Computation Error');
        return;
    end

    close(d);

    % Update UI (text area, axes, etc.) - delegated to backend
    BctAppBackend.updateUIAfterLoad(app);

    % Now that actual eigenvalues exist → update slider ranges - delegated to backend
    BctAppBackend.updateKernelSliders(app, B);

    uialert(app.UIFigure, ...
        sprintf('Successfully computed %d eigenmodes for Lambda domain.', k), ...
        'Done');
        end

        % Button pushed function: SynthesizeButton
        function SynthesizeButtonPushed(app, ~)
    % Synthesize and visualize filter response using Filter.evaluate()
    
    B = app.CurrentBCT;

    % Check if filter exists
    if isempty(app.CurrentFilter)
        uialert(app.UIFigure, 'No filter created. Load BCT object first.', 'No Filter');
        return;
    end

    % Lambda always exists as Manifold's dual
    % Check if eigenbasis has been computed (Lambda.lambda filled)
    if isempty(B.Lambda) || isempty(B.Lambda.lambda)
        uialert(app.UIFigure, 'Compute eigenbasis first (Eigenbasis button)', 'Eigenbasis Not Computed');
        return;
    end
    
    % Check if Omega exists (Time's dual)
    if isempty(B.Omega)
        uialert(app.UIFigure, 'Assign Time domain to BCT first (Omega is created automatically)', 'No Omega Domain');
        return;
    end

    % Ensure Joint domain exists
    if isempty(B.Joint)
        B = B.createJoint('Lambda', 'Omega');
        app.CurrentBCT = B;
    end

    % Evaluate filter on Joint domain
    % Filter.evaluate() uses the domain's axis/grid automatically
    try
        F = app.CurrentFilter.evaluate();
    catch ME
        uialert(app.UIFigure, sprintf('Filter evaluation failed: %s', ME.message), 'Error');
        return;
    end

    % Get grids for visualization
    LambdaGrid = B.Joint.A_grid;  % Wavenumber grid (k = sqrt(λ))
    OmegaGrid = B.Joint.B_grid;   % Angular frequency grid (rad/s)
    freq_grid = OmegaGrid / (2*pi);  % Convert to Hz

    % Visualize in Joint UIAxes - delegated to backend
    BctAppBackend.visualizeJointFilter(app, freq_grid, LambdaGrid, F);
        end

        % Value changed function: omegaSlider
        function omegaSliderValueChanged(app, ~)
            % Update Filter center frequency (omega0)
            if ~isempty(app.CurrentFilter)
                app.CurrentFilter.setParameter('center_y', app.omegaSlider.Value);
            end
            BctAppBackend.updateKernelPreview(app);
        end

        % Value changed function: sigma_oSlider
        function sigma_oSliderValueChanged(app, ~)
            % Update Filter frequency bandwidth (sigma_omega)
            if ~isempty(app.CurrentFilter)
                app.CurrentFilter.setParameter('sigma_y', app.sigma_oSlider.Value);
            end
            BctAppBackend.updateKernelPreview(app);
        end

        % Value changed function: k0Slider
        function k0SliderValueChanged(app, ~)
            % Update Filter center wavenumber (k0)
            if ~isempty(app.CurrentFilter)
                app.CurrentFilter.setParameter('center_x', app.k0Slider.Value);
            end
            BctAppBackend.updateKernelPreview(app);
        end

        % Value changed function: sigma_kSlider
        function sigma_kSliderValueChanged(app, ~)
            % Update Filter wavenumber bandwidth (sigma_k)
            if ~isempty(app.CurrentFilter)
                app.CurrentFilter.setParameter('sigma_x', app.sigma_kSlider.Value);
            end
            BctAppBackend.updateKernelPreview(app);
        end

        % Changes arrangement of the app based on UIFigure width
        function updateAppLayout(app, ~)
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
                app.GridLayout.ColumnWidth = {220, '1x', 529};
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
            app.UIFigure.Position = [100 100 1277 746];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @updateAppLayout, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {220, '1x', 529};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Scrollable = 'on';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create FilterDesignLabel
            app.FilterDesignLabel = uilabel(app.LeftPanel);
            app.FilterDesignLabel.Position = [26 259 72 22];
            app.FilterDesignLabel.Text = 'Filter Design';

            % Create FilterTypeDropDownLabel
            app.FilterTypeDropDownLabel = uilabel(app.LeftPanel);
            app.FilterTypeDropDownLabel.HorizontalAlignment = 'right';
            app.FilterTypeDropDownLabel.Position = [21 230 61 22];
            app.FilterTypeDropDownLabel.Text = 'Filter Type';

            % Create FilterTypeDropDown
            app.FilterTypeDropDown = uidropdown(app.LeftPanel);
            app.FilterTypeDropDown.Items = {'Spatial', 'Temporal', 'Joint Separable', 'Joint', 'Dynamic'};
            app.FilterTypeDropDown.Position = [97 230 100 22];
            app.FilterTypeDropDown.Value = 'Joint';

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
            app.SpectralLabel.Position = [27 374 88 22];
            app.SpectralLabel.Text = 'Lambda Domain';

            % Create FourierButton (Eigenbasis)
            app.FourierButton = uibutton(app.LeftPanel, 'push');
            app.FourierButton.ButtonPushedFcn = createCallbackFcn(app, @FourierButtonPushed, true);
            app.FourierButton.Position = [92 331 100 22];
            app.FourierButton.Text = 'Eigenbasis';

            % Create kmodesEditFieldLabel
            app.kmodesEditFieldLabel = uilabel(app.LeftPanel);
            app.kmodesEditFieldLabel.HorizontalAlignment = 'right';
            app.kmodesEditFieldLabel.Position = [27 351 50 22];
            app.kmodesEditFieldLabel.Text = 'k modes';

            % Create kmodesEditField
            app.kmodesEditField = uieditfield(app.LeftPanel, 'numeric');
            app.kmodesEditField.Position = [92 351 100 22];
            app.kmodesEditField.Value = 300;

            % Create ResolutionLabel
            app.ResolutionLabel = uilabel(app.LeftPanel);
            app.ResolutionLabel.Position = [24 471 62 22];
            app.ResolutionLabel.Text = 'Resolution';

            % Create TextArea
            app.TextArea = uitextarea(app.LeftPanel);
            app.TextArea.Position = [24 416 181 47];

            % Create ShowMeshButton
            app.ShowMeshButton = uibutton(app.LeftPanel, 'push');
            app.ShowMeshButton.ButtonPushedFcn = createCallbackFcn(app, @ShowMeshButtonPushed, true);
            app.ShowMeshButton.Position = [92 297 100 22];
            app.ShowMeshButton.Text = 'Show Mesh';

            % Create DesignButton
            app.DesignButton = uibutton(app.LeftPanel, 'push');
            app.DesignButton.Position = [105 19 100 22];
            app.DesignButton.Text = 'Design';

            % Create SynthesizeButton
            app.SynthesizeButton = uibutton(app.LeftPanel, 'push');
            app.SynthesizeButton.ButtonPushedFcn = createCallbackFcn(app, @SynthesizeButtonPushed, true);
            app.SynthesizeButton.Position = [97 177 100 22];
            app.SynthesizeButton.Text = 'Synthesize';

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

            % Create UIAxesKernel
            app.UIAxesKernel = uiaxes(app.JointTab);
            title(app.UIAxesKernel, 'Title')
            xlabel(app.UIAxesKernel, 'X')
            ylabel(app.UIAxesKernel, 'Y')
            zlabel(app.UIAxesKernel, 'Z')
            app.UIAxesKernel.Position = [228 493 272 210];

            % Create UIAxesResponse
            app.UIAxesResponse = uiaxes(app.JointTab);
            title(app.UIAxesResponse, 'Title')
            xlabel(app.UIAxesResponse, 'Frequency (Hz)')
            ylabel(app.UIAxesResponse, 'Wavenumber (k)')
            zlabel(app.UIAxesResponse, 'Z')
            app.UIAxesResponse.Position = [20 13 484 443];

            % Create k0SliderLabel
            app.k0SliderLabel = uilabel(app.JointTab);
            app.k0SliderLabel.HorizontalAlignment = 'right';
            app.k0SliderLabel.Position = [35 564 25 22];
            app.k0SliderLabel.Text = 'k0';

            % Create k0Slider
            app.k0Slider = uislider(app.JointTab);
            app.k0Slider.ValueChangedFcn = createCallbackFcn(app, @k0SliderValueChanged, true);
            app.k0Slider.Position = [82 573 102 3];

            % Create sigma_oSliderLabel
            app.sigma_oSliderLabel = uilabel(app.JointTab);
            app.sigma_oSliderLabel.HorizontalAlignment = 'right';
            app.sigma_oSliderLabel.Position = [12 613 50 22];
            app.sigma_oSliderLabel.Text = 'sigma_o';

            % Create sigma_oSlider
            app.sigma_oSlider = uislider(app.JointTab);
            app.sigma_oSlider.ValueChangedFcn = createCallbackFcn(app, @sigma_oSliderValueChanged, true);
            app.sigma_oSlider.Position = [84 622 100 3];

            % Create sigma_kSliderLabel
            app.sigma_kSliderLabel = uilabel(app.JointTab);
            app.sigma_kSliderLabel.HorizontalAlignment = 'right';
            app.sigma_kSliderLabel.Position = [10 512 50 22];
            app.sigma_kSliderLabel.Text = 'sigma_k';

            % Create sigma_kSlider
            app.sigma_kSlider = uislider(app.JointTab);
            app.sigma_kSlider.ValueChangedFcn = createCallbackFcn(app, @sigma_kSliderValueChanged, true);
            app.sigma_kSlider.Position = [82 521 106 3];

            % Create omegaSliderLabel
            app.omegaSliderLabel = uilabel(app.JointTab);
            app.omegaSliderLabel.HorizontalAlignment = 'right';
            app.omegaSliderLabel.Position = [20 658 42 22];
            app.omegaSliderLabel.Text = 'omega';

            % Create omegaSlider
            app.omegaSlider = uislider(app.JointTab);
            app.omegaSlider.ValueChangedFcn = createCallbackFcn(app, @omegaSliderValueChanged, true);
            app.omegaSlider.Position = [84 667 106 3];

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

            % Create TemporalTab
            app.TemporalTab = uitab(app.TabGroup);
            app.TemporalTab.Title = 'Temporal';

            % Create UIAxes_2
            app.UIAxes_2 = uiaxes(app.TemporalTab);
            title(app.UIAxes_2, 'Title')
            xlabel(app.UIAxes_2, 'Frequency (Hz)')
            ylabel(app.UIAxes_2, 'Wavenumber (k)')
            zlabel(app.UIAxes_2, 'Z')
            app.UIAxes_2.Position = [15 303 467 377];

            % Create ShowomegaButton
            app.ShowomegaButton = uibutton(app.TemporalTab, 'push');
            app.ShowomegaButton.Position = [110 55 100 22];
            app.ShowomegaButton.Text = 'Show omega';

            % Create TemporalparametersLabel
            app.TemporalparametersLabel = uilabel(app.TemporalTab);
            app.TemporalparametersLabel.Position = [28 138 118 22];
            app.TemporalparametersLabel.Text = 'Temporal parameters';

            % Create Centerf0EditFieldLabel
            app.Centerf0EditFieldLabel = uilabel(app.TemporalTab);
            app.Centerf0EditFieldLabel.HorizontalAlignment = 'right';
            app.Centerf0EditFieldLabel.Position = [41 107 54 22];
            app.Centerf0EditFieldLabel.Text = 'Center f0';

            % Create Centerf0EditField
            app.Centerf0EditField = uieditfield(app.TemporalTab, 'numeric');
            app.Centerf0EditField.Position = [110 107 100 22];

            % Create SigmafEditFieldLabel
            app.SigmafEditFieldLabel = uilabel(app.TemporalTab);
            app.SigmafEditFieldLabel.HorizontalAlignment = 'right';
            app.SigmafEditFieldLabel.Position = [49 87 46 22];
            app.SigmafEditFieldLabel.Text = 'Sigma f';

            % Create SigmafEditField
            app.SigmafEditField = uieditfield(app.TemporalTab, 'numeric');
            app.SigmafEditField.Position = [110 87 100 22];

            % Create MeshPanel
            app.MeshPanel = uipanel(app.GridLayout);
            app.MeshPanel.Layout.Row = 1;
            app.MeshPanel.Layout.Column = 3;

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.MeshPanel);
            app.GridLayout2.RowHeight = {'1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x'};

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