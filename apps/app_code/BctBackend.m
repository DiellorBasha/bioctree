classdef BctBackend
    % BctBackend Backend logic for BctFilterDesigner app
    %
    % This class contains all custom business logic, data processing,
    % and visualization functions used by the BctFilterDesigner.mlapp GUI.
    %
    % Architecture:
    %   - Frontend (.mlapp): UI components and event handlers only
    %   - Backend (.m): All custom logic, reusable and testable
    %
    % Usage from app callbacks:
    %   BctBackend.scanWorkspace(app);
    %   BctBackend.updateUIAfterLoad(app);
    %   etc.
    
    methods (Static)
        
        %% Workspace Management
        
        function loadDefaultBCT(app)
            % Load default BCT object (fsaverage right hemisphere) on app startup
            % Creates a BCT object with computed eigenbasis ready for filtering
            
            try
                % Load default fsaverage mesh
                B = bct_fsaverage('rh');
                
                % Compute eigenbasis (required for filters to work)
                fprintf('[loadDefaultBCT] Computing eigenbasis...\n');
                B = B.computeEigenbasis(100);  % 100 eigenmodes
                fprintf('[loadDefaultBCT] Eigenbasis computed: %d modes\n', B.Lambda.K);
                
                % Add Time domain to create Joint Manifold_Time and dual Lambda_Omega
                fprintf('[loadDefaultBCT] Creating Time domain...\n');
                B.Time = bct.Time(100, 10);  % 100 samples, 10 Hz sampling rate
                fprintf('[loadDefaultBCT] Time domain created, Joint: %s\n', B.Joint.Domain);
                
                % Store in BCTObjects struct
                app.BCTObjects = struct();
                app.BCTObjects.fsaverage_rh = B;
                
                % Set as current BCT
                app.CurrentBCT = B;
                
                % Initialize FilterDesigner
                app.FilterDesigner = bct.filters.FilterDesigner(app.CurrentBCT);
                
                % Create default filter
                BctBackend.createDefaultFilter(app);
                
                % Update UI to reflect loaded object
                BctBackend.updateUIAfterLoad(app);
                
                % Update workspace tree
                node = uitreenode(app.DataNode);
                node.Text = 'fsaverage_rh';
                node.NodeData = 'fsaverage_rh';
                expand(app.Tree);
                
            catch ME
                warning('BctFilterDesigner:LoadDefault', ...
                    'Could not load default BCT object: %s', ME.message);
            end
        end
        
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
        
        function scanSignals(app)
            % Scan MATLAB base workspace for bct.Signal objects
            % Populates SignalObjects structure and updates SignalDropDown
            
            % Get all variables from base workspace
            vars = evalin('base', 'whos');
            
            % Storage for SignalObjects
            app.SignalObjects = struct();
            
            for i = 1:numel(vars)
                if strcmp(vars(i).class, 'bct.Signal')
                    varName = vars(i).name;
                    
                    % Store the object itself internally
                    app.SignalObjects.(varName) = evalin('base', varName);
                end
            end
            
            % Update signal dropdown
            BctBackend.updateSignalDropDown(app);
            
            fprintf('[scanSignals] Found %d bct.Signal objects in workspace\n', ...
                length(fieldnames(app.SignalObjects)));
        end
        
        %% UI Update Functions
        
        function updateUIAfterLoad(app)
            % Main UI update after BCT object is loaded
            % Orchestrates all necessary UI updates
            
            B = app.CurrentBCT;
            
            % Update kernel slider ranges based on domain axes
            BctBackend.updateKernelSliders(app, B);
            
            % Update text area
            BctBackend.updateTextArea(app, B);
            
            % Update the joint axes
            BctBackend.updateJointAxes(app, B, app.UIAxesResponse);
            
            % Update signal dropdown
            BctBackend.updateSignalDropDown(app);
        end
        
        function updateSignalDropDown(app)
            % Populate SignalDropDown with available Signal objects
            % Includes signals from workspace (SignalObjects) and app signals
            
            signalNames = {};
            
            % Add signals from workspace (SignalObjects structure)
            if ~isempty(app.SignalObjects)
                workspaceSignalNames = fieldnames(app.SignalObjects);
                for i = 1:length(workspaceSignalNames)
                    signalNames{end+1} = sprintf('%s (workspace)', workspaceSignalNames{i});
                end
            end
            
            % Check for KronDelta signal
            if ~isempty(app.KronDelta) && isa(app.KronDelta, 'bct.Signal')
                signalNames{end+1} = 'KronDelta (app)';
            end
            
            % Check for IRSignal
            if ~isempty(app.IRSignal) && isa(app.IRSignal, 'bct.Signal')
                signalNames{end+1} = 'IRSignal (app)';
            end
            
            % Update dropdown items
            if isempty(signalNames)
                app.SignalDropDown.Items = {'No signals available'};
                app.SignalDropDown.Enable = 'off';
            else
                app.SignalDropDown.Items = signalNames;
                app.SignalDropDown.Enable = 'on';
                
                % Select first item by default
                if ~isempty(signalNames)
                    app.SignalDropDown.Value = signalNames{1};
                end
            end
            
            fprintf('[updateSignalDropDown] Dropdown updated with %d signals\n', length(signalNames));
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
            if ~isempty(B.Time) && ~isempty(B.Time.axis)
                % Calculate duration from Time.N and Time.axis
                nTime = B.Time.N;
                dt = B.Time.axis(2) - B.Time.axis(1);
                T_duration = (nTime - 1) * dt;
                
                temporal_lines = {
                    ''
                    '--- Temporal (Time) ---'
                    sprintf('Samples: %d', nTime)
                    sprintf('Sampling rate: %.1f Hz', B.Time.fs)
                    sprintf('Duration: %.2f s', T_duration)
                };
                
                % Omega is automatically created as Time's dual
                if ~isempty(B.Omega) && ~isempty(B.Omega.axis)
                    temporal_lines{end+1} = sprintf('Omega: %d frequencies', length(B.Omega.axis));
                    temporal_lines{end+1} = sprintf('Nyquist: %.1f Hz', max(B.Omega.axis)/(2*pi));
                end
            end
            
            % Combine and display
            lines = [spatial_lines; temporal_lines];
            
            % Add Joint domain info if available
            if ~isempty(B.Joint)
                dims = B.Joint.N;
                joint_lines = {
                    ''
                    '--- Joint Domain ---'
                    sprintf('Type: %s', B.Joint.Domain)
                    sprintf('Grid: [%d×%d]', dims(1), dims(2))
                    sprintf('Units: %s', B.Joint.units)
                };
                lines = [lines; joint_lines];
            end
            
            app.TextArea.Value = lines;
        end
        
        function updateKernelSliders(app, B)
            % Update kernel parameter slider ranges based on Joint.dual (spectral) domain axes
            % This ensures sliders match the actual Lambda_Omega domain where filters are evaluated
            
            % Get spectral Joint domain (Lambda × Omega)
            if ~isempty(B.Joint) && ~isempty(B.Joint.dual)
                spectralJoint = B.Joint.dual;  % Lambda_Omega
                
                % Get Lambda axis (wavenumber)
                k_axis = spectralJoint.axis{1};
                k_min = min(k_axis);
                k_max = max(k_axis);
                k_range = k_max - k_min;
                
                % Get Omega axis (angular frequency)
                omega_axis = spectralJoint.axis{2};
                omega_min = min(omega_axis);
                omega_max = max(omega_axis);
                omega_range = omega_max - omega_min;
                
            else
                % Fallback if Joint.dual not available
                if ~isempty(B.Lambda) && ~isempty(B.Lambda.axis)
                    k_axis = B.Lambda.axis;
                    k_min = min(k_axis);
                    k_max = max(k_axis);
                    k_range = k_max - k_min;
                else
                    k_min = 0;
                    k_max = 10;
                    k_range = 10;
                end
                
                if ~isempty(B.Omega) && ~isempty(B.Omega.axis)
                    omega_axis = B.Omega.axis;
                    omega_min = min(omega_axis);
                    omega_max = max(omega_axis);
                    omega_range = omega_max - omega_min;
                elseif ~isempty(B.Time)
                    omega_max = 2*pi * (B.Time.fs/2);
                    omega_min = 0;
                    omega_range = omega_max;
                else
                    omega_max = 2*pi*50;
                    omega_min = 0;
                    omega_range = omega_max;
                end
            end
            
            % Spatial sliders (Lambda/wavenumber)
            app.WavenumberSlider.Limits      = [k_min k_max];
            app.WavenumberSlider.Value       = k_min + k_range/4;  % 25% of range
            
            app.kbandwidthSlider.Limits = [k_range/200  k_range/3.33];  % Max increased by 50%
            app.kbandwidthSlider.Value  = k_range/20;  % 5% of range
            
            % Temporal sliders (Omega/frequency)
            app.FrequencySlider.Limits      = [omega_min  omega_max];
            app.FrequencySlider.Value       = omega_min + omega_range/2;  % Center
            
            app.BandwidthSlider.Limits    = [omega_range/200   omega_range/3.33];  % Max increased by 50%
            app.BandwidthSlider.Value     = omega_range/20;  % 5% of range
            
            % After ranges are updated, refresh the kernel preview
            BctBackend.updateKernelPreview(app);
        end
        
        function updateJointAxes(app, B, ax)
            % Automatically configure the joint spectral axes using Joint.dual domain
            % Uses the spectral Lambda_Omega domain for accurate axis ranges
            %
            % Args:
            %   B  = bct.bct object
            %   ax = handle to uiaxes (e.g., app.UIAxesResponse)
            
            if nargin < 3
                ax = app.UIAxesResponse;   % default joint axes
            end
            
            % Get spectral Joint domain (Lambda × Omega)
            if ~isempty(B.Joint) && ~isempty(B.Joint.dual)
                % Use Joint.dual if it's the spectral domain
                if strcmp(B.Joint.Domain, 'Manifold_Time')
                    spectralJoint = B.Joint.dual;  % Lambda_Omega
                else
                    spectralJoint = B.Joint;  % Already Lambda_Omega
                end
                
                % Get axes from spectral Joint domain
                k_axis = spectralJoint.axis{1};      % Lambda axis (wavenumber)
                omega_axis = spectralJoint.axis{2};  % Omega axis
                
                kmin = min(k_axis);
                kmax = max(k_axis);
                
                omega_min = min(omega_axis);
                omega_max = max(omega_axis);
                
                % Check Omega coordinate mode to determine if conversion needed
                omegaDomain = spectralJoint.B();  % Get Omega domain
                if omegaDomain.displayCoordinateMode == bct.enum.CoordinateMode.Frequency
                    % Omega.axis is already in Hz
                    freq_min = omega_min;
                    freq_max = omega_max;
                else
                    % Omega.axis is in rad/s, convert to Hz for display
                    freq_min = omega_min / (2*pi);
                    freq_max = omega_max / (2*pi);
                end
                
                % Get units from component domains
                k_units = spectralJoint.A_units();
                
            else
                % Fallback if Joint not available - use individual domains
                if ~isempty(B.Lambda) && ~isempty(B.Lambda.axis)
                    k_axis = B.Lambda.axis;
                    kmin = min(k_axis);
                    kmax = max(k_axis);
                    k_units = B.Lambda.units;
                else
                    kmin = 0;
                    kmax = 10;
                    k_units = '1/mm';
                end
                
                if ~isempty(B.Omega) && ~isempty(B.Omega.axis)
                    % Check Omega coordinate mode
                    if B.Omega.displayCoordinateMode == bct.enum.CoordinateMode.Frequency
                        % Omega.axis is already in Hz
                        freq_min = min(B.Omega.axis);
                        freq_max = max(B.Omega.axis);
                    else
                        % Omega.axis is in rad/s, convert to Hz
                        freq_min = min(B.Omega.axis) / (2*pi);
                        freq_max = max(B.Omega.axis) / (2*pi);
                    end
                elseif ~isempty(B.Time)
                    freq_min = 0;
                    freq_max = B.Time.fs / 2;  % Nyquist
                else
                    freq_min = 0;
                    freq_max = 25;
                end
            end
            
            % Set axes limits
            ax.XLim = [freq_min freq_max];  % frequency axis (Hz)
            ax.YLim = [kmin kmax];          % wavenumber axis
            
            % Set labels
            ax.XLabel.String = 'Frequency (Hz)';
            ax.YLabel.String = sprintf('Wavenumber k (%s)', k_units);
            
            % Set title
            ax.Title.String = 'Joint Spectral Domain (Lambda × Omega)';
            
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
            
            % Fill top 10 rows and all columns
            viewer.Layout.Row = [1 min(10, numRows)];
            viewer.Layout.Column = [1 numCols];
            
            drawnow;
        end
        
        %% Signal Processing
        
        function delta = createKronDelta(~, B)
            % Create Kronecker delta signal on Manifold_Time domain
            % Places impulse at center vertex and initial time
            
            if isempty(B.Joint) || ~strcmp(B.Joint.Domain, 'Manifold_Time')
                error('BctFilterDesigner:NoManifoldTime', ...
                    'Joint domain must be Manifold_Time to create delta signal.');
            end
            
            % Get domain dimensions
            nVertices = B.Manifold.N;
            nTime = B.Time.N;
            
            % Create zero data on Manifold_Time grid
            data = zeros(nVertices, nTime);
            
            % Place Kronecker delta at center vertex, first time point
            centerVertex = round(nVertices / 2);
            data(centerVertex, 1) = 1.0;
            
            % Create Signal object on Manifold_Time domain
            delta = bct.Signal(B.Joint, data);
            delta.Label = 'Kronecker Delta';
            
            fprintf('[createKronDelta] Delta created at vertex %d, time 1\n', centerVertex);
        end
        
        function ir = impulseResponse(app, B)
            % Compute impulse response by filtering KronDelta signal
            % Uses Bct orchestrator to handle Joint domain filtering
            % Workflow: Manifold_Time → Lambda_Omega → apply filter → Manifold_Time
            %
            % Returns:
            %   ir = bct.Signal on Manifold_Time domain (filtered impulse response)
            
            if isempty(app.KronDelta)
                error('BctFilterDesigner:NoDelta', 'KronDelta signal not created.');
            end
            
            if isempty(app.CurrentFilter)
                error('BctFilterDesigner:NoFilter', 'No filter available.');
            end
            
            % Use Bct orchestrator to apply filter
            % This handles:
            %   1. Forward transform: Manifold_Time → Lambda_Omega (via Joint.transform.forward)
            %   2. Apply filter: multiply by H in spectral domain
            %   3. Inverse transform: Lambda_Omega → Manifold_Time (via Joint.dual.transform.inverse)
            fprintf('[impulseResponse] Applying filter to delta signal...\n');
            ir = B.applyFilter(app.CurrentFilter, app.KronDelta);
            
            % Update label
            ir.Label = 'Impulse Response';
            
            fprintf('[impulseResponse] Impulse response computed [%d×%d]\n', size(ir.Data,1), size(ir.Data,2));
        end
        
        function visualizeFilterOnLambdaOmega(app, B, ax)
            % Visualize filter kernel evaluated on actual Lambda-Omega eigenmode grid
            % Shows which specific eigenmodes are being filtered
            %
            % Args:
            %   ax = handle to uiaxes (e.g., app.UIAxesResponse)
            
            if isempty(app.CurrentFilter)
                warning('BctFilterDesigner:NoFilter', 'No filter to visualize.');
                return;
            end
            
            % Get spectral Joint domain (Lambda × Omega)
            if strcmp(B.Joint.Domain, 'Manifold_Time')
                spectralJoint = B.Joint.dual;  % Lambda_Omega
            else
                spectralJoint = B.Joint;  % Already Lambda_Omega
            end
            
            % Evaluate filter on the ACTUAL Lambda-Omega grid (not preview grid)
            % This uses spectralJoint.A_grid and spectralJoint.B_grid (meshgrids)
            H = app.CurrentFilter.evaluate();
            
            % Get actual axes from spectral Joint domain
            k_axis = spectralJoint.axis{1};      % Lambda eigenvalues (wavenumber) [K×1]
            omega_axis = spectralJoint.axis{2};  % Omega frequencies (angular) [F×1]
            
            % Check domain coordinate mode for proper frequency display
            omegaDomain = spectralJoint.B();
            if isprop(omegaDomain, 'displayCoordinateMode') && ...
               omegaDomain.displayCoordinateMode == bct.enum.CoordinateMode.Frequency
                % Already in Hz
                freq_axis = omega_axis;
                freq_units = 'Hz';
            else
                % Convert from angular frequency (rad/s) to Hz
                freq_axis = omega_axis / (2*pi);
                freq_units = 'Hz';
            end
            
            % H is [K×F] from meshgrid evaluation: rows=lambda, cols=omega
            % For imagesc(ax, x, y, C): x goes horizontally (freq), y goes vertically (wavenumber)
            % C should be [length(y) × length(x)] = [K × F]
            cla(ax);
            imagesc(ax, freq_axis, k_axis, H);  % H is already [K×F]: freq on X, wavenumber on Y
            axis(ax, 'xy');
            
            xlabel(ax, sprintf('Frequency (%s)', freq_units));
            ylabel(ax, sprintf('Wavenumber k (%s)', spectralJoint.A_units()));
            title(ax, sprintf('Filter Response: %s [%d×%d]', app.CurrentFilter.Label, size(H,1), size(H,2)));
            
            colormap(ax, 'turbo');
            colorbar(ax);
            
            fprintf('[visualizeFilter] Filter evaluated on Lambda-Omega grid [%d×%d]\n', size(H,1), size(H,2));
        end
        
        %% Filter Design
        
        function createFilterFromKernelType(app, kernelType)
            % Create Joint filter based on selected kernel type from dropdown
            % This is called when user changes the KernelDropDown selection
            %
            % Inputs:
            %   kernelType - String from KernelDropDown: 'Gaussian', 'Heat', etc.
            
            B = app.CurrentBCT;
            
            % Ensure Joint domain exists
            if isempty(B.Joint)
                try
                    B = B.createJoint('Lambda', 'Omega');
                    app.CurrentBCT = B;
                catch ME
                    warning('BctBackend:CreateJoint', 'Could not create Joint domain: %s', ME.message);
                    return;
                end
            end
            
            % Get spectral Joint domain (Lambda × Omega)
            if strcmp(B.Joint.Domain, 'Manifold_Time')
                if isempty(B.Joint.dual)
                    warning('BctBackend:NoDual', 'Joint dual not available');
                    return;
                end
                spectralJoint = B.Joint.dual;  % Lambda_Omega
            else
                spectralJoint = B.Joint;  % Already Lambda_Omega
            end
            
            % Normalize kernel type string
            kernelType = lower(kernelType);
            kernelType = strrep(kernelType, ' ', '_');  % 'Velocity Gabor' -> 'velocity_gabor'
            
            % Get current slider values
            k0 = app.WavenumberSlider.Value;
            sigma_k = app.kbandwidthSlider.Value;
            omega0 = app.FrequencySlider.Value;
            sigma_o = app.BandwidthSlider.Value;
            
            % Get velocity if applicable
            v = app.VelocitySpinner.Value;
            
            % Create filter based on kernel type
            try
                switch kernelType
                    case 'velocity_gabor'
                        % Velocity-tuned traveling wave filter
                        lambda0 = k0;       % Center eigenvalue
                        sigma_l = sigma_k;  % Spatial bandwidth
                        sigma_w = sigma_o;  % Temporal bandwidth
                        omega_offset = omega0;  % Frequency offset
                        
                        app.CurrentFilter = bct.filters.Filter(spectralJoint, 'velocity_gabor', ...
                            'v', v, 'sigma_w', sigma_w, ...
                            'lambda0', lambda0, 'sigma_l', sigma_l, ...
                            'omega0', omega_offset, ...
                            'label', sprintf('Velocity Gabor (v=%.2f, λ0=%.1f, ω0=%.1f)', v, lambda0, omega_offset/(2*pi)));
                        
                    case 'gabor'
                        % 2D Gabor (localized wave packet)
                        app.CurrentFilter = bct.filters.Filter(spectralJoint, 'gabor', ...
                            'center_x', k0, 'sigma_x', sigma_k, ...
                            'center_y', omega0, 'sigma_y', sigma_o, ...
                            'label', sprintf('Gabor (k0=%.2f, ω0=%.1f Hz)', k0, omega0/(2*pi)));
                        
                    case 'gaussian'
                        % 2D Gaussian (smooth localization)
                        app.CurrentFilter = bct.filters.Filter(spectralJoint, 'gabor', ...
                            'center_x', k0, 'sigma_x', sigma_k, ...
                            'center_y', omega0, 'sigma_y', sigma_o, ...
                            'label', sprintf('Gaussian (k0=%.2f, ω0=%.1f Hz)', k0, omega0/(2*pi)));
                        
                    case 'heat'
                        % Heat diffusion kernel
                        tau = sigma_k;
                        app.CurrentFilter = bct.filters.Filter(spectralJoint, 'gabor', ...
                            'center_x', 0, 'sigma_x', 1/tau, ...
                            'center_y', omega0, 'sigma_y', sigma_o, ...
                            'label', sprintf('Heat (τ=%.2f, ω0=%.1f Hz)', tau, omega0/(2*pi)));
                        
                    case 'mexican_hat'
                        % Mexican hat wavelet
                        scale = sigma_k;
                        app.CurrentFilter = bct.filters.Filter(spectralJoint, 'gabor', ...
                            'center_x', k0, 'sigma_x', scale, ...
                            'center_y', omega0, 'sigma_y', sigma_o, ...
                            'label', sprintf('Mexican Hat (scale=%.2f, ω0=%.1f Hz)', scale, omega0/(2*pi)));
                        
                    otherwise
                        warning('BctBackend:UnknownKernel', 'Unknown kernel: %s, using Gabor', kernelType);
                        app.CurrentFilter = bct.filters.Filter(spectralJoint, 'gabor', ...
                            'center_x', k0, 'sigma_x', sigma_k, ...
                            'center_y', omega0, 'sigma_y', sigma_o, ...
                            'label', 'Joint Filter');
                end
                
                fprintf('[createFilterFromKernelType] Created %s filter\n', kernelType);
                
            catch ME
                warning('BctBackend:CreateFilter', 'Could not create filter: %s', ME.message);
                app.CurrentFilter = [];
            end
        end
        
        function updateVelocityParameter(app, velocity)
            % Update velocity parameter in current filter
            % Only applicable for velocity_gabor kernel
            
            if isempty(app.CurrentFilter)
                return;
            end
            
            % Check if current filter is velocity_gabor
            if strcmpi(app.CurrentFilter.KernelName, 'velocity_gabor')
                % Update velocity parameter
                app.CurrentFilter.setParameter('v', velocity);
                
                fprintf('[updateVelocityParameter] Updated velocity to %.4f\n', velocity);
            end
        end
        
        function createDefaultFilter(app)
            % Create default Joint filter (Lambda × Omega) with selected kernel type
            % Uses kernel type from KernelDropDown: Gaussian, Heat, Mexican Hat, Gabor, or Velocity Gabor
            % This is called on app startup or BCT load
            
            % Get kernel type from dropdown (defaults to 'Gaussian')
            kernelType = app.KernelDropDown.Value;
            
            % Delegate to createFilterFromKernelType
            BctBackend.createFilterFromKernelType(app, kernelType);
        end
        
        function updateKernelPreview(app)
            % Update kernel preview using Filter object's kernel function
            % Evaluates the filter's kernel on a smooth preview grid
            
            if isempty(app.CurrentFilter)
                return;  % No filter to preview
            end
            
            % Update filter parameters based on kernel type
            if strcmpi(app.CurrentFilter.KernelName, 'velocity_gabor')
                % Velocity gabor has different parameter names
                app.CurrentFilter.setParameter('lambda0', app.WavenumberSlider.Value);
                app.CurrentFilter.setParameter('sigma_l', app.kbandwidthSlider.Value);
                app.CurrentFilter.setParameter('sigma_w', app.BandwidthSlider.Value);
                app.CurrentFilter.setParameter('omega0', app.FrequencySlider.Value);
                app.CurrentFilter.setParameter('v', app.VelocitySpinner.Value);
            else
                % Standard gabor/gaussian parameters
                app.CurrentFilter.setParameter('center_x', app.WavenumberSlider.Value);
                app.CurrentFilter.setParameter('sigma_x', app.kbandwidthSlider.Value);
                app.CurrentFilter.setParameter('center_y', app.FrequencySlider.Value);
                app.CurrentFilter.setParameter('sigma_y', app.BandwidthSlider.Value);
            end
            
            ax = app.UIAxesKernel;
            
            % Use Joint domain axes directly (Lambda × Omega)
            B = app.CurrentBCT;
            
            if isempty(B.Joint)
                warning('BctBackend:NoJoint', 'Joint domain not available for kernel preview');
                return;
            end
            
            % Get the spectral Joint domain (Lambda × Omega)
            % If Joint is Manifold_Time, use its dual (Lambda_Omega)
            if strcmp(B.Joint.Domain, 'Manifold_Time')
                if isempty(B.Joint.dual)
                    warning('BctBackend:NoDual', 'Joint domain dual not available for kernel preview');
                    return;
                end
                spectralJoint = B.Joint.dual;  % Lambda_Omega
            else
                spectralJoint = B.Joint;  % Already Lambda_Omega
            end
            
            % Get axes from spectral Joint domain (Lambda × Omega)
            % New architecture: axis is a cell array {axis1, axis2}
            k_axis = spectralJoint.axis{1};      % Lambda axis (wavenumber)
            omega_axis = spectralJoint.axis{2};  % Omega axis (angular frequency)
            
            % Get component domains and their display properties
            domainA = spectralJoint.A();  % First component (Lambda)
            domainB = spectralJoint.B();  % Second component (Omega)
            
            % Get display coordinate mode and units
            k_units = domainA.units;
            omega_units = domainB.units;
            
            % Determine if we need to convert angular frequency to Hz
            if isprop(domainB, 'displayCoordinateMode')
                displayMode = domainB.displayCoordinateMode;
            else
                displayMode = 'AngularFrequency';  % Default for Omega
            end
            
            % Create fine grid for smooth visualization
            k = linspace(min(k_axis), max(k_axis), 200);
            w = linspace(min(omega_axis), max(omega_axis), 200);
            
            % Convert to display coordinates if needed
            if strcmp(displayMode, 'Frequency')
                % Already in Hz, no conversion needed
                f = w;
                freq_units = omega_units;  % Should be 'Hz'
            else
                % Convert from angular frequency (rad/s) to Hz
                f = w / (2*pi);
                freq_units = 'Hz';
            end
            
            [K, ~] = meshgrid(k, f);
            [~, W_grid] = meshgrid(k, w);
            
            % Evaluate using Filter's kernel function directly
            kernel_fh = app.CurrentFilter.KernelFunction;
            params = app.CurrentFilter.Parameters;
            
            % Call kernel function with appropriate parameters based on kernel type
            if strcmpi(app.CurrentFilter.KernelName, 'velocity_gabor')
                % velocity_gabor uses meshgrids like all other 2D joint kernels
                % Pass omega0 as optional parameter
                H = kernel_fh(K, W_grid, ...
                    params.v, params.sigma_w, ...
                    params.lambda0, params.sigma_l, ...
                    'omega0', params.omega0);
                titleStr = sprintf('Kernel: velocity_gabor | v=%.3f, \\lambda_0=%.3f, \\omega_0=%.1f', ...
                    params.v, params.lambda0, params.omega0/(2*pi));
            else
                % Standard gabor/gaussian parameters
                H = kernel_fh(K, W_grid, ...
                    params.center_x, params.center_y, ...
                    params.sigma_x, params.sigma_y);
                titleStr = sprintf('Kernel: %s | k_0=%.3f, \\sigma_k=%.3f', ...
                    app.CurrentFilter.KernelName, params.center_x, params.sigma_x);
            end
            
            % Plot with Frequency on X-axis, Wavenumber on Y-axis
            % H is [F×K] for both kernel types (from meshgrid structure)
            cla(ax);
            imagesc(ax, f, k, H');
            axis(ax, 'xy');
            
            % Set axis limits to match data ranges
            ax.XLim = [min(f) max(f)];
            ax.YLim = [min(k) max(k)];
            
            xlabel(ax, sprintf('Frequency (%s)', freq_units));
            ylabel(ax, sprintf('Wavenumber k (%s)', k_units));
            title(ax, titleStr);
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
        
        function stepSignal(app)
            % Advance impulse response signal by one time step
            % Each button press shows the next time point on the mesh viewer
            %
            % Args:
            %   app = BctFilterDesigner app handle
            %
            % Uses app.CurrentTimePoint to track position (initialize to 1 if needed)
            
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
            B.Viewer.Children.Color = bct.show.x2rgb(abs(dd), 'colormap', 'hot');
            drawnow;
            
            fprintf('[stepSignal] Time point: %d / %d\n', app.CurrentTimePoint, nTimePoints);
        end
        
        %% Wave Packet Generation (bct_wavepacket method - EXACT implementation)
        
        function packet = generateWavePacket(app, B)
            % bct_wavepacket - Generate traveling wave packet
            % EXACT implementation of the provided bct_wavepacket function
            % Sliders map to params struct
            
            % Build params struct from app sliders
            params = struct();
            params.lambda0_frac = app.WavenumberSlider.Value / max(B.Lambda.axis);
            params.sigma_l_frac = app.kbandwidthSlider.Value / (max(B.Lambda.axis) - min(B.Lambda.axis));
            params.omega0_frac = (app.FrequencySlider.Value * 2*pi) / (max(B.Time.fs*pi));
            params.sigma_w_frac = (app.BandwidthSlider.Value * 2*pi) / (max(B.Time.fs*pi));
            params.v = app.VelocitySpinner.Value;
            
            % Fixed source parameters (not controlled by sliders)
            params.lambda0_idx = floor(0.6 * B.Lambda.N);
            params.sigma_l_idx = 40;
            params.center_t = floor(B.Time.N/2);
            params.sigma_t = 8;
            params.f0 = 8;  % Hz
            
            % Apply defaults helper
            defaults.lambda0_idx   = floor(0.6 * B.Lambda.N);
            defaults.sigma_l_idx   = 40;
            defaults.center_t      = floor(B.Time.N/2);
            defaults.sigma_t       = 8;
            defaults.f0            = 8;
            defaults.v             = [];
            defaults.lambda0_frac  = 0.7;
            defaults.sigma_l_frac  = 0.15;
            defaults.omega0_frac   = 0.6;
            defaults.sigma_w_frac  = 0.2;
            
            params = applyDefaults(params, defaults);
            
            %% STEP 0 — Extract Axes
            t      = B.Time.axis;
            lambda = B.Lambda.axis;
            U      = B.Lambda.U;
            N      = B.Manifold.N;
            T      = B.Time.N;
            L      = length(lambda);
            
            %% STEP 0b — Correct FFT Angular Frequency Axis
            fs = B.Time.fs;
            freqs = (0:T-1)*(fs/T);
            freqs(T/2+1:end) = freqs(T/2+1:end) - fs;
            omega = 2*pi*freqs(:);
            
            %% STEP 1 — Spatial Gaussian
            gL = exp(-((1:L) - params.lambda0_idx).^2 / (2*params.sigma_l_idx^2));
            spatial_bump = U * gL.';
            
            %% STEP 2 — Temporal Gabor
            omega0_t = 2*pi*params.f0;
            temporal_bump = exp(-(t - t(params.center_t)).^2/(2*params.sigma_t^2)) .* ...
                            cos(omega0_t * t);
            temporal_bump = temporal_bump.';
            
            %% STEP 3 — Spatiotemporal source
            f = spatial_bump * temporal_bump;
            
            %% STEP 4 — λ transform, then FFT
            F_lambda        = U' * f;
            F_lambda_omega  = fft(F_lambda,[],2);
            
            %% STEP 5 — Velocity Kernel
            lambda0 = lambda(round(params.lambda0_frac * L));
            sigma_l = (lambda(end) - lambda(1)) * params.sigma_l_frac;
            omega0  = omega(round(params.omega0_frac * T));
            sigma_w = (max(omega)-min(omega)) * params.sigma_w_frac;
            
            if isempty(params.v)
                params.v = omega0 / sqrt(lambda0);
            end
            
            [LL, WW] = ndgrid(lambda, omega);
            
            velocityKernel = @(lambda,omega,v,lambda0,sigma_l,omega0,sigma_w) ...
                exp(-((omega - (omega0 + v.*sqrt(lambda))).^2)/(2*sigma_w^2)) .* ...
                exp(-((lambda - lambda0).^2)/(2*sigma_l^2));
            
            H = velocityKernel(LL, WW, params.v, lambda0, sigma_l, omega0, sigma_w);
            
            % Store for visualization
            omega_vis = fftshift(omega);
            H_vis     = fftshift(H,2);
            app.CurrentKernelFFT = H_vis;
            app.CurrentOmegaAxis = omega_vis;
            app.CurrentLambdaAxis = lambda;
            
            %% STEP 6 — Apply filter
            G_lambda_omega = F_lambda_omega .* H;
            G_lambda_time  = ifft(G_lambda_omega,[],2,'symmetric');
            
            %% STEP 7 — Reconstruct packet
            packet = U * G_lambda_time;
            
            fprintf('[generateWavePacket] Packet generated [%d×%d]\n', N, T);
        end
        
        function visualizeVelocityKernel(app, ax)
            % Visualize velocity kernel in Lambda-Omega space with correct FFT axes
            
            if isempty(app.CurrentKernelFFT)
                warning('BctBackend:NoKernel', 'No velocity kernel available. Run generateWavePacket first.');
                return;
            end
            
            % Convert omega to Hz for display
            freq_vis = app.CurrentOmegaAxis / (2*pi);
            
            cla(ax);
            imagesc(ax, freq_vis, app.CurrentLambdaAxis, app.CurrentKernelFFT);
            axis(ax, 'xy');
            
            xlabel(ax, '\omega (rad/s)');
            ylabel(ax, '\lambda');
            title(ax, 'Velocity Kernel H(\lambda,\omega)');
            
            colormap(ax, 'turbo');
            colorbar(ax);
        end
        
    end
end

%% Helper function for applyDefaults
function params = applyDefaults(params, defaults)
    fields = fieldnames(defaults);
    for i = 1:numel(fields)
        f = fields{i};
        if ~isfield(params, f) || isempty(params.(f))
            params.(f) = defaults.(f);
        end
    end
end
