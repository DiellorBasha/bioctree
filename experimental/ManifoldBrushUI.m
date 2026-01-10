classdef ManifoldBrushUI < matlab.ui.componentcontainer.ComponentContainer
    % ManifoldBrushUI
    %
    % Inspector-style UI for selecting and configuring manifold brushes
    % using the bct.brush API.
    %
    % Layout:
    %   [ Brush Type List | Brush Parameters ]
    %
    % Responsibilities:
    %   - Choose manifold brush type (delta, gaussian, spectral, etc.)
    %   - Configure brush parameters (sigma, kernel, etc.)
    %   - Update ManifoldBrushModel with selections
    %
    % Does NOT:
    %   - Depend on ManifoldController
    %   - Perform spatial selection itself

    %% =========================
    % Public API
    % =========================

    properties (SetObservable)
        Model bctui.model.ManifoldBrushModel
        Seed (1,1) double = 1  % Current seed vertex
    end

    %% =========================
    % Private state
    % =========================

    properties (Access = private)
        ModelListeners event.listener
        IsInitialized logical = false
        SuppressCallbacks logical = false  % Flag to prevent callback loops
    end

    properties (Access = private, Transient, NonCopyable)
        Grid matlab.ui.container.GridLayout

        % Left panel
        BrushTypeList matlab.ui.control.ListBox

        % Right panel
        ParamsPanel matlab.ui.container.Panel
        ParamsGrid matlab.ui.container.GridLayout
        
        % Parameter controls (created dynamically based on brush type)
        SigmaSpinner
        SigmaLabel
        MetricDropdown
        MetricLabel
        
        % Kernel editor (for spectral brush)
        KernelFactoryUI
        KernelModelInstance
    end

    %% =========================
    % Lifecycle
    % =========================

    methods (Access = protected)
        
        function delete(comp)
            % Clean up listeners on component destruction
            if ~isempty(comp.ModelListeners)
                delete(comp.ModelListeners(isvalid(comp.ModelListeners)));
            end
        end

        function setup(comp)

            % Root grid: 25% / 75%
            comp.Grid = uigridlayout(comp);
            comp.Grid.RowHeight    = {'1x'};
            comp.Grid.ColumnWidth = {'1x','3x'};

            %% Brush type list (left)
            comp.BrushTypeList = uilistbox(comp.Grid);
            comp.BrushTypeList.Layout.Row = 1;
            comp.BrushTypeList.Layout.Column = 1;

            comp.BrushTypeList.Items = {'Delta','Gaussian','Spectral','Geodesic'};
            comp.BrushTypeList.Value = 'Delta';

            comp.BrushTypeList.ValueChangedFcn = ...
                @(~,~)comp.onBrushTypeChanged();

            %% Parameters panel (right)
            comp.ParamsPanel = uipanel(comp.Grid, ...
                'Title','Brush Parameters');
            comp.ParamsPanel.Layout.Row = 1;
            comp.ParamsPanel.Layout.Column = 2;

            % Grid INSIDE panel (critical for resizing)
            comp.ParamsGrid = uigridlayout(comp.ParamsPanel);
            comp.ParamsGrid.RowHeight    = repmat({'fit'}, 1, 6);
            comp.ParamsGrid.ColumnWidth = {'fit', '1x'};
            comp.ParamsGrid.Padding = [10 10 10 10];
            comp.ParamsGrid.RowSpacing = 10;

            % Create kernel model (for spectral brush)
            % Use eigenvalue axis from 0 to 100 by default
            comp.KernelModelInstance = bctui.model.KernelModel(linspace(0, 100, 500));
            % Ensure it starts with a valid kernel type
            comp.KernelModelInstance.KernelType = 'Heat';
            
            % React to Model assignment
            addlistener(comp, 'Model', 'PostSet', ...
                @(~,~)comp.onModelChanged());
                
            % React to Seed changes
            addlistener(comp, 'Seed', 'PostSet', ...
                @(~,~)comp.onSeedChanged());
        end

        function update(comp)
            % Update UI based on model state
            
            % Guard against early callback
            if ~comp.IsInitialized || isempty(comp.Model)
                return;
            end
            
            % Suppress callbacks during programmatic updates
            comp.SuppressCallbacks = true;
            
            % Update brush type selection
            brushType = comp.Model.BrushType;
            switch brushType
                case "delta"
                    comp.BrushTypeList.Value = 'Delta';
                case "gaussian"
                    comp.BrushTypeList.Value = 'Gaussian';
                case "spectral"
                    comp.BrushTypeList.Value = 'Spectral';
                case "geodesic"
                    comp.BrushTypeList.Value = 'Geodesic';
            end
            
            % Update parameter controls
            comp.updateParamControls();
            
            % Re-enable callbacks
            comp.SuppressCallbacks = false;
        end
    end

    %% =========================
    % Public methods
    % =========================

    methods
        function initialize(comp)
            % Call once after Model is set
            comp.IsInitialized = true;
            comp.buildParamControls();
            comp.update();
        end
    end

    %% =========================
    % Internal logic
    % =========================

    methods (Access = private)

        function onModelChanged(comp)
            % Handle Model property changes
            
            % Clear old listeners
            if ~isempty(comp.ModelListeners)
                delete(comp.ModelListeners(isvalid(comp.ModelListeners)));
            end
            
            if isempty(comp.Model)
                return;
            end
            
            % Add listener for brush updates (bound method reference)
            comp.ModelListeners = addlistener(comp.Model, ...
                'BrushUpdated', @comp.onBrushUpdated);
        end
        
        function onBrushUpdated(comp, ~, ~)
            % Handle brush updated event from model
            
            % Guard against deleted component
            if ~isvalid(comp) || ~comp.IsInitialized
                return;
            end
            
            comp.update();
        end
        
        function onSeedChanged(comp)
            % Handle Seed property changes
            
            % Guard against deleted component or early callback
            if ~isvalid(comp) || ~comp.IsInitialized || isempty(comp.Model)
                return;
            end
            
            comp.Model.setSeed(comp.Seed);
        end

        function onBrushTypeChanged(comp)
            % Handle brush type selection changes
            
            % Guard against deleted component and callbacks during programmatic updates
            if ~isvalid(comp) || comp.SuppressCallbacks || ~comp.IsInitialized || isempty(comp.Model)
                return;
            end

            brushType = lower(comp.BrushTypeList.Value);
            
            % Set default parameters for brush type
            switch brushType
                case 'delta'
                    params = struct('source', comp.Seed);
                    
                case 'gaussian'
                    params = struct('source', comp.Seed, ...
                                  'sigma', 10, ...
                                  'metric', 'geometry');
                    
                case 'spectral'
                    params = struct('source', comp.Seed, ...
                                  'kernel', 'heat', ...
                                  'bandwidth', []);
                    
                case 'geodesic'
                    params = struct('source', comp.Seed, ...
                                  'sigma', 10, ...
                                  'metric', 'geodesic');
            end
            
            % Update model
            comp.Model.setBrushType(brushType, params);
            
            % Rebuild parameter controls
            comp.buildParamControls();
            comp.updateParamControls();
        end
        
        function buildParamControls(comp)
            % Build parameter controls based on brush type
            
            % Clear existing controls
            comp.clearParamControls();
            
            if ~comp.IsInitialized || isempty(comp.Model)
                return;
            end
            
            brushType = comp.Model.BrushType;
            row = 1;
            
            % Sigma parameter (for gaussian/geodesic only, NOT spectral)
            if brushType == "gaussian" || brushType == "geodesic"
                comp.SigmaLabel = uilabel(comp.ParamsGrid, 'Text', 'Sigma:');
                comp.SigmaLabel.Layout.Row = row;
                comp.SigmaLabel.Layout.Column = 1;
                
                comp.SigmaSpinner = uispinner(comp.ParamsGrid);
                comp.SigmaSpinner.Layout.Row = row;
                comp.SigmaSpinner.Layout.Column = 2;
                comp.SigmaSpinner.Limits = [0.1 100];
                comp.SigmaSpinner.Step = 1;
                comp.SigmaSpinner.ValueChangedFcn = @(~,~)comp.onParamChanged('sigma', comp.SigmaSpinner.Value);
                row = row + 1;
                
                % Metric parameter
                comp.MetricLabel = uilabel(comp.ParamsGrid, 'Text', 'Metric:');
                comp.MetricLabel.Layout.Row = row;
                comp.MetricLabel.Layout.Column = 1;
                
                comp.MetricDropdown = uidropdown(comp.ParamsGrid);
                comp.MetricDropdown.Layout.Row = row;
                comp.MetricDropdown.Layout.Column = 2;
                comp.MetricDropdown.Items = {'Geometry', 'Geodesic'};
                comp.MetricDropdown.ItemsData = {'geometry', 'geodesic'};
                comp.MetricDropdown.ValueChangedFcn = @(~,~)comp.onParamChanged('metric', comp.MetricDropdown.Value);
                row = row + 1;
            end
            
            % Spectral-specific parameters
            if brushType == "spectral"
                % Kernel editor (interactive kernel shape)
                comp.KernelFactoryUI = bctui.component.KernelFactoryUI('Parent', comp.ParamsGrid);
                comp.KernelFactoryUI.Layout.Row = [row row+6];  % Span multiple rows
                comp.KernelFactoryUI.Layout.Column = [1 2];
                comp.KernelFactoryUI.Model = comp.KernelModelInstance;
                
                % Connect kernel model changes to brush model
                addlistener(comp.KernelModelInstance, 'KernelType', 'PostSet', ...
                    @(~,~)comp.onKernelModelChanged());
                addlistener(comp.KernelModelInstance, 'Parameters', 'PostSet', ...
                    @(~,~)comp.onKernelModelChanged());
            end
        end
        
        function clearParamControls(comp)
            % Clear all parameter controls
            controls = {comp.SigmaSpinner, comp.SigmaLabel, ...
                       comp.MetricDropdown, comp.MetricLabel, ...
                       comp.KernelFactoryUI};
                   
            for i = 1:numel(controls)
                if ~isempty(controls{i}) && isvalid(controls{i})
                    delete(controls{i});
                end
            end
            
            comp.SigmaSpinner = [];
            comp.SigmaLabel = [];
            comp.MetricDropdown = [];
            comp.MetricLabel = [];
            comp.KernelFactoryUI = [];
        end
        
        function updateParamControls(comp)
            % Update parameter control values from model
            
            if isempty(comp.Model)
                return;
            end
            
            % Sigma
            if ~isempty(comp.SigmaSpinner) && isvalid(comp.SigmaSpinner)
                sigma = comp.Model.getParam('sigma');
                if ~isempty(sigma)
                    comp.SigmaSpinner.Value = sigma;
                end
            end
            
            % Kernel model (sync from brush model)
            if ~isempty(comp.KernelFactoryUI) && isvalid(comp.KernelFactoryUI)
                kernel = comp.Model.getParam('kernel');
                if ~isempty(kernel)
                    % Convert 'heat' -> 'Heat', 'gaussian' -> 'Gaussian', etc.
                    comp.KernelModelInstance.KernelType = [upper(kernel(1)) kernel(2:end)];
                end
            end
            
            % Metric
            if ~isempty(comp.MetricDropdown) && isvalid(comp.MetricDropdown)
                metric = comp.Model.getParam('metric');
                if ~isempty(metric)
                    comp.MetricDropdown.Value = metric;
                end
            end
        end
        
        function onParamChanged(comp, paramName, value)
            % Handle parameter value changes
            
            % Guard against deleted component and callbacks during programmatic updates
            if ~isvalid(comp) || comp.SuppressCallbacks || isempty(comp.Model)
                return;
            end
            
            % Update model
            comp.Model.setParam(paramName, value);
        end
        
        function onKernelModelChanged(comp)
            % Handle kernel model changes and sync to brush model
            
            % Guard against deleted component and callbacks during programmatic updates
            if ~isvalid(comp) || comp.SuppressCallbacks || isempty(comp.Model)
                return;
            end
            
            % Get kernel type from kernel model (convert from 'Heat' to 'heat')
            kernelType = lower(comp.KernelModelInstance.KernelType);
            
            % Update brush model kernel parameter
            comp.Model.setParam('kernel', kernelType);
        end
    end
end
