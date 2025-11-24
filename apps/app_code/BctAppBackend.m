classdef BctAppBackend
    % BCTAPPBACKEND Backend logic for BctFilterDesigner app
    %
    % This class contains all custom business logic, data processing,
    % and visualization functions used by the BctFilterDesigner.mlapp GUI.
    %
    % Architecture:
    %   - Frontend (.mlapp): UI components and event handlers only
    %   - Backend (.m): All custom logic, reusable and testable
    %
    % Usage from app callbacks:
    %   BctAppBackend.scanWorkspace(app);
    %   BctAppBackend.updateUIAfterLoad(app);
    %   etc.
    
    methods (Static)
        
        %% Workspace Management
        
        function scanWorkspace(app)
            % Scan MATLAB base workspace for bct.bct objects
            % Populates the tree view with found BCT objects
            
            % Clear all existing children under DataNode
            delete(app.DataNode.Children);
            
            % Get all variables from base workspace
            vars = evalin('base', 'whos');
            
            % Storage for BCTObjects
            app.BCTObjects = struct();
            
            for i = 1:numel(vars)
                if strcmp(vars(i).class, 'bct.bct')
                    varName = vars(i).name;
                    
                    % Store the object itself internally
                    app.BCTObjects.(varName) = evalin('base', varName);
                    
                    % Add a tree node for this variable
                    node = uitreenode(app.DataNode);
                    node.Text = varName;
                    node.NodeData = varName;
                end
            end
            
            % Expand the tree
            expand(app.Tree);
            
            % Notify the user if nothing was found
            if isempty(fieldnames(app.BCTObjects))
                uialert(app.UIFigure, ...
                    'No variables of type bct.bct were found in the workspace.', ...
                    'Workspace Scan');
            end
        end
        
        %% UI Update Functions
        
        function updateUIAfterLoad(app)
            % Main UI update after BCT object is loaded
            % Orchestrates all necessary UI updates
            
            B = app.CurrentBCT;
            
            % Update kernel slider ranges based on domain axes
            BctAppBackend.updateKernelSliders(app, B);
            
            % Update text area
            BctAppBackend.updateTextArea(app, B);
            
            % Update the joint axes
            BctAppBackend.updateJointAxes(app, B, app.UIAxesResponse);
        end
        
        function updateTextArea(app, B)
            % Populate the text area with mesh + time resolution info
            
            % Build spatial info
            spatial_lines = {
                '--- Spatial (Manifold) ---'
                sprintf('Vertices: %d', B.Manifold.N)
                sprintf('Units: %s', B.Manifold.units)
            };
            
            % Lambda is always created as Manifold's dual
            % Check if eigenbasis has been computed (has actual eigenvalues)
            if ~isempty(B.Lambda)
                if ~isempty(B.Lambda.lambda)
                    % Eigenbasis computed
                    spatial_lines{end+1} = sprintf('Eigenmodes: %d (computed)', B.Lambda.K);
                    spatial_lines{end+1} = sprintf('Max wavenumber: %.2f rad/mm', max(B.Lambda.axis));
                else
                    % Only estimated axis available
                    spatial_lines{end+1} = 'Lambda: estimated (eigenbasis not computed)';
                end
            end
            
            % Build temporal info
            temporal_lines = {''};
            if ~isempty(B.Time)
                temporal_lines = {
                    ''
                    '--- Temporal (Time) ---'
                    sprintf('Samples: %d', B.Time.N)
                    sprintf('Sampling rate: %.1f Hz', B.Time.fs)
                    sprintf('Duration: %.2f s', B.Time.T/B.Time.fs)
                };
                
                % Omega is automatically created as Time's dual
                if ~isempty(B.Omega)
                    temporal_lines{end+1} = sprintf('Omega: %d frequencies', length(B.Omega.axis));
                    temporal_lines{end+1} = sprintf('Nyquist: %.1f Hz', max(B.Omega.axis)/(2*pi));
                end
            end
            
            % Combine and display
            lines = [spatial_lines; temporal_lines];
            
            % Add Joint domain info if available
            if ~isempty(B.Joint)
                sz = B.Joint.size();
                joint_lines = {
                    ''
                    '--- Joint Domain ---'
                    sprintf('Type: %s', B.Joint.Domain)
                    sprintf('Grid: [%d×%d]', sz(1), sz(2))
                    sprintf('Units: %s', B.Joint.units)
                };
                lines = [lines; joint_lines];
            end
            
            app.TextArea.Value = lines;
        end
        
        function updateKernelSliders(app, B)
            % Update kernel parameter slider ranges based on domain axes
            
            % Lambda is automatically created as Manifold's dual
            % Lambda.axis is always available (estimated or computed)
            if ~isempty(B.Lambda) && ~isempty(B.Lambda.axis)
                k_max = max(B.Lambda.axis);  % Wavenumber (rad/mm)
            else
                k_max = 10;  % fallback
            end
            
            % Spatial sliders
            app.k0Slider.Limits      = [0 k_max];
            app.k0Slider.Value       = k_max/4;
            
            app.sigma_kSlider.Limits = [k_max/200  k_max/5];
            app.sigma_kSlider.Value  = k_max/20;
            
            % Temporal sliders
            % Omega is automatically created as Time's dual
            if ~isempty(B.Omega) && ~isempty(B.Omega.axis)
                omega_max = max(abs(B.Omega.axis));  % Max angular frequency (rad/s)
            elseif ~isempty(B.Time)
                nyquist = B.Time.fs/2;
                omega_max = 2*pi*nyquist;  % Convert to rad/s
            else
                omega_max = 2*pi*50;  % fallback
            end
            
            app.omegaSlider.Limits      = [-omega_max  omega_max];
            app.omegaSlider.Value       = 0;
            
            app.sigma_oSlider.Limits    = [omega_max/200   omega_max/5];
            app.sigma_oSlider.Value     = omega_max/20;
            
            % After ranges are updated, refresh the kernel preview
            BctAppBackend.updateKernelPreview(app);
        end
        
        function updateJointAxes(app, B, ax)
            % Automatically configure the joint spectral axes
            % Default: wavenumber k (rad/mm) vs frequency f (Hz)
            %
            % Args:
            %   B  = bct.bct object
            %   ax = handle to uiaxes (e.g., app.UIAxesResponse)
            
            if nargin < 3
                ax = app.UIAxesResponse;   % default joint axes
            end
            
            % Spatial resolution (wavenumber)
            if ~isempty(B.Lambda) && ~isempty(B.Lambda.axis)
                kmax = max(B.Lambda.axis);  % Max wavenumber (rad/mm)
            else
                kmax = 10;  % fallback
            end
            
            % Temporal resolution
            if ~isempty(B.Omega) && ~isempty(B.Omega.axis)
                omega_max = max(B.Omega.axis);  % Max angular frequency (rad/s)
                nyq = omega_max / (2*pi);       % Convert to Hz
            elseif ~isempty(B.Time)
                fs = B.Time.fs;        % sampling frequency
                nyq = fs / 2;          % Nyquist (Hz)
            else
                nyq = 25;  % fallback
            end
            
            % Set axes limits
            ax.XLim = [0 nyq];       % frequency axis (Hz)
            ax.YLim = [0 kmax];      % wavenumber axis (rad/mm)
            
            % Set labels
            ax.XLabel.String = 'Frequency (Hz)';
            ax.YLabel.String = 'Wavenumber k (rad/mm)';
            
            % Set title
            ax.Title.String = 'Joint Spectrum (k vs f)';
            
            % Grid & formatting
            ax.XGrid = 'on';
            ax.YGrid = 'on';
        end
        
        %% Viewer Management
        
        function attachViewer(app, B)
            % Attach B.Viewer to the grid layout app.GridLayout2
            
            parent = app.GridLayout2;
            
            % CASE 1: No viewer exists → create inside grid
            if isempty(B.Viewer) || ~isvalid(B.Viewer)
                B.showMesh('Parent', parent);
                viewer = B.Viewer;
            else
                viewer = B.Viewer;
                
                % CASE 2: Viewer exists but is attached to a standalone figure
                if isa(viewer.Parent, 'matlab.ui.Figure')
                    % Recreate inside grid
                    B.showMesh('Parent', parent);
                    viewer = B.Viewer;
                end
            end
            
            % Assign layout to fill ALL rows/columns
            numRows = numel(parent.RowHeight);
            numCols = numel(parent.ColumnWidth);
            
            % Fill entire grid
            viewer.Layout.Row = [1 numRows];
            viewer.Layout.Column = [1 numCols];
            
            drawnow;
        end
        
        %% Joint Domain Helpers
        
        function [L, O] = buildJointGrid(app, lambda_values)
            % Build joint (lambda × omega) grid using Joint class
            % Uses B.Joint if available, otherwise creates Lambda×Omega joint
            
            B = app.CurrentBCT;
            
            % Check if Joint domain already exists
            if ~isempty(B.Joint)
                % Use existing Joint domain
                L = B.Joint.A_grid;  % Lambda grid
                O = B.Joint.B_grid;  % Omega grid
            else
                % Create Joint domain from Lambda and Omega
                if isempty(B.Lambda) || isempty(B.Omega)
                    error('BctFilterDesigner:NoLambdaOmega', ...
                        'Lambda and Omega domains must exist. Assign Time to BCT first.');
                end
                
                % Create Joint domain
                B = B.createJoint('Lambda', 'Omega');
                app.CurrentBCT = B;  % Update stored reference
                
                % Get grids from newly created Joint
                L = B.Joint.A_grid;  % Lambda grid
                O = B.Joint.B_grid;  % Omega grid
            end
        end
        
        function [L, W, f] = buildFullJointGrid(app, lam)
            % Build full joint grid using Joint class
            % Uses B.Joint if available, otherwise creates Lambda×Omega joint
            
            B = app.CurrentBCT;
            
            % Check if Joint domain already exists
            if ~isempty(B.Joint)
                % Use existing Joint domain
                L = B.Joint.A_grid;  % Lambda grid (eigenvalues)
                W = B.Joint.B_grid;  % Omega grid (angular frequency)
                f = W / (2*pi);      % Convert to Hz
            else
                % Create Joint domain from Lambda and Omega
                if isempty(B.Lambda) || isempty(B.Omega)
                    error('BctFilterDesigner:NoLambdaOmega', ...
                        'Lambda and Omega domains must exist.');
                end
                
                % Create Joint domain
                B = B.createJoint('Lambda', 'Omega');
                app.CurrentBCT = B;  % Update stored reference
                
                % Get grids from newly created Joint
                L = B.Joint.A_grid;  % Lambda grid
                W = B.Joint.B_grid;  % Omega grid (angular frequency)
                f = W / (2*pi);      % Convert to Hz
            end
        end
        
        %% Filter Design
        
        function createDefaultFilter(app)
            % Create default Joint filter (Lambda × Omega) with separable Gaussian kernels
            % This is called when BCT is loaded or FilterTypeDropDown changes
            
            B = app.CurrentBCT;
            
            % Ensure Joint domain exists
            if isempty(B.Joint)
                try
                    B = B.createJoint('Lambda', 'Omega');
                    app.CurrentBCT = B;
                catch ME
                    warning('BctFilterDesigner:CreateJoint', 'Could not create Joint domain: %s', ME.message);
                    return;
                end
            end
            
            % Get default parameters from slider values (if available)
            if ~isempty(app.k0Slider.Value)
                k0 = app.k0Slider.Value;
            else
                k0 = 0.1;  % Default center wavenumber (rad/mm)
            end
            
            if ~isempty(app.sigma_kSlider.Value)
                sigma_k = app.sigma_kSlider.Value;
            else
                sigma_k = 0.05;  % Default bandwidth
            end
            
            if ~isempty(app.omegaSlider.Value)
                omega0 = app.omegaSlider.Value;
            else
                omega0 = 20 * 2*pi;  % Default 20 Hz in rad/s
            end
            
            if ~isempty(app.sigma_oSlider.Value)
                sigma_o = app.sigma_oSlider.Value;
            else
                sigma_o = 5 * 2*pi;  % Default 5 Hz bandwidth
            end
            
            % Create Joint filter using FilterDesigner with Gabor kernel
            try
                app.CurrentFilter = app.FilterDesigner.joint('gabor', ...
                    'center_x', k0, 'sigma_x', sigma_k, ...
                    'center_y', omega0, 'sigma_y', sigma_o, ...
                    'label', 'Joint Lambda-Omega Filter');
            catch ME
                warning('BctFilterDesigner:CreateFilter', 'Could not create filter: %s', ME.message);
                app.CurrentFilter = [];
            end
        end
        
        function updateKernelPreview(app)
            % Update kernel preview using Filter object's kernel function
            % Evaluates the filter's kernel on a smooth preview grid
            
            if isempty(app.CurrentFilter)
                return;  % No filter to preview
            end
            
            ax = app.UIAxesKernel;
            
            % Build preview grid (finer than domain grid for smooth visualization)
            k_axis = app.CurrentBCT.Lambda.axis;  % Wavenumber axis
            omega_axis = app.CurrentBCT.Omega.axis;  % Angular frequency axis
            
            k = linspace(min(k_axis), max(k_axis), 200);
            w = linspace(min(omega_axis), max(omega_axis), 200);
            
            [W, K] = ndgrid(w, k);
            
            % Evaluate using Filter's kernel function directly
            kernel_fh = app.CurrentFilter.KernelFunction;
            params = app.CurrentFilter.Parameters;
            
            F = kernel_fh(K, W, ...
                params.center_x, params.center_y, ...
                params.sigma_x, params.sigma_y);
            
            % Plot
            cla(ax);
            imagesc(ax, k, w/(2*pi), F);
            axis(ax,'xy');
            xlabel(ax, 'Wavenumber k (rad/mm)');
            ylabel(ax, 'Frequency (Hz)');
            title(ax, sprintf('Kernel: %s | k_0=%.3f, \\sigma_k=%.3f', ...
                app.CurrentFilter.KernelName, params.center_x, params.sigma_x));
            colormap(ax, 'turbo');
            colorbar(ax);
        end
        
        %% Visualization
        
        function visualizeJointFilter(app, freq, L, F)
            % Visualizes joint filter on UIAxesResponse
            
            ax = app.UIAxesResponse;
            cla(ax);
            
            % surf plot (freq × lambda)
            surf(ax, freq, L, F, 'EdgeColor','none');
            
            xlabel(ax, 'Frequency (Hz)');
            ylabel(ax, 'Wavenumber k (sqrt(\lambda))');
            zlabel(ax, 'Magnitude');
            title(ax, 'Joint Filter Response');
            
            colormap(ax, 'turbo');
            shading(ax, 'interp');
            view(ax, 2);   % 2D heatmap view
            
            colorbar(ax);
        end
        
    end
end
