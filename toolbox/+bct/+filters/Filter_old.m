classdef Filter < handle
    %FILTER Spectral filter with function handle kernel
    %
    %   The Filter class represents a spectral filter defined by a function
    %   handle. Supports five filter types corresponding to bct.filters.design
    %   package structure:
    %
    %   Filter Types:
    %     'Manifold'  - H(λ) spatial spectral filter
    %     'Time'      - H(ω) or H(f) temporal filter
    %     'Separable' - H(λ,ω) = Hλ(λ) * Hω(ω) separable joint filter
    %     'Spectral'  - H(λ,ω) non-separable joint spectral filter
    %     'Dynamic'   - K(λ,t) dynamic propagator in time domain
    %
    %   Properties:
    %       Type          - Filter type (see above)
    %       g             - Filter kernel function handle
    %       lambda_band   - [lambda_min, lambda_max] for Manifold filters
    %       freq_band     - [f_min, f_max] for Time filters (Hz)
    %       KernelType    - Kernel name (e.g., 'heat', 'gaussian', 'wave')
    %       KernelParams  - Structure with kernel parameters
    %       Manifold      - Reference to bct.manifold.Manifold
    %       Time          - Reference to bct.manifold.Time
    %
    %   Methods:
    %       Filter(type)           - Constructor
    %       setKernel(g, params)   - Set filter kernel function
    %       getResponse(x)         - Evaluate filter at query points
    %       plotResponse()         - Plot filter response
    %
    %   Example - Manifold filter:
    %       filt = bct.filters.Filter('Manifold');
    %       filt.Manifold = B.Manifold;
    %       filt.g = bct.filters.design.manifold.heat(B.Manifold, 'tau', 0.1);
    %
    %   Example - Separable filter:
    %       filt = bct.filters.Filter('Separable');
    %       Hlambda = bct.filters.design.manifold.gaussian(B.Manifold, 'sigma', 100);
    %       Homega = bct.filters.design.time.gabor('omega0', 2*pi*10);
    %       filt.g = bct.filters.design.joint.separable.spatial_temporal(Hlambda, Homega);
    %
    %   Example - Dynamic filter:
    %       filt = bct.filters.Filter('Dynamic');
    %       filt.g = bct.filters.design.joint.dynamic.wave(B.Manifold, 'c', 1);
    %
    %   See also: bct.filters.design.manifold, bct.filters.design.time,
    %             bct.filters.design.joint.separable, bct.filters.design.joint.spectral,
    %             bct.filters.design.joint.dynamic
    
    properties
        Type string = ""              % Filter type
        g                             % Filter kernel function handle
        lambda_band double = []       % [lambda_min, lambda_max]
        freq_band double = []         % [f_min, f_max] in Hz
        KernelType string = ""        % Kernel name
        KernelParams struct = struct() % Kernel parameters
        Manifold                      % bct.manifold.Manifold reference
        Time                          % bct.manifold.Time reference
    end
    
    methods
        function obj = Filter(filter_type)
            %FILTER Construct a Filter object
            %
            %   filt = Filter(type) creates a filter of specified type
            %
            %   Inputs:
            %     type - 'Manifold', 'Time', 'Separable', 'Spectral', or 'Dynamic'
            
            if nargin > 0
                obj.Type = string(filter_type);
                
                % Validate type
                valid_types = ["Manifold", "Time", "Separable", "Spectral", "Dynamic"];
                if ~ismember(obj.Type, valid_types)
                    error('bct:filters:Filter:InvalidType', ...
                        ['Type must be one of: ', strjoin(valid_types, ', ')]);
                end
            end
        end
        
        function setKernel(obj, kernel_handle, kernel_type, params)
            %SETKERNEL Set filter kernel function
            %
            %   filt.setKernel(g, type, params) sets the kernel function
            %
            %   Inputs:
            %     g      - Function handle @(x) or @(lambda,t)
            %     type   - Kernel name string
            %     params - Struct with kernel parameters
            
            if ~isa(kernel_handle, 'function_handle')
                error('bct:filters:Filter:InvalidKernel', ...
                    'Kernel must be a function handle');
            end
            
            obj.g = kernel_handle;
            
            if nargin >= 3
                obj.KernelType = string(kernel_type);
            end
            
            if nargin >= 4
                obj.KernelParams = params;
            end
        end
        
        function response = getResponse(obj, x)
            %GETRESPONSE Evaluate filter at query points
            %
            %   g = filt.getResponse(x) evaluates the filter kernel
            %
            %   Inputs:
            %     x - Query points (eigenvalues or frequencies)
            %
            %   Returns:
            %     g - Filter response values
            
            if isempty(obj.g)
                error('bct:filters:Filter:NoKernel', ...
                    'No kernel set. Use setKernel() or design.* functions.');
            end
            
            response = obj.g(x);
        end
        
        function plotResponse(obj, varargin)
            %PLOTRESPONSE Plot filter frequency response
            %
            %   filt.plotResponse() plots the filter response
            %   filt.plotResponse('N', n) uses n points for plotting
            
            if isempty(obj.g)
                error('bct:filters:Filter:NoKernel', 'No kernel set.');
            end
            
            p = inputParser;
            addParameter(p, 'N', 1000, @isnumeric);
            parse(p, varargin{:});
            N = p.Results.N;
            
            % Determine x-axis range based on filter type
            if obj.Type == "Manifold"
                if ~isempty(obj.Manifold) && ~isempty(obj.Manifold.Resolution)
                    x_max = obj.Manifold.Resolution.lambda_max;
                elseif ~isempty(obj.lambda_band)
                    x_max = obj.lambda_band(2) * 1.5;
                else
                    x_max = 1000;
                end
                x = linspace(0, x_max, N);
                xlabel_str = '\lambda (eigenvalue)';
                title_str = sprintf('Manifold Filter: %s', obj.KernelType);
                
            elseif obj.Type == "Time"
                % Time filters use OMEGA (rad/s) axis
                if ~isempty(obj.Time) && ~isempty(obj.Time.Resolution)
                    omega_max = 2 * pi * obj.Time.fs / 2;  % Nyquist in rad/s
                elseif ~isempty(obj.freq_band)
                    omega_max = 2 * pi * obj.freq_band(2) * 1.5;
                else
                    omega_max = 2 * pi * 100;  % Default 100 Hz
                end
                x = linspace(0, omega_max, N);
                xlabel_str = '\omega (rad/s)';
                title_str = sprintf('Temporal Filter: %s', obj.KernelType);
                
            else  % Separable, Spectral, or Dynamic
                error('bct:filters:Filter:CannotPlot', ...
                    'Plotting for Separable/Spectral/Dynamic filters requires 2D visualization. Use custom plotting code.');
            end
            
            % Evaluate filter
            g_vals = obj.getResponse(x);
            
            % Plot
            figure;
            plot(x, g_vals, 'LineWidth', 2);
            xlabel(xlabel_str);
            ylabel('g(x)');
            title(title_str);
            grid on;
            ylim([0, max(g_vals)*1.1]);
        end
        
        function modes = getModeIndices(obj)
            %GETMODEINDICES Get eigenmode indices in filter band
            %
            %   indices = filt.getModeIndices() returns the indices of
            %   eigenvalues that fall within the filter's spectral band
            
            if obj.Type ~= "Manifold"
                error('bct:filters:Filter:NotManifold', ...
                    'getModeIndices only works for Manifold filters');
            end
            
            if isempty(obj.lambda_band)
                error('bct:filters:Filter:NoBand', ...
                    'No spectral band set.');
            end
            
            if isempty(obj.Manifold) || isempty(obj.Manifold.Eigenvalues)
                error('bct:filters:Filter:NoEigenvalues', ...
                    'No eigenvalues computed.');
            end
            
            lam = obj.Manifold.Eigenvalues;
            mask = (lam >= obj.lambda_band(1)) & (lam <= obj.lambda_band(2));
            modes = find(mask);
        end
    end
end
