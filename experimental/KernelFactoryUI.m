classdef KernelFactoryUI < matlab.ui.componentcontainer.ComponentContainer

    % ============================================================
    % Public API
    % ============================================================
    properties (SetObservable)
        Model bctui.model.KernelModel
    end

    % ============================================================
    % UI Components (private) – SAME AS KernelShapeViewer
    % ============================================================

    properties (Access = private, Transient, NonCopyable)

        GridLayout      matlab.ui.container.GridLayout
        UIAxes          matlab.ui.control.UIAxes

        KernelDropDown  matlab.ui.control.DropDown

        Slider1Label    matlab.ui.control.Label
        Slider2Label    matlab.ui.control.Label
        Slider1         matlab.ui.control.Slider
        Slider2         matlab.ui.control.Slider

        EquationLabel   matlab.ui.control.Label
        
        IsUpdating logical = false  % Flag to prevent update loops
    end
    % ============================================================
    % Lifecycle
    % ============================================================
    methods (Access = protected)

        function setup(comp)

            %comp.Position = [1 1 320 240];

            % --------------------------------------------------
            % Grid layout (IDENTICAL to KernelShapeViewer)
            % --------------------------------------------------
            comp.GridLayout = uigridlayout(comp);
            comp.GridLayout.ColumnWidth = {'1x','1x','1x','1x','1x','1x'};
            comp.GridLayout.RowHeight = ...
                {'fit','fit','fit','1x','1x','1x','1x','1x','1x'};

            % --------------------------------------------------
            % Kernel dropdown
            % --------------------------------------------------
            comp.KernelDropDown = uidropdown(comp.GridLayout);
            comp.KernelDropDown.Layout.Row = 1;
            comp.KernelDropDown.Layout.Column = [1 6];
            comp.KernelDropDown.ValueChangedFcn = @(~,~)comp.onKernelChanged();

            % --------------------------------------------------
            % Slider 1
            % --------------------------------------------------
            comp.Slider1Label = uilabel(comp.GridLayout);
            comp.Slider1Label.HorizontalAlignment = 'right';
            comp.Slider1Label.Interpreter = 'latex';
            comp.Slider1Label.Layout.Row = 2;
            comp.Slider1Label.Layout.Column = 1;

            comp.Slider1 = uislider(comp.GridLayout);
            comp.Slider1.Layout.Row = 2;
            comp.Slider1.Layout.Column = [2 3];
            comp.Slider1.MajorTicks = [];
            comp.Slider1.MinorTicks = [];
            comp.Slider1.ValueChangedFcn = @(~,~)comp.onSliderChanged();

            % --------------------------------------------------
            % Slider 2
            % --------------------------------------------------
            comp.Slider2Label = uilabel(comp.GridLayout);
            comp.Slider2Label.HorizontalAlignment = 'right';
            comp.Slider2Label.Interpreter = 'latex';
            comp.Slider2Label.Layout.Row = 2;
            comp.Slider2Label.Layout.Column = 4;
            comp.Slider2Label.Visible = 'off';

            comp.Slider2 = uislider(comp.GridLayout);
            comp.Slider2.Layout.Row = 2;
            comp.Slider2.Layout.Column = [5 6];
            comp.Slider2.MajorTicks = [];
            comp.Slider2.MinorTicks = [];
            comp.Slider2.ValueChangedFcn = @(~,~)comp.onSliderChanged();
            comp.Slider2.Visible = 'off';

            % --------------------------------------------------
            % Equation label
            % --------------------------------------------------
            comp.EquationLabel = uilabel(comp.GridLayout);
            comp.EquationLabel.Layout.Row = 3;
            comp.EquationLabel.Layout.Column = [1 6];
            comp.EquationLabel.Interpreter = 'latex';
            comp.EquationLabel.HorizontalAlignment = 'center';
            comp.EquationLabel.Visible="off";

            % --------------------------------------------------
            % Axes (NO labels, ticks, etc.)
            % --------------------------------------------------
            comp.UIAxes = uiaxes(comp.GridLayout);
            comp.UIAxes.Layout.Row = [4 9];
            comp.UIAxes.Layout.Column = [1 6];
            axis(comp.UIAxes,'off');
            hold(comp.UIAxes,'on');
        end

        function update(comp)

            if isempty(comp.Model) || comp.IsUpdating
                return;
            end
            
            comp.IsUpdating = true;

            registry = KernelRegistry.getRegistry();
            kernelNames = fieldnames(registry);

            % Populate dropdown
            comp.KernelDropDown.Items = kernelNames;
            comp.KernelDropDown.Value = comp.Model.KernelType;

            k = registry.(comp.Model.KernelType);

            % Equation
            comp.EquationLabel.Text = k.EquationLatex;

            % Parameter UI
            ranges = k.ParamRanges(comp.Model.Axis);
            params = comp.Model.Parameters;

            switch k.NumParams
                case 1
                    pname = k.ParamNames{1};

                    comp.Slider1Label.Text = ['$\' pname];
                    comp.Slider1.Limits = ranges.(pname);
                    comp.Slider1.Value  = params.(pname);
                    comp.Slider1.Layout.Column = [2 6];
                    comp.Slider2.Visible = 'off';
                    comp.Slider2Label.Visible = 'off';

                case 2
                    p1 = k.ParamNames{1};
                    p2 = k.ParamNames{2};

                    comp.Slider1Label.Text = ['$\' p1];
                    comp.Slider2Label.Text = ['$\' p2];
    
                    comp.Slider1.Limits = ranges.(p1);
                    comp.Slider2.Limits = ranges.(p2);

                    comp.Slider1.Value = params.(p1);
                    comp.Slider2.Value = params.(p2);

                    comp.Slider2.Visible = 'on';
                    comp.Slider2Label.Visible = 'on';
                    comp.Slider1.Layout.Column = [2 3];
            end

            % --------------------------------------------------
            % Kernel preview (CORRECT)
            % --------------------------------------------------
            comp.updatePlot();
            
            comp.IsUpdating = false;
        end
    end

    % ============================================================
    % Callbacks
    % ============================================================
    methods (Access = private)

        function onKernelChanged(comp)
            if comp.IsUpdating
                return;
            end
            comp.Model.KernelType = comp.KernelDropDown.Value;
            comp.update();
        end

        function onSliderChanged(comp)
            if comp.IsUpdating
                return;
            end

            registry = KernelRegistry.getRegistry();
            k = registry.(comp.Model.KernelType);

            % Get fresh copy of parameters
            params = comp.Model.Parameters;

            switch k.NumParams
                case 1
                    params.(k.ParamNames{1}) = comp.Slider1.Value;
                case 2
                    params.(k.ParamNames{1}) = comp.Slider1.Value;
                    params.(k.ParamNames{2}) = comp.Slider2.Value;
            end

            % Assign back to model (this should trigger updateKernel via setter)
            comp.Model.Parameters = params;
            
            % Explicitly update kernel function (in case setter didn't trigger)
            comp.Model.updateKernel();
            
            % Update the plot with latest kernel function
            comp.updatePlot();
        end
        
        function updatePlot(comp)
            % Update only the kernel visualization
            if isempty(comp.Model)
                return;
            end
            
            cla(comp.UIAxes);

            fplot( ...
                comp.UIAxes, ...
                comp.Model.KernelFunction, ...
                [min(comp.Model.Axis), max(comp.Model.Axis)], ...
                'LineWidth', 2);

            axis(comp.UIAxes,'tight');
            xlim(comp.UIAxes,'padded');
            ylim(comp.UIAxes,'padded');
            axis(comp.UIAxes,'off');
        end
    end
end
