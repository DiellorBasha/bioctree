classdef JointFilter < handle
    %JOINTFILTER Joint mesh-time spectral filter for spatiotemporal signals
    %
    %   Designs separable or joint filters on the mesh-time spectral grid:
    %       W(λ,t) = K(λ,t) * ψ_mesh(λ) * φ_time(t)
    %
    %   where:
    %     - ψ_mesh(λ): Spatial filter kernel (e.g., Mexican hat wavelet)
    %     - φ_time(t): Temporal filter kernel (e.g., Gabor wavelet)
    %     - K(λ,t): Dispersion relationship (optional, e.g., heat diffusion)
    %
    %   Workflow:
    %     1. Design: Create filter with spatial/temporal kernels
    %     2. Synthesize: Build spectral grid from Manifold and Time
    %     3. Apply: Filter spatiotemporal signals
    %
    %   Properties:
    %     Bct              - Associated bct object (contains Manifold, Time, SpectralGrid)
    %     psi_mesh         - Spatial kernel function handle @(lambda)
    %     phi_time         - Temporal kernel function handle @(t)
    %     K_dispersion     - Dispersion kernel function handle @(lambda, t) (optional)
    %     lambda_band      - Spatial frequency band [lambda_min, lambda_max]
    %     time_band        - Temporal band (e.g., [t_start, t_end] or [f_min, f_max])
    %     SpatialKernelType   - Type of spatial kernel ('mexican_hat', 'morlet', 'gabor', etc.)
    %     TemporalKernelType  - Type of temporal kernel ('gabor', 'morlet', 'gaussian', etc.)
    %     DispersionType      - Type of dispersion ('heat', 'wave', 'none')
    %     KernelParams        - Parameters for kernels (scales, frequencies, etc.)
    %
    %   Example:
    %     % Design diffusion-coupled Gabor filter
    %     filt = bct.filters.JointFilter(B);
    %     filt = bct.filters.design.diffusion(B, ...
    %         'lambda_band', [0, 5], ...
    %         'freq_band', [8, 12], ...  % Alpha band
    %         'sx', 2, 'st', 0.05, 'omega0', 10);
    %     
    %     % Synthesize on spectral grid
    %     filt.synthesize();
    %     
    %     % Evaluate joint kernel
    %     W = filt.evaluate();
    %
    %   See also: bct.filters.design.diffusion, bct.filters.design.wave,
    %             bct.bct.buildSpectralGrid, bct.filters.Filter
    
    properties
        Bct                           % bct object with Manifold, Time, SpectralGrid
        
        % Kernel function handles
        psi_mesh                      % Spatial kernel @(lambda) -> scalar/vector
        phi_time                      % Temporal kernel @(t) -> scalar/vector
        K_dispersion                  % Dispersion relationship @(lambda, t) -> scalar/matrix
        
        % Spectral bands
        lambda_band double = []       % [lambda_min, lambda_max]
        time_band double = []         % Temporal band (depends on band_type)
        band_type string = "freq"     % 'freq' for frequency, 'time' for time interval
        
        % Kernel metadata
        SpatialKernelType string = ""
        TemporalKernelType string = ""
        DispersionType string = "none"
        
        % Kernel parameters
        KernelParams struct = struct()
    end
    
    properties (SetAccess = private)
        % Synthesized filter on spectral grid
        W_lambda_t double = []        % Joint filter evaluated on SpectralGrid [numModes × T]
        lambda_vec double = []        % Eigenvalues from synthesis
        t_vec double = []             % Time vector from synthesis
    end
    
    methods
        %% Constructor
        function obj = JointFilter(bct_obj)
            %JOINTFILTER Construct joint mesh-time filter
            %
            %   filt = bct.filters.JointFilter(B) creates a joint filter
            %   for the given bct object
            %
            %   Inputs:
            %     bct_obj - bct.bct object with Manifold and Time
            
            if nargin < 1 || isempty(bct_obj)
                error('bct:filters:JointFilter:NoBct', ...
                    'Bct object required');
            end
            
            if ~isa(bct_obj, 'bct.bct')
                error('bct:filters:JointFilter:InvalidBct', ...
                    'Input must be a bct.bct object');
            end
            
            obj.Bct = bct_obj;
        end
        
        %% Design methods
        function setSpatialKernel(obj, kernel_type, varargin)
            %SETSPATIALKERNEL Set spatial filter kernel
            %
            %   filt.setSpatialKernel(type, 'param', value, ...)
            %
            %   Kernel types:
            %     'mexican_hat'  - Mexican hat wavelet
            %     'morlet'       - Morlet wavelet
            %     'gabor'        - Gabor filter
            %     'gaussian'     - Gaussian kernel
            %     'heat'         - Heat diffusion kernel
            %     'custom'       - Custom function handle
            %
            %   Parameters:
            %     'sx'       - Spatial scale parameter
            %     'lambda0'  - Center wavelength/eigenvalue
            %     'handle'   - Custom function handle (for 'custom' type)
            
            obj.SpatialKernelType = string(kernel_type);
            
            % Parse parameters
            p = inputParser;
            addParameter(p, 'sx', 1.0, @isnumeric);
            addParameter(p, 'lambda0', [], @isnumeric);
            addParameter(p, 'handle', [], @(x) isa(x, 'function_handle'));
            parse(p, varargin{:});
            
            sx = p.Results.sx;
            lambda0 = p.Results.lambda0;
            custom_handle = p.Results.handle;
            
            % Store parameters
            obj.KernelParams.sx = sx;
            if ~isempty(lambda0)
                obj.KernelParams.lambda0 = lambda0;
            end
            
            % Create kernel function
            switch obj.SpatialKernelType
                case "mexican_hat"
                    obj.psi_mesh = @(lambda) (1 - lambda/(sx^2)) .* exp(-lambda/(2*sx^2));
                    
                case "morlet"
                    obj.psi_mesh = @(lambda) exp(-lambda/(2*sx^2));
                    
                case "gabor"
                    if isempty(lambda0)
                        lambda0 = mean(obj.lambda_band);
                        obj.KernelParams.lambda0 = lambda0;
                    end
                    obj.psi_mesh = @(lambda) exp(-((lambda - lambda0).^2)/(2*sx^2));
                    
                case "gaussian"
                    obj.psi_mesh = @(lambda) exp(-lambda.^2/(2*sx^2));
                    
                case "heat"
                    obj.psi_mesh = @(lambda) exp(-sx * lambda);
                    
                case "custom"
                    if isempty(custom_handle)
                        error('bct:filters:JointFilter:NoCustomHandle', ...
                            'Custom kernel requires function handle');
                    end
                    obj.psi_mesh = custom_handle;
                    
                otherwise
                    error('bct:filters:JointFilter:UnknownSpatialKernel', ...
                        'Unknown spatial kernel type: %s', kernel_type);
            end
        end
        
        function setTemporalKernel(obj, kernel_type, varargin)
            %SETTEMPORALKERNEL Set temporal filter kernel
            %
            %   filt.setTemporalKernel(type, 'param', value, ...)
            %
            %   Kernel types:
            %     'gabor'      - Gabor wavelet (modulated Gaussian)
            %     'morlet'     - Morlet wavelet
            %     'gaussian'   - Gaussian envelope
            %     'cosine'     - Cosine with envelope
            %     'custom'     - Custom function handle
            %
            %   Parameters:
            %     'st'       - Temporal scale (width of envelope)
            %     'omega0'   - Center frequency (rad/s or Hz)
            %     'freq_hz'  - Center frequency in Hz (alternative to omega0)
            %     'handle'   - Custom function handle (for 'custom' type)
            
            obj.TemporalKernelType = string(kernel_type);
            
            % Parse parameters
            p = inputParser;
            addParameter(p, 'st', 0.1, @isnumeric);
            addParameter(p, 'omega0', 2*pi*10, @isnumeric);
            addParameter(p, 'freq_hz', [], @isnumeric);
            addParameter(p, 'handle', [], @(x) isa(x, 'function_handle'));
            parse(p, varargin{:});
            
            st = p.Results.st;
            omega0 = p.Results.omega0;
            freq_hz = p.Results.freq_hz;
            custom_handle = p.Results.handle;
            
            % Convert freq_hz to omega0 if provided
            if ~isempty(freq_hz)
                omega0 = 2*pi*freq_hz;
            end
            
            % Store parameters
            obj.KernelParams.st = st;
            obj.KernelParams.omega0 = omega0;
            
            % Create kernel function
            switch obj.TemporalKernelType
                case "gabor"
                    % Gabor: Gaussian envelope × cosine
                    obj.phi_time = @(t) exp(-(t.^2)/(st^2)) .* cos(omega0*t);
                    
                case "morlet"
                    % Morlet: Gaussian envelope × complex exponential (real part)
                    obj.phi_time = @(t) exp(-(t.^2)/(2*st^2)) .* cos(omega0*t);
                    
                case "gaussian"
                    % Pure Gaussian envelope
                    obj.phi_time = @(t) exp(-(t.^2)/(2*st^2));
                    
                case "cosine"
                    % Cosine with Gaussian envelope
                    obj.phi_time = @(t) exp(-(t.^2)/(st^2)) .* cos(omega0*t);
                    
                case "custom"
                    if isempty(custom_handle)
                        error('bct:filters:JointFilter:NoCustomHandle', ...
                            'Custom kernel requires function handle');
                    end
                    obj.phi_time = custom_handle;
                    
                otherwise
                    error('bct:filters:JointFilter:UnknownTemporalKernel', ...
                        'Unknown temporal kernel type: %s', kernel_type);
            end
        end
        
        function setDispersion(obj, dispersion_type, varargin)
            %SETDISPERSION Set dispersion relationship
            %
            %   filt.setDispersion(type, 'param', value, ...)
            %
            %   Dispersion types:
            %     'heat'     - Heat diffusion: exp(-t*λ)
            %     'wave'     - Wave propagation: exp(i*sqrt(λ)*t)
            %     'none'     - No dispersion (separable filter)
            %     'custom'   - Custom function handle @(lambda, t)
            %
            %   Parameters:
            %     'velocity' - Wave velocity (for 'wave' type)
            %     'handle'   - Custom function handle (for 'custom' type)
            
            obj.DispersionType = string(dispersion_type);
            
            % Parse parameters
            p = inputParser;
            addParameter(p, 'velocity', 1.0, @isnumeric);
            addParameter(p, 'handle', [], @(x) isa(x, 'function_handle'));
            parse(p, varargin{:});
            
            velocity = p.Results.velocity;
            custom_handle = p.Results.handle;
            
            % Store parameters
            obj.KernelParams.velocity = velocity;
            
            % Create dispersion function
            switch obj.DispersionType
                case "heat"
                    % Heat diffusion: K(λ,t) = exp(-t*λ)
                    obj.K_dispersion = @(lambda, t) exp(-t .* lambda);
                    
                case "wave"
                    % Wave propagation: K(λ,t) = exp(i*sqrt(λ)*t/v)
                    % Taking real part for visualization
                    obj.K_dispersion = @(lambda, t) cos(sqrt(lambda) .* t / velocity);
                    
                case "none"
                    % No dispersion - separable filter
                    obj.K_dispersion = [];
                    
                case "custom"
                    if isempty(custom_handle)
                        error('bct:filters:JointFilter:NoCustomHandle', ...
                            'Custom dispersion requires function handle');
                    end
                    obj.K_dispersion = custom_handle;
                    
                otherwise
                    error('bct:filters:JointFilter:UnknownDispersion', ...
                        'Unknown dispersion type: %s', dispersion_type);
            end
        end
        
        %% Synthesis methods
        function synthesize(obj, varargin)
            %SYNTHESIZE Build spectral grid and evaluate filter
            %
            %   filt.synthesize() builds the spectral grid using the
            %   specified lambda_band and evaluates the joint filter
            %
            %   filt.synthesize('numModes', n) specifies number of modes
            %
            %   This method:
            %     1. Calls Bct.buildSpectralGrid(lambda_band, opts)
            %     2. Retrieves lambda_grid and t_grid
            %     3. Evaluates W(λ,t) = K(λ,t) * ψ_mesh(λ) * φ_time(t)
            
            % Parse options
            p = inputParser;
            addParameter(p, 'numModes', min(200, obj.Bct.Manifold.N-1), @isnumeric);
            parse(p, varargin{:});
            
            numModes = p.Results.numModes;
            
            % Validate prerequisites
            if isempty(obj.psi_mesh)
                error('bct:filters:JointFilter:NoSpatialKernel', ...
                    'Spatial kernel not set. Use setSpatialKernel() first.');
            end
            
            if isempty(obj.phi_time)
                error('bct:filters:JointFilter:NoTemporalKernel', ...
                    'Temporal kernel not set. Use setTemporalKernel() first.');
            end
            
            if isempty(obj.lambda_band)
                error('bct:filters:JointFilter:NoLambdaBand', ...
                    'Lambda band not set.');
            end
            
            % Build spectral grid
            opts.numModes = numModes;
            obj.Bct.buildSpectralGrid(obj.lambda_band, opts);
            
            % Get grid components
            lambda_grid = obj.Bct.SpectralGrid.lambda_grid;  % [numModes × T]
            t_grid = obj.Bct.SpectralGrid.t_grid;            % [numModes × T]
            obj.lambda_vec = obj.Bct.SpectralGrid.lambda_band;
            obj.t_vec = obj.Bct.SpectralGrid.t;
            
            % Evaluate spatial kernel
            psi_vals = obj.psi_mesh(lambda_grid);  % [numModes × T] (broadcast)
            
            % Evaluate temporal kernel
            phi_vals = obj.phi_time(t_grid);       % [numModes × T] (broadcast)
            
            % Evaluate dispersion if present
            if ~isempty(obj.K_dispersion)
                K_vals = obj.K_dispersion(lambda_grid, t_grid);
                obj.W_lambda_t = K_vals .* psi_vals .* phi_vals;
            else
                % Separable filter (no dispersion)
                obj.W_lambda_t = psi_vals .* phi_vals;
            end
            
            fprintf('[bct.filters.JointFilter] Synthesized on %d modes × %d time points\n', ...
                size(obj.W_lambda_t, 1), size(obj.W_lambda_t, 2));
        end
        
        function W = evaluate(obj, lambda_query, t_query)
            %EVALUATE Evaluate joint filter at query points
            %
            %   W = filt.evaluate() returns synthesized filter on grid
            %   W = filt.evaluate(lambda, t) evaluates at query points
            %
            %   Returns:
            %     W - Joint filter values [numel(lambda) × numel(t)]
            
            if nargin < 2
                % Return synthesized filter
                if isempty(obj.W_lambda_t)
                    error('bct:filters:JointFilter:NotSynthesized', ...
                        'Filter not synthesized. Call synthesize() first.');
                end
                W = obj.W_lambda_t;
                return;
            end
            
            % Evaluate at query points
            if isempty(obj.psi_mesh) || isempty(obj.phi_time)
                error('bct:filters:JointFilter:NoKernels', ...
                    'Kernels not set.');
            end
            
            % Create grid from query points
            [lambda_grid, t_grid] = ndgrid(lambda_query(:), t_query(:));
            
            % Evaluate kernels
            psi_vals = obj.psi_mesh(lambda_grid);
            phi_vals = obj.phi_time(t_grid);
            
            if ~isempty(obj.K_dispersion)
                K_vals = obj.K_dispersion(lambda_grid, t_grid);
                W = K_vals .* psi_vals .* phi_vals;
            else
                W = psi_vals .* phi_vals;
            end
        end
        
        %% Analysis and visualization
        function plotJoint(obj)
            %PLOTJOINT Plot joint filter W(λ,t) as 2D image
            
            if isempty(obj.W_lambda_t)
                error('bct:filters:JointFilter:NotSynthesized', ...
                    'Filter not synthesized. Call synthesize() first.');
            end
            
            figure;
            imagesc(obj.t_vec, obj.lambda_vec, obj.W_lambda_t);
            axis xy;
            colorbar;
            xlabel('Time (s)');
            ylabel('Eigenvalue \lambda');
            title(sprintf('Joint Filter: %s (spatial) × %s (temporal)', ...
                obj.SpatialKernelType, obj.TemporalKernelType));
            
            if ~isempty(obj.DispersionType) && obj.DispersionType ~= "none"
                title(sprintf('Joint Filter with %s dispersion', obj.DispersionType));
            end
        end
        
        function plotMarginals(obj)
            %PLOTMARGINALS Plot spatial and temporal marginals
            
            if isempty(obj.W_lambda_t)
                error('bct:filters:JointFilter:NotSynthesized', ...
                    'Filter not synthesized. Call synthesize() first.');
            end
            
            figure;
            
            % Spatial marginal (integrate over time)
            subplot(2,1,1);
            spatial_marginal = mean(obj.W_lambda_t, 2);  % Average over time
            plot(obj.lambda_vec, spatial_marginal, 'LineWidth', 2);
            grid on;
            xlabel('Eigenvalue \lambda');
            ylabel('Spatial kernel \psi(\lambda)');
            title(sprintf('Spatial Kernel: %s', obj.SpatialKernelType));
            
            % Temporal marginal (integrate over space)
            subplot(2,1,2);
            temporal_marginal = mean(obj.W_lambda_t, 1);  % Average over lambda
            plot(obj.t_vec, temporal_marginal, 'LineWidth', 2);
            grid on;
            xlabel('Time (s)');
            ylabel('Temporal kernel \phi(t)');
            title(sprintf('Temporal Kernel: %s', obj.TemporalKernelType));
        end
        
        %% Display
        function disp(obj)
            fprintf('\n  <a href="matlab:helpPopup bct.filters.JointFilter">JointFilter</a> object:\n\n');
            
            fprintf('  Spatial Kernel:\n');
            if ~isempty(obj.SpatialKernelType)
                fprintf('    Type: %s\n', obj.SpatialKernelType);
                if isfield(obj.KernelParams, 'sx')
                    fprintf('    Scale sx: %.4g\n', obj.KernelParams.sx);
                end
            else
                fprintf('    Type: <not set>\n');
            end
            
            fprintf('\n  Temporal Kernel:\n');
            if ~isempty(obj.TemporalKernelType)
                fprintf('    Type: %s\n', obj.TemporalKernelType);
                if isfield(obj.KernelParams, 'st')
                    fprintf('    Scale st: %.4g\n', obj.KernelParams.st);
                end
                if isfield(obj.KernelParams, 'omega0')
                    fprintf('    Frequency ω₀: %.4g rad/s (%.2f Hz)\n', ...
                        obj.KernelParams.omega0, obj.KernelParams.omega0/(2*pi));
                end
            else
                fprintf('    Type: <not set>\n');
            end
            
            fprintf('\n  Dispersion:\n');
            fprintf('    Type: %s\n', obj.DispersionType);
            
            if ~isempty(obj.lambda_band)
                fprintf('\n  Lambda Band: [%.4g, %.4g]\n', obj.lambda_band(1), obj.lambda_band(2));
            end
            
            if ~isempty(obj.W_lambda_t)
                fprintf('\n  Synthesized Filter:\n');
                fprintf('    Grid size: %d modes × %d time points\n', ...
                    size(obj.W_lambda_t, 1), size(obj.W_lambda_t, 2));
                fprintf('    Value range: [%.4g, %.4g]\n', ...
                    min(obj.W_lambda_t(:)), max(obj.W_lambda_t(:)));
            else
                fprintf('\n  Filter: <not synthesized>\n');
            end
            
            fprintf('\n');
        end
    end
end
