classdef Axis < handle
    %AXIS Unified axis management for Bct workflows
    %
    %   The Axis class provides a centralized interface for creating and
    %   managing different axis types used throughout the Bct framework,
    %   including temporal, spatial, spectral, and joint axes.
    %
    %   Properties:
    %       Type        - Axis type: 'Time', 'Vertex', 'Lambda', 'Frequency', etc.
    %       Values      - Axis values (vector or meshgrid for joint axes)
    %       Label       - Axis label for plotting
    %       Units       - Physical units (e.g., 's', 'Hz', 'rad/s')
    %       N           - Number of points
    %       Range       - [min, max] range
    %
    %   Methods:
    %       Axis.time(time_obj)                    - Create time axis (seconds)
    %       Axis.vertex(manifold)                  - Create vertex index axis
    %       Axis.lambda(spatial_res)               - Create eigenvalue axis
    %       Axis.frequency(temporal_res)           - Create frequency axis (Hz)
    %       Axis.omega(temporal_res)               - Create angular frequency (rad/s)
    %       Axis.wavenumber(spatial_res)           - Create wavenumber axis
    %       Axis.wavelength(spatial_res)           - Create wavelength axis
    %       Axis.scale(spatial_res)                - Create spatial scale axis
    %       Axis.joint(axis1, axis2)               - Create joint 2D axis
    %
    %   Example - Temporal axis:
    %       ax_t = bct.resolution.Axis.time(B.Time);
    %       plot(ax_t.Values, signal);
    %       xlabel(ax_t.Label);
    %
    %   Example - Spectral axis:
    %       ax_lambda = bct.resolution.Axis.lambda(B.Manifold.Resolution);
    %       plot(ax_lambda.Values, eigenvalues);
    %
    %   Example - Joint axis:
    %       ax_lambda = bct.resolution.Axis.lambda(B.Manifold.Resolution);
    %       ax_freq = bct.resolution.Axis.frequency(B.Time.Resolution);
    %       ax_joint = bct.resolution.Axis.joint(ax_lambda, ax_freq);
    %       surf(ax_joint.Values{1}, ax_joint.Values{2}, power_spectrum);
    %
    %   See also: bct.resolution.spatial, bct.resolution.spectral,
    %             bct.resolution.temporal
    
    properties
        Type string = ""           % Axis type identifier
        Values                     % Axis values (vector or cell of meshgrids)
        Label string = ""          % Axis label for plotting
        Units string = ""          % Physical units
        N double = 0               % Number of points
        Range double = []          % [min, max]
        IsJoint logical = false    % True for joint 2D axes
    end
    
    methods
        function obj = Axis(type, values, label, units)
            %AXIS Construct an Axis object
            %
            %   ax = Axis(type, values, label, units)
            
            if nargin > 0
                obj.Type = string(type);
                obj.Values = values;
                
                if ~iscell(values)
                    obj.N = length(values);
                    obj.Range = [min(values), max(values)];
                else
                    obj.IsJoint = true;
                    obj.N = [size(values{1}, 1), size(values{1}, 2)];
                    obj.Range = {[min(values{1}(:)), max(values{1}(:))], ...
                                 [min(values{2}(:)), max(values{2}(:))]};
                end
                
                if nargin >= 3
                    obj.Label = string(label);
                end
                
                if nargin >= 4
                    obj.Units = string(units);
                end
            end
        end
    end
    
    methods (Static)
        function ax = time(time_obj)
            %TIME Create temporal axis in seconds
            %
            %   ax = Axis.time(time_obj) creates a time axis from bct.manifold.Time
            %
            %   Inputs:
            %     time_obj - bct.manifold.Time object
            %
            %   Returns:
            %     ax - Axis object with time values in seconds
            
            if ~isa(time_obj, 'bct.manifold.Time')
                error('bct:resolution:Axis:InvalidInput', ...
                    'Input must be a bct.manifold.Time object');
            end
            
            t = time_obj.t;  % Time vector in seconds
            ax = bct.resolution.Axis('Time', t, 'Time', 's');
        end
        
        function ax = vertex(manifold)
            %VERTEX Create vertex index axis
            %
            %   ax = Axis.vertex(manifold) creates vertex index axis 1:N
            %
            %   Inputs:
            %     manifold - bct.manifold.Manifold object
            %
            %   Returns:
            %     ax - Axis object with vertex indices
            
            if ~isa(manifold, 'bct.manifold.Manifold')
                error('bct:resolution:Axis:InvalidInput', ...
                    'Input must be a bct.manifold.Manifold object');
            end
            
            v = (1:manifold.N)';  % Vertex indices
            ax = bct.resolution.Axis('Vertex', v, 'Vertex Index', '');
        end
        
        function ax = lambda(spatial_res, varargin)
            %LAMBDA Create eigenvalue axis
            %
            %   ax = Axis.lambda(spatial_res) creates eigenvalue axis 0 to lambda_max
            %   ax = Axis.lambda(spatial_res, 'N', n) uses n points (default: 1000)
            %
            %   Inputs:
            %     spatial_res - bct.resolution.spatial object
            %     'N'         - Number of points (default: 1000)
            %
            %   Returns:
            %     ax - Axis object with eigenvalue values
            
            if ~isa(spatial_res, 'bct.resolution.spatial')
                error('bct:resolution:Axis:InvalidInput', ...
                    'Input must be a bct.resolution.spatial object');
            end
            
            p = inputParser;
            addParameter(p, 'N', 1000, @isnumeric);
            parse(p, varargin{:});
            
            lambda_max = spatial_res.lambda_max;
            lambda_vals = linspace(0, lambda_max, p.Results.N)';
            
            ax = bct.resolution.Axis('Lambda', lambda_vals, '\lambda (eigenvalue)', '');
        end
        
        function ax = frequency(temporal_res, varargin)
            %FREQUENCY Create frequency axis in Hz (positive frequencies)
            %
            %   ax = Axis.frequency(temporal_res) creates frequency axis
            %   ax = Axis.frequency(time_obj) creates from Time object
            %
            %   Inputs:
            %     temporal_res - bct.resolution.temporal or bct.manifold.Time object
            %
            %   Returns:
            %     ax - Axis object with positive frequencies in Hz
            
            if isa(temporal_res, 'bct.manifold.Time')
                % Extract Resolution from Time object
                if isempty(temporal_res.Resolution)
                    error('bct:resolution:Axis:NoResolution', ...
                        'Time object has no Resolution. Call setResolution() first.');
                end
                temporal_res = temporal_res.Resolution;
            end
            
            if ~isa(temporal_res, 'bct.resolution.temporal')
                error('bct:resolution:Axis:InvalidInput', ...
                    'Input must be a bct.resolution.temporal or bct.manifold.Time object');
            end
            
            % Positive frequencies: 0 to Nyquist
            f = temporal_res.f_pos;  % Positive frequencies
            ax = bct.resolution.Axis('Frequency', f, 'Frequency', 'Hz');
        end
        
        function ax = omega(temporal_res)
            %OMEGA Create angular frequency axis in rad/s
            %
            %   ax = Axis.omega(temporal_res) creates angular frequency axis
            %   ax = Axis.omega(time_obj) creates from Time object
            %
            %   Inputs:
            %     temporal_res - bct.resolution.temporal or bct.manifold.Time object
            %
            %   Returns:
            %     ax - Axis object with angular frequencies in rad/s
            
            if isa(temporal_res, 'bct.manifold.Time')
                if isempty(temporal_res.Resolution)
                    error('bct:resolution:Axis:NoResolution', ...
                        'Time object has no Resolution. Call setResolution() first.');
                end
                temporal_res = temporal_res.Resolution;
            end
            
            if ~isa(temporal_res, 'bct.resolution.temporal')
                error('bct:resolution:Axis:InvalidInput', ...
                    'Input must be a bct.resolution.temporal or bct.manifold.Time object');
            end
            
            % Angular frequency: omega = 2*pi*f
            f = temporal_res.f_pos;
            omega_vals = 2 * pi * f;
            
            ax = bct.resolution.Axis('Omega', omega_vals, '\omega (angular frequency)', 'rad/s');
        end
        
        function ax = wavenumber(spatial_res, varargin)
            %WAVENUMBER Create wavenumber axis
            %
            %   ax = Axis.wavenumber(spatial_res) creates wavenumber axis
            %   ax = Axis.wavenumber(spatial_res, 'N', n) uses n points
            %
            %   Relation: k = sqrt(lambda)
            %
            %   Inputs:
            %     spatial_res - bct.resolution.spatial object
            %     'N'         - Number of points (default: 1000)
            %
            %   Returns:
            %     ax - Axis object with wavenumber values
            
            if ~isa(spatial_res, 'bct.resolution.spatial')
                error('bct:resolution:Axis:InvalidInput', ...
                    'Input must be a bct.resolution.spatial object');
            end
            
            p = inputParser;
            addParameter(p, 'N', 1000, @isnumeric);
            parse(p, varargin{:});
            
            lambda_max = spatial_res.lambda_max;
            k_max = sqrt(lambda_max);
            k_vals = linspace(0, k_max, p.Results.N)';
            
            ax = bct.resolution.Axis('Wavenumber', k_vals, 'k (wavenumber)', 'rad/unit');
        end
        
        function ax = wavelength(spatial_res, varargin)
            %WAVELENGTH Create wavelength axis
            %
            %   ax = Axis.wavelength(spatial_res) creates wavelength axis
            %   ax = Axis.wavelength(spatial_res, 'N', n) uses n points
            %
            %   Relation: wavelength = 2*pi / k = 2*pi / sqrt(lambda)
            %
            %   Inputs:
            %     spatial_res - bct.resolution.spatial object
            %     'N'         - Number of points (default: 1000)
            %
            %   Returns:
            %     ax - Axis object with wavelength values (decreasing order)
            
            if ~isa(spatial_res, 'bct.resolution.spatial')
                error('bct:resolution:Axis:InvalidInput', ...
                    'Input must be a bct.resolution.spatial object');
            end
            
            p = inputParser;
            addParameter(p, 'N', 1000, @isnumeric);
            parse(p, varargin{:});
            
            lambda_max = spatial_res.lambda_max;
            k_min = sqrt(eps);  % Avoid division by zero
            k_max = sqrt(lambda_max);
            
            % Generate k values and convert to wavelength
            k_vals = linspace(k_min, k_max, p.Results.N);
            L_vals = 2 * pi ./ k_vals;
            
            % Reverse to get decreasing wavelength (increasing spatial frequency)
            L_vals = flip(L_vals)';
            
            ax = bct.resolution.Axis('Wavelength', L_vals, 'L (wavelength)', 'units');
        end
        
        function ax = scale(spatial_res, varargin)
            %SCALE Create spatial scale axis (inverse sqrt of lambda)
            %
            %   ax = Axis.scale(spatial_res) creates spatial scale axis
            %   ax = Axis.scale(spatial_res, 'N', n) uses n points
            %
            %   Relation: scale = 1 / sqrt(lambda)
            %   Useful for graph wavelets, scale-space, diffusion maps
            %
            %   Inputs:
            %     spatial_res - bct.resolution.spatial object
            %     'N'         - Number of points (default: 1000)
            %
            %   Returns:
            %     ax - Axis object with spatial scale values (decreasing)
            
            if ~isa(spatial_res, 'bct.resolution.spatial')
                error('bct:resolution:Axis:InvalidInput', ...
                    'Input must be a bct.resolution.spatial object');
            end
            
            p = inputParser;
            addParameter(p, 'N', 1000, @isnumeric);
            parse(p, varargin{:});
            
            lambda_max = spatial_res.lambda_max;
            lambda_min = max(eps, 1e-6);  % Avoid division by zero
            
            % Generate lambda values and convert to scale
            lambda_vals = linspace(lambda_min, lambda_max, p.Results.N);
            scale_vals = 1 ./ sqrt(lambda_vals);
            
            % Reverse to get decreasing scale (increasing lambda)
            scale_vals = flip(scale_vals)';
            
            ax = bct.resolution.Axis('Scale', scale_vals, 's (spatial scale)', 'units');
        end
        
        function ax = joint(axis1, axis2)
            %JOINT Create joint 2D axis from two 1D axes
            %
            %   ax = Axis.joint(ax1, ax2) creates 2D meshgrid from two axes
            %
            %   Common combinations:
            %     - Lambda × Frequency: [LAMBDA, FREQ] = meshgrid(lambda, f)
            %     - Lambda × Omega: [LAMBDA, OMEGA] = meshgrid(lambda, omega)
            %     - Lambda × Time: [LAMBDA, TIME] = meshgrid(lambda, t)
            %
            %   Inputs:
            %     axis1 - First Axis object (typically spatial/spectral)
            %     axis2 - Second Axis object (typically temporal)
            %
            %   Returns:
            %     ax - Joint Axis object with Values = {GRID1, GRID2}
            %
            %   Example:
            %       ax_lambda = bct.resolution.Axis.lambda(B.Manifold.Resolution);
            %       ax_freq = bct.resolution.Axis.frequency(B.Time);
            %       ax_joint = bct.resolution.Axis.joint(ax_lambda, ax_freq);
            %       
            %       % Use for plotting
            %       surf(ax_joint.Values{1}, ax_joint.Values{2}, spectrum);
            %       xlabel(ax_joint.Label{1});
            %       ylabel(ax_joint.Label{2});
            
            if ~isa(axis1, 'bct.resolution.Axis') || ~isa(axis2, 'bct.resolution.Axis')
                error('bct:resolution:Axis:InvalidInput', ...
                    'Both inputs must be Axis objects');
            end
            
            if axis1.IsJoint || axis2.IsJoint
                error('bct:resolution:Axis:AlreadyJoint', ...
                    'Cannot create joint axis from already-joint axes');
            end
            
            % Create meshgrid: [AXIS1_GRID, AXIS2_GRID] = meshgrid(axis1, axis2)
            [GRID1, GRID2] = meshgrid(axis1.Values, axis2.Values);
            
            % Store as cell array
            values_joint = {GRID1, GRID2};
            
            % Create joint type name
            type_joint = sprintf('%s×%s', axis1.Type, axis2.Type);
            
            % Create joint labels
            label_joint = {axis1.Label, axis2.Label};
            units_joint = {axis1.Units, axis2.Units};
            
            % Construct joint axis
            ax = bct.resolution.Axis(type_joint, values_joint, label_joint, units_joint);
            ax.IsJoint = true;
        end
    end
    
    methods
        function disp(obj)
            %DISP Display Axis information
            
            if obj.IsJoint
                fprintf('  Joint Axis: %s\n', obj.Type);
                fprintf('    Grid Size: [%d × %d]\n', obj.N(1), obj.N(2));
                fprintf('    Axis 1: %s [%s]\n', obj.Label{1}, obj.Units{1});
                fprintf('      Range: [%.4g, %.4g]\n', obj.Range{1}(1), obj.Range{1}(2));
                fprintf('    Axis 2: %s [%s]\n', obj.Label{2}, obj.Units{2});
                fprintf('      Range: [%.4g, %.4g]\n', obj.Range{2}(1), obj.Range{2}(2));
            else
                fprintf('  Axis: %s\n', obj.Type);
                fprintf('    Label: %s [%s]\n', obj.Label, obj.Units);
                fprintf('    N: %d points\n', obj.N);
                fprintf('    Range: [%.4g, %.4g]\n', obj.Range(1), obj.Range(2));
            end
        end
    end
end
