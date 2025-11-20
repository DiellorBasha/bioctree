classdef Filter < handle
    %FILTER Spectral filter for graph/mesh signals
    %
    %   Designs filters as kernel functions g(λ) on the eigenvalue spectrum.
    %   Filters signals by: y_hat(λ) = g(λ) * x_hat(λ)
    %
    %   Filter Design → Filter Analysis → Filter Synthesis
    %
    %   Properties:
    %     Manifold       - Associated manifold object
    %     Resolution     - Associated resolution object (spatial/temporal)
    %     KernelType     - Type of filter kernel ('heat', 'band', 'ideal', etc.)
    %     KernelParams   - Parameters for kernel function
    %
    %   Workflow:
    %     1. Design: Create filter with kernel type and parameters
    %     2. Analysis: Inspect filter response g(λ)
    %     3. Synthesis: Apply filter to signals
    %
    %   Example:
    %     % Create bandpass filter for spatial wavelengths 5-50 mm
    %     filt = bct.filters.Filter(B.Manifold);
    %     filt.setBand([5, 50], bct.resolution.Quantity.wavelength);
    %     filt.design('band', 'taper', 'hann');
    %     
    %     % Analyze filter
    %     filt.plotResponse();
    %     modes = filt.getModeIndices();
    %     
    %     % Apply to signal (use bct.signal.transform)
    %     y = bct.signal.transform.filter(x, filt);
    %
    %   See also: bct.signal.transform, bct.resolution.spatial, bct.manifold.Manifold
    
    properties
        Manifold bct.manifold.Manifold      % Associated manifold
        Resolution                          % Resolution object (spatial or temporal)
        KernelType string = ""              % Kernel type: 'heat', 'band', 'ideal', 'mexican_hat', 'morlet'
        KernelParams struct = struct()      % Kernel-specific parameters
    end
    
    properties (SetAccess = private)
        % Spectral band (set via setBand or design methods)
        lambda_band double = []      % [lambda_low, lambda_high]
        
        % Designed filter response
        g_lambda double = []         % Filter kernel values at eigenvalues g(λ_k)
        lambda_support double = []   % Eigenvalue support (for plotting)
        g_support double = []        % Kernel values on support (for plotting)
    end
    
    methods
        %% Constructor
        function obj = Filter(manifold, resolution)
            %FILTER Construct spectral filter
            %
            %   filt = bct.filters.Filter(manifold) creates a filter
            %   for the given manifold
            %
            %   filt = bct.filters.Filter(manifold, resolution) also
            %   associates a resolution object for band specification
            %
            %   Inputs:
            %     manifold   - bct.manifold.Manifold object
            %     resolution - bct.resolution.spatial or temporal (optional)
            
            if nargin < 1 || isempty(manifold)
                error('bct:filters:Filter:NoManifold', 'Manifold required');
            end
            
            obj.Manifold = manifold;
            
            if nargin >= 2 && ~isempty(resolution)
                obj.Resolution = resolution;
            elseif manifold.Type == "mesh" && ~isempty(manifold.Resolution)
                obj.Resolution = manifold.Resolution;
            end
        end
        
        %% Design methods
        function setBand(obj, range, quantity)
            %SETBAND Set spectral band for filter
            %
            %   filt.setBand([low, high], quantity) sets the spectral
            %   band using the specified quantity type
            %
            %   Inputs:
            %     range    - [low, high] values
            %     quantity - bct.resolution.Quantity enum
            %
            %   Example:
            %     filt.setBand([5, 50], bct.resolution.Quantity.wavelength);
            %     filt.setBand([0.01, 0.5], bct.resolution.Quantity.lambda);
            
            if nargin < 3
                quantity = bct.resolution.Quantity.lambda;
            end
            
            % Convert to lambda range
            switch quantity
                case bct.resolution.Quantity.lambda
                    obj.lambda_band = range;
                    
                case bct.resolution.Quantity.wavelength
                    % L = 2π/sqrt(λ) → λ = (2π/L)^2
                    obj.lambda_band = [(2*pi/range(2))^2, (2*pi/range(1))^2];
                    
                case bct.resolution.Quantity.k
                    % k = sqrt(λ) → λ = k^2
                    obj.lambda_band = [range(1)^2, range(2)^2];
                    
                case bct.resolution.Quantity.freq
                    % f = sqrt(λ)/(2π) → λ = (2πf)^2
                    obj.lambda_band = [(2*pi*range(1))^2, (2*pi*range(2))^2];
                    
                case bct.resolution.Quantity.frequency
                    % Temporal frequency
                    obj.lambda_band = [(2*pi*range(1))^2, (2*pi*range(2))^2];
                    
                case bct.resolution.Quantity.period
                    % T = 1/f → f = 1/T → λ = (2π/T)^2
                    obj.lambda_band = [(2*pi/range(2))^2, (2*pi/range(1))^2];
            end
            
            % Update resolution band if available
            if ~isempty(obj.Resolution)
                try
                    obj.Resolution.setBand(range, quantity);
                catch
                    % Resolution object might not have setBand method
                end
            end
        end
        
        function design(obj, kernelType, varargin)
            %DESIGN Design filter kernel
            %
            %   filt.design(kernelType) designs a filter with the
            %   specified kernel type
            %
            %   filt.design(kernelType, 'param', value, ...) sets
            %   kernel-specific parameters
            %
            %   Kernel types:
            %     'ideal'       - Ideal bandpass (rectangular)
            %     'band'        - Bandpass with tapered edges
            %     'heat'        - Heat diffusion kernel
            %     'mexican_hat' - Mexican hat wavelet
            %     'morlet'      - Morlet wavelet
            %     'lowpass'     - Lowpass filter
            %     'highpass'    - Highpass filter
            %
            %   Parameters (kernel-dependent):
            %     'taper'       - Taper type: 'hann', 'hamming', 'tukey'
            %     'scale'       - Scale parameter for wavelets
            %     'time'        - Time parameter for heat kernel
            %     'order'       - Filter order
            %
            %   Example:
            %     filt.design('band', 'taper', 'hann');
            %     filt.design('heat', 'time', 0.1);
            %     filt.design('mexican_hat', 'scale', 5);
            
            obj.KernelType = string(kernelType);
            
            % Parse parameters
            p = inputParser;
            p.KeepUnmatched = true;
            addParameter(p, 'taper', 'hann', @ischar);
            addParameter(p, 'scale', 1.0, @isnumeric);
            addParameter(p, 'time', 0.1, @isnumeric);
            addParameter(p, 'order', 2, @isnumeric);
            parse(p, varargin{:});
            
            obj.KernelParams = p.Results;
            
            % Design kernel (eigenvalues not needed - only lambda_max from Resolution)
            obj.designKernel();
        end
        
        %% Analysis methods
        function modes = getModeIndices(obj)
            %GETMODEINDICES Get eigenmode indices in filter band
            %
            %   indices = filt.getModeIndices() returns the indices of
            %   eigenvalues that fall within the filter's spectral band
            
            if isempty(obj.lambda_band)
                error('bct:filters:Filter:NoBand', ...
                    'No spectral band set. Use setBand() first.');
            end
            
            if isempty(obj.Manifold.Eigenvalues)
                error('bct:filters:Filter:NoEigenvalues', ...
                    'No eigenvalues computed.');
            end
            
            lam = obj.Manifold.Eigenvalues;
            mask = (lam >= obj.lambda_band(1)) & (lam <= obj.lambda_band(2));
            modes = find(mask);
        end
        
        function response = getResponse(obj, lambda_query)
            %GETRESPONSE Evaluate filter response at query eigenvalues
            %
            %   g = filt.getResponse(lambda) evaluates the filter
            %   kernel g(λ) at the specified eigenvalues
            %
            %   Inputs:
            %     lambda - Query eigenvalues (optional)
            %
            %   Returns:
            %     g - Filter response values
            
            if nargin < 2 || isempty(lambda_query)
                % Return response at lambda_support points
                if ~isempty(obj.g_support)
                    response = obj.g_support;
                else
                    error('bct:filters:Filter:NoFilter', ...
                        'Filter not designed. Call design() first.');
                end
            else
                % Evaluate kernel at query points
                response = obj.evaluateKernel(lambda_query);
            end
        end
        
        function plotResponse(obj, varargin)
            %PLOTRESPONSE Plot filter frequency response
            %
            %   filt.plotResponse() plots g(λ) vs λ
            %
            %   filt.plotResponse('quantity', q) plots in terms of
            %   specified quantity (wavelength, freq, k, etc.)
            %
            %   Example:
            %     filt.plotResponse();
            %     filt.plotResponse('quantity', bct.resolution.Quantity.wavelength);
            
            if isempty(obj.g_support)
                error('bct:filters:Filter:NoFilter', ...
                    'Filter not designed. Call design() first.');
            end
            
            % Parse options
            p = inputParser;
            addParameter(p, 'quantity', bct.resolution.Quantity.lambda);
            parse(p, varargin{:});
            
            quantity = p.Results.quantity;
            
            % Convert lambda to desired quantity
            res = bct.resolution.spectral(obj.lambda_support);
            
            switch quantity
                case bct.resolution.Quantity.lambda
                    xdata = obj.lambda_support;
                    xlabel_str = '\lambda (eigenvalue)';
                case bct.resolution.Quantity.wavelength
                    xdata = res.L_min;
                    xlabel_str = 'Wavelength';
                case bct.resolution.Quantity.k
                    xdata = res.k_max;
                    xlabel_str = 'Wavenumber k (rad/unit)';
                case bct.resolution.Quantity.freq
                    xdata = res.f_max;
                    xlabel_str = 'Frequency f (cycles/unit)';
                otherwise
                    xdata = obj.lambda_support;
                    xlabel_str = '\lambda';
            end
            
            % Plot
            figure;
            plot(xdata, obj.g_support, 'LineWidth', 2);
            grid on;
            xlabel(xlabel_str);
            ylabel('Filter response g(\lambda)');
            title(sprintf('%s Filter Response', obj.KernelType));
            ylim([0, 1.1*max(obj.g_support)]);
        end
        
        %% Display
        function disp(obj)
            fprintf('\n  <a href="matlab:helpPopup bct.filters.Filter">Filter</a> object:\n\n');
            
            if ~isempty(obj.KernelType)
                fprintf('    Kernel Type: %s\n', obj.KernelType);
                
                % Display kernel parameters
                if ~isempty(fieldnames(obj.KernelParams))
                    fprintf('    Parameters:\n');
                    fn = fieldnames(obj.KernelParams);
                    for i = 1:length(fn)
                        val = obj.KernelParams.(fn{i});
                        if isnumeric(val)
                            fprintf('      %s: %.4g\n', fn{i}, val);
                        else
                            fprintf('      %s: %s\n', fn{i}, string(val));
                        end
                    end
                end
            else
                fprintf('    Kernel Type: <not designed>\n');
            end
            
            if ~isempty(obj.lambda_band)
                fprintf('\n  Spectral Band:\n');
                fprintf('    lambda: [%.4e, %.4e]\n', obj.lambda_band(1), obj.lambda_band(2));
                
                % Show in other quantities if resolution available
                if ~isempty(obj.Resolution)
                    try
                        res_low = bct.resolution.spectral(obj.lambda_band(1));
                        res_high = bct.resolution.spectral(obj.lambda_band(2));
                        fprintf('    Wavelength: [%.4f, %.4f]\n', res_high.L_min, res_low.L_min);
                        fprintf('    Frequency: [%.4f, %.4f] cycles/unit\n', res_low.f_max, res_high.f_max);
                    catch
                    end
                end
                
                % Show number of modes in band
                if ~isempty(obj.Manifold.Eigenvalues)
                    try
                        modes = obj.getModeIndices();
                        fprintf('    Modes in band: %d\n', length(modes));
                    catch
                    end
                end
            end
            
            fprintf('\n');
        end
    end
    
    %% Private methods
    methods (Access = private)
        function designKernel(obj)
            %DESIGNKERNEL Design filter kernel based on type
            %
            % For spatial filters, we only need lambda_max from Resolution
            % to define the filter function g(λ). The actual eigenvalues
            % will be used later during synthesis when SpectralGrid is built.
            
            % Get lambda range from Resolution (0 to lambda_max)
            if ~isempty(obj.Manifold.Resolution)
                lambda_max = obj.Manifold.Resolution.lambda_max;
                lambda_min = 0;
            elseif ~isempty(obj.Manifold.Eigenvalues)
                % Fallback: use actual eigenvalues if available
                lambda_min = min(obj.Manifold.Eigenvalues);
                lambda_max = max(obj.Manifold.Eigenvalues);
            else
                error('bct:filters:Filter:NoLambdaRange', ...
                    'Cannot determine lambda range. Manifold needs Resolution or computed eigenvalues.');
            end
            
            % Create smooth support for filter function definition
            obj.lambda_support = linspace(lambda_min, lambda_max, 1000)';
            
            % Design kernel using lambda_support (not actual eigenvalues)
            switch obj.KernelType
                case "ideal"
                    obj.g_support = obj.kernelIdeal(obj.lambda_support);
                    
                case "band"
                    obj.g_support = obj.kernelBand(obj.lambda_support);
                    
                case "heat"
                    obj.g_support = obj.kernelHeat(obj.lambda_support);
                    
                case "mexican_hat"
                    obj.g_support = obj.kernelMexicanHat(obj.lambda_support);
                    
                case "morlet"
                    obj.g_support = obj.kernelMorlet(obj.lambda_support);
                    
                case "lowpass"
                    obj.g_support = obj.kernelLowpass(obj.lambda_support);
                    
                case "highpass"
                    obj.g_support = obj.kernelHighpass(obj.lambda_support);
                    
                otherwise
                    error('bct:filters:Filter:UnknownKernel', ...
                        'Unknown kernel type: %s', obj.KernelType);
            end
            
            % Store g_lambda as empty - will be populated during synthesis
            % when actual eigenvalues are known
            obj.g_lambda = [];
        end
        
        function g = evaluateKernel(obj, lambda)
            %EVALUATEKERNEL Evaluate kernel at arbitrary lambda values
            
            switch obj.KernelType
                case "ideal"
                    g = obj.kernelIdeal(lambda);
                case "band"
                    g = obj.kernelBand(lambda);
                case "heat"
                    g = obj.kernelHeat(lambda);
                case "mexican_hat"
                    g = obj.kernelMexicanHat(lambda);
                case "morlet"
                    g = obj.kernelMorlet(lambda);
                case "lowpass"
                    g = obj.kernelLowpass(lambda);
                case "highpass"
                    g = obj.kernelHighpass(lambda);
                otherwise
                    g = zeros(size(lambda));
            end
        end
        
        %% Kernel functions
        function g = kernelIdeal(obj, lambda)
            %KERNELIDEAL Ideal bandpass filter (rectangular)
            if isempty(obj.lambda_band)
                error('bct:filters:Filter:NoBand', 'Set band with setBand() first');
            end
            g = double((lambda >= obj.lambda_band(1)) & (lambda <= obj.lambda_band(2)));
        end
        
        function g = kernelBand(obj, lambda)
            %KERNELBAND Bandpass with tapered edges
            if isempty(obj.lambda_band)
                error('bct:filters:Filter:NoBand', 'Set band with setBand() first');
            end
            
            lambda_low = obj.lambda_band(1);
            lambda_high = obj.lambda_band(2);
            
            % Taper width (10% of band)
            bandwidth = lambda_high - lambda_low;
            taper_width = 0.1 * bandwidth;
            
            g = zeros(size(lambda));
            
            % Passband
            passband = (lambda >= lambda_low + taper_width) & (lambda <= lambda_high - taper_width);
            g(passband) = 1;
            
            % Lower transition
            lower_trans = (lambda >= lambda_low) & (lambda < lambda_low + taper_width);
            if any(lower_trans)
                x = (lambda(lower_trans) - lambda_low) / taper_width;
                g(lower_trans) = obj.applyTaper(x, obj.KernelParams.taper);
            end
            
            % Upper transition
            upper_trans = (lambda > lambda_high - taper_width) & (lambda <= lambda_high);
            if any(upper_trans)
                x = (lambda_high - lambda(upper_trans)) / taper_width;
                g(upper_trans) = obj.applyTaper(x, obj.KernelParams.taper);
            end
        end
        
        function g = kernelHeat(obj, lambda)
            %KERNELHEAT Heat diffusion kernel: g(λ) = exp(-t*λ)
            t = obj.KernelParams.time;
            g = exp(-t * lambda);
        end
        
        function g = kernelMexicanHat(obj, lambda)
            %KERNELMEXICANHAT Mexican hat wavelet kernel
            s = obj.KernelParams.scale;
            g = (1 - lambda/(s^2)) .* exp(-lambda/(2*s^2));
            g = max(g, 0);  % Ensure non-negative
        end
        
        function g = kernelMorlet(obj, lambda)
            %KERNELMORLET Morlet wavelet kernel
            s = obj.KernelParams.scale;
            g = exp(-lambda/(2*s^2));
        end
        
        function g = kernelLowpass(obj, lambda)
            %KERNELLOWPASS Lowpass filter
            if ~isempty(obj.lambda_band)
                cutoff = obj.lambda_band(2);
            elseif ~isempty(obj.Manifold.Resolution)
                % Use half of lambda_max as default cutoff
                cutoff = obj.Manifold.Resolution.lambda_max / 2;
            elseif ~isempty(obj.Manifold.Eigenvalues)
                % Fallback: use median eigenvalue if available
                cutoff = median(obj.Manifold.Eigenvalues);
            else
                error('bct:filters:Filter:NoCutoff', ...
                    'Cannot determine lowpass cutoff. Set lambda_band or compute Resolution.');
            end
            
            % Smooth cutoff
            bandwidth = cutoff * 0.1;
            g = 0.5 * (1 - tanh((lambda - cutoff) / bandwidth));
        end
        
        function g = kernelHighpass(obj, lambda)
            %KERNELHIGHPASS Highpass filter
            if ~isempty(obj.lambda_band)
                cutoff = obj.lambda_band(1);
            elseif ~isempty(obj.Manifold.Resolution)
                % Use half of lambda_max as default cutoff
                cutoff = obj.Manifold.Resolution.lambda_max / 2;
            elseif ~isempty(obj.Manifold.Eigenvalues)
                % Fallback: use median eigenvalue if available
                cutoff = median(obj.Manifold.Eigenvalues);
            else
                error('bct:filters:Filter:NoCutoff', ...
                    'Cannot determine highpass cutoff. Set lambda_band or compute Resolution.');
            end
            
            % Smooth cutoff
            bandwidth = cutoff * 0.1;
            g = 0.5 * (1 + tanh((lambda - cutoff) / bandwidth));
        end
        
        function y = applyTaper(~, x, taper_type)
            %APPLYTAPER Apply taper function to transition region
            switch string(taper_type)
                case "hann"
                    y = 0.5 * (1 - cos(pi * x));
                case "hamming"
                    y = 0.54 - 0.46 * cos(pi * x);
                case "tukey"
                    y = 0.5 * (1 + cos(pi * (1 - x)));
                otherwise
                    y = x;  % Linear
            end
        end
    end
end
