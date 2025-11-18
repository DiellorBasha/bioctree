classdef spatial < handle
    %SPATIAL Spatial resolution manager for mesh manifolds
    %
    %   Manages spatial resolution information including:
    %   - Mesh theoretical resolution (from Laplacian eigenspectrum)
    %   - Instrument-limited resolution (e.g., MEG spatial resolution)
    %   - Current spatial band selection
    %   - Mode selectors and patch size helpers
    %
    %   Properties:
    %     Units          - Spatial units (bct.resolution.Units)
    %     Manifold       - Associated manifold object
    %
    %   Mesh Theoretical Resolution:
    %     lambda_max     - Maximum eigenvalue [1/units^2]
    %     f_max          - Maximum spatial frequency [cycles/units]
    %     L_min          - Minimum wavelength [units]
    %
    %   Instrument-Limited Resolution:
    %     L_min_instrument - Minimum reliable wavelength [units]
    %
    %   Current Spatial Band:
    %     lambda_band    - [lambda_low, lambda_high] eigenvalue range
    %     L_band         - [L_min_band, L_max_band] wavelength range
    %     f_band         - [f_min_band, f_max_band] frequency range
    %
    %   Example:
    %     B = bct.io.import.mesh('path/to/mesh.pial');
    %     res = bct.resolution.spatial(B.Manifold);
    %     res.Units = bct.resolution.Units.mm;
    %     res.L_min_instrument = 25;  % 25 mm MEG resolution
    %     res.setBand([0.01, 0.5], bct.resolution.Quantity.lambda);
    %     modes = res.getModeIndices();
    %
    %   See also: bct.resolution.temporal, bct.manifold.Manifold
    
    properties
        Units bct.resolution.Units = bct.resolution.Units.mm  % Spatial units
        Manifold bct.manifold.Manifold                        % Associated manifold
    end
    
    properties (SetAccess = private)
        % Instrument-limited resolution (same structure as mesh resolution)
        InstrumentName string = ""           % Name of instrument (e.g., "MEG", "EEG")
        lambda_max_instrument double = []    % Instrument max eigenvalue [1/units^2]
        L_min_instrument double = []         % Instrument min wavelength [units]
        f_max_instrument double = []         % Instrument max spatial frequency [cycles/units]
        k_max_instrument double = []         % Instrument max wavenumber [rad/units]
        
        % Current spatial band
        lambda_band double = []  % [lambda_low, lambda_high]
        L_band double = []       % [L_min, L_max]
        f_band double = []       % [f_min, f_max]
        k_band double = []       % [k_min, k_max]
    end
    
    properties (Dependent)
        % Mesh theoretical resolution (from full eigenspectrum)
        lambda_max   % Maximum eigenvalue [1/units^2]
        Wavelength   % Minimum wavelength [units] (meaningful name for L_min)
        Wavenumber   % Maximum angular wavenumber [rad/units] (meaningful name for k_max)
        SpatialFrequency  % Maximum spatial frequency [cycles/units] (meaningful name for f_max)
        
        % Legacy aliases for compatibility
        f_max        % Alias for SpatialFrequency
        L_min        % Alias for Wavelength
        k_max        % Alias for Wavenumber
        
        % Resolution as struct (compatible with Manifold.Resolution)
        resolution   % struct with wavelength, lambda_max, k, freq
    end
    
    methods
        function obj = spatial(manifold)
            %SPATIAL Construct spatial resolution manager
            %
            %   res = bct.resolution.spatial(manifold) creates a spatial
            %   resolution manager for the given manifold
            %
            %   Inputs:
            %     manifold - bct.manifold.Manifold object (mesh type)
            
            if nargin < 1 || isempty(manifold)
                error('bct:resolution:spatial:NoManifold', ...
                    'Manifold object required');
            end
            
            if manifold.Type ~= "mesh"
                error('bct:resolution:spatial:InvalidType', ...
                    'spatial resolution only works with mesh manifolds');
            end
            
            obj.Manifold = manifold;
            
            % Inherit units from manifold if available
            if ~isempty(manifold.Units)
                obj.Units = bct.resolution.Units.(manifold.Units);
            end
        end
        
        %% Dependent properties
        function val = get.lambda_max(obj)
            %GET.LAMBDA_MAX Get maximum eigenvalue from manifold cache
            if ~isempty(obj.Manifold)
                val = obj.Manifold.getLambdaMaxFull();
            else
                val = [];
            end
        end
        
        function val = get.f_max(obj)
            %GET.F_MAX Maximum spatial frequency [cycles/units]
            val = obj.SpatialFrequency;
        end
        
        function val = get.SpatialFrequency(obj)
            %GET.SPATIALFREQUENCY Maximum spatial frequency [cycles/units]
            if ~isempty(obj.lambda_max)
                val = sqrt(obj.lambda_max) / (2*pi);
            else
                val = [];
            end
        end
        
        function val = get.L_min(obj)
            %GET.L_MIN Minimum wavelength (Nyquist limit) [units]
            val = obj.Wavelength;
        end
        
        function val = get.Wavelength(obj)
            %GET.WAVELENGTH Minimum wavelength (Nyquist limit) [units]
            if ~isempty(obj.SpatialFrequency)
                val = 1 / obj.SpatialFrequency;
            else
                val = [];
            end
        end
        
        function val = get.k_max(obj)
            %GET.K_MAX Maximum angular wavenumber [rad/units]
            val = obj.Wavenumber;
        end
        
        function val = get.Wavenumber(obj)
            %GET.WAVENUMBER Maximum angular wavenumber [rad/units]
            if ~isempty(obj.lambda_max)
                val = sqrt(obj.lambda_max);
            else
                val = [];
            end
        end
        
        function R = get.resolution(obj)
            %GET.RESOLUTION Get resolution struct (compatible with Manifold.Resolution)
            if isempty(obj.lambda_max)
                R = struct('wavelength', '', 'lambda_max', [], 'k', [], 'freq', []);
                return;
            end
            
            wavelength_str = sprintf('%.4f %s', obj.Wavelength, obj.Units.toString());
            
            R = struct(...
                'wavelength', wavelength_str, ...
                'lambda_max', obj.lambda_max, ...
                'k', obj.Wavenumber, ...
                'freq', obj.SpatialFrequency ...
            );
        end
        
        %% Instrument resolution methods
        function setInstrumentResolution(obj, value, quantity, instrumentName)
            %SETINSTRUMENTRESOLUTION Set instrument-limited resolution
            %
            %   res.setInstrumentResolution(value, quantity) sets the
            %   instrument resolution using the specified quantity type.
            %   Automatically calculates all other representations.
            %
            %   res.setInstrumentResolution(value, quantity, name) also
            %   stores the instrument name (e.g., 'MEG', 'EEG')
            %
            %   Inputs:
            %     value    - Resolution value
            %     quantity - bct.resolution.Quantity enum
            %     name     - Instrument name (optional, default: '')
            %
            %   Example:
            %     res.setInstrumentResolution(25, bct.resolution.Quantity.wavelength, 'MEG');
            %     res.setInstrumentResolution(0.5, bct.resolution.Quantity.lambda);
            
            if nargin < 3
                quantity = bct.resolution.Quantity.wavelength;
            end
            
            if nargin >= 4
                obj.InstrumentName = string(instrumentName);
            end
            
            % Convert to lambda
            switch quantity
                case bct.resolution.Quantity.lambda
                    obj.lambda_max_instrument = value;
                    
                case bct.resolution.Quantity.wavelength
                    % L = 2π/sqrt(λ) → λ = (2π/L)^2
                    obj.lambda_max_instrument = (2*pi/value)^2;
                    
                case bct.resolution.Quantity.k
                    % k = sqrt(λ) → λ = k^2
                    obj.lambda_max_instrument = value^2;
                    
                case bct.resolution.Quantity.freq
                    % f = sqrt(λ)/(2π) → λ = (2πf)^2
                    obj.lambda_max_instrument = (2*pi*value)^2;
            end
            
            % Compute other representations
            if ~isempty(obj.lambda_max_instrument)
                obj.k_max_instrument = sqrt(obj.lambda_max_instrument);
                obj.f_max_instrument = obj.k_max_instrument / (2*pi);
                obj.L_min_instrument = 1 / obj.f_max_instrument;
            end
        end
        
        function clearInstrumentResolution(obj)
            %CLEARINSTRUMENTRESOLUTION Clear instrument resolution settings
            obj.InstrumentName = "";
            obj.lambda_max_instrument = [];
            obj.L_min_instrument = [];
            obj.f_max_instrument = [];
            obj.k_max_instrument = [];
        end
        
        %% Band selection methods
        function setBand(obj, range, quantity)
            %SETBAND Set current spatial band
            %
            %   res.setBand([low, high], quantity) sets the spatial band
            %   using the specified quantity type
            %
            %   Inputs:
            %     range    - [low, high] range values
            %     quantity - bct.resolution.Quantity enum
            %
            %   Example:
            %     res.setBand([0.01, 0.5], bct.resolution.Quantity.lambda);
            %     res.setBand([5, 50], bct.resolution.Quantity.wavelength);
            
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
            end
            
            % Compute other band representations
            if ~isempty(obj.lambda_band)
                k_low = sqrt(obj.lambda_band(1));
                k_high = sqrt(obj.lambda_band(2));
                obj.k_band = [k_low, k_high];
                
                obj.f_band = [k_low/(2*pi), k_high/(2*pi)];
                obj.L_band = [1/(k_high/(2*pi)), 1/(k_low/(2*pi))];
            end
        end
        
        function indices = getModeIndices(obj)
            %GETMODEINDICES Get eigenmode indices in current band
            %
            %   indices = res.getModeIndices() returns the indices of
            %   eigenvalues that fall within the current spatial band
            %
            %   Returns:
            %     indices - Column vector of mode indices
            
            if isempty(obj.lambda_band)
                error('bct:resolution:spatial:NoBand', ...
                    'No spatial band set. Use setBand() first.');
            end
            
            if isempty(obj.Manifold.Eigenvalues)
                error('bct:resolution:spatial:NoEigenvalues', ...
                    'No eigenvalues computed. Call Manifold.meshFourier(k) first.');
            end
            
            lam = obj.Manifold.Eigenvalues;
            mask = (lam >= obj.lambda_band(1)) & (lam <= obj.lambda_band(2));
            indices = find(mask);
        end
        
        function patchSize = getPatchSize(obj, quantity)
            %GETPATCHSIZE Get characteristic patch size for current band
            %
            %   patchSize = res.getPatchSize() returns the characteristic
            %   spatial scale (wavelength) for the current band
            %
            %   patchSize = res.getPatchSize(quantity) returns the patch
            %   size in the specified quantity representation
            %
            %   Inputs:
            %     quantity - bct.resolution.Quantity enum (optional)
            %
            %   Returns:
            %     patchSize - Characteristic spatial scale
            
            if nargin < 2
                quantity = bct.resolution.Quantity.wavelength;
            end
            
            if isempty(obj.lambda_band)
                error('bct:resolution:spatial:NoBand', ...
                    'No spatial band set. Use setBand() first.');
            end
            
            % Use geometric mean of band limits
            lambda_mean = sqrt(obj.lambda_band(1) * obj.lambda_band(2));
            
            switch quantity
                case bct.resolution.Quantity.lambda
                    patchSize = lambda_mean;
                case bct.resolution.Quantity.k
                    patchSize = sqrt(lambda_mean);
                case bct.resolution.Quantity.freq
                    patchSize = sqrt(lambda_mean) / (2*pi);
                case bct.resolution.Quantity.wavelength
                    patchSize = 2*pi / sqrt(lambda_mean);
            end
        end
        
        %% Conversion methods
        function val = convert(~, value, fromQuantity, toQuantity)
            %CONVERT Convert between quantity representations
            %
            %   val = res.convert(value, fromQuantity, toQuantity)
            %
            %   Example:
            %     L = res.convert(0.5, Quantity.lambda, Quantity.wavelength);
            
            % Convert from → lambda
            switch fromQuantity
                case bct.resolution.Quantity.lambda
                    lambda = value;
                case bct.resolution.Quantity.k
                    lambda = value^2;
                case bct.resolution.Quantity.freq
                    lambda = (2*pi*value)^2;
                case bct.resolution.Quantity.wavelength
                    lambda = (2*pi/value)^2;
            end
            
            % Convert lambda → to
            switch toQuantity
                case bct.resolution.Quantity.lambda
                    val = lambda;
                case bct.resolution.Quantity.k
                    val = sqrt(lambda);
                case bct.resolution.Quantity.freq
                    val = sqrt(lambda) / (2*pi);
                case bct.resolution.Quantity.wavelength
                    val = 2*pi / sqrt(lambda);
            end
        end
        
        %% Display methods
        function disp(obj)
            %DISP Display spatial resolution information
            fprintf('\n  <a href="matlab:helpPopup bct.resolution.spatial">spatial</a> resolution:\n\n');
            fprintf('    Units: %s\n', obj.Units.toString());
            
            if ~isempty(obj.lambda_max)
                fprintf('\n  Mesh Resolution:\n');
                fprintf('    Wavelength:        %.4f %s\n', obj.Wavelength, obj.Units.toString());
                fprintf('    Spatial Frequency: %.4f cycles/%s\n', obj.SpatialFrequency, obj.Units.toString());
                fprintf('    Wavenumber:        %.4f rad/%s\n', obj.Wavenumber, obj.Units.toString());
                fprintf('    lambda_max:        %.4e\n', obj.lambda_max);
            end
            
            if ~isempty(obj.L_min_instrument)
                fprintf('\n  Instrument Resolution');
                if ~isempty(obj.InstrumentName) && strlength(obj.InstrumentName) > 0
                    fprintf(' (%s)', obj.InstrumentName);
                end
                fprintf(':\n');
                fprintf('    Wavelength:        %.4f %s\n', obj.L_min_instrument, obj.Units.toString());
                fprintf('    Spatial Frequency: %.4f cycles/%s\n', obj.f_max_instrument, obj.Units.toString());
                fprintf('    Wavenumber:        %.4f rad/%s\n', obj.k_max_instrument, obj.Units.toString());
                fprintf('    lambda_max:        %.4e\n', obj.lambda_max_instrument);
            end
            
            if ~isempty(obj.lambda_band)
                fprintf('\n  Current Spatial Band:\n');
                fprintf('    lambda: [%.4e, %.4e]\n', obj.lambda_band(1), obj.lambda_band(2));
                fprintf('    L:      [%.4f, %.4f] %s\n', obj.L_band(1), obj.L_band(2), obj.Units.toString());
                fprintf('    f:      [%.4f, %.4f] cycles/%s\n', obj.f_band(1), obj.f_band(2), obj.Units.toString());
                fprintf('    k:      [%.4f, %.4f] rad/%s\n', obj.k_band(1), obj.k_band(2), obj.Units.toString());
                
                if ~isempty(obj.Manifold.Eigenvalues)
                    nModes = numel(obj.getModeIndices());
                    fprintf('    Modes in band: %d\n', nModes);
                end
            end
            fprintf('\n');
        end
    end
end
