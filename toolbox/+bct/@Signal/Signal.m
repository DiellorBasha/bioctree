classdef Signal < handle
%BCT.SIGNAL  Lightweight signal container
%
%   A Signal represents data defined on a Manifold axis or a
%   Manifold × Time joint axis.
%
%   Signal is intentionally lightweight:
%     - no computation
%     - no operators
%     - no UI state
%
%   Signals are immutable by convention: transformations produce
%   new Signal objects.

    properties (SetAccess = private)

        % =====================================================
        % Core data
        % =====================================================
        Data                % numeric array: [N×1] or [N×T]

        % =====================================================
        % Domain reference
        % =====================================================
        Domain              % bct.Domain (Manifold, Lambda, Time, etc.)
        Time                % bct.Time (optional, [] if not joint)

        % =====================================================
        % Provenance
        % =====================================================
        Id                  % unique identifier for provenance tracking
        Metadata            % struct (generator, filter, params, etc.)
        
        % =====================================================
        % Cached differential operators (Manifold signals only)
        % =====================================================
        Gradient            % [M×3] face-based gradient (cached)
        Divergence          % [N×1] vertex-based divergence (cached)
        Curl                % [N×1] vertex-based curl (cached)
        
        % =====================================================
        % Helmholtz-Hodge decomposition (Manifold signals only)
        % =====================================================
        RotationalMagnitude % [N×1] magnitude of curl-free component (cached)
        DivergenceMagnitude % [N×1] magnitude of divergence-free component (cached)
        HarmonicMagnitude   % [N×1] magnitude of harmonic component (cached)
    end

    properties (Dependent)
        N                   % number of spatial samples
        T                   % number of time samples (1 if static)
        IsJoint             % true if Domain-Time signal
    end

    methods
        %% ----------------------------------------------------
        function obj = Signal(data, domain, time, metadata)
        %BCT.SIGNAL Construct a Signal
        %
        %   Signal(data, domain)
        %   Signal(data, domain, time)
        %   Signal(data, domain, time, metadata)
        %
        %   Inputs:
        %     data     - numeric array [N×1] or [N×T]
        %     domain   - bct.Domain (Manifold, Lambda, etc.)
        %     time     - bct.Time (optional, for joint signals)
        %     metadata - struct with provenance info

            arguments
                data double
                domain (1,1) bct.Domain
                time = []
                metadata struct = struct()
            end
            
            % Validate time input if provided
            if ~isempty(time) && ~isa(time, 'bct.Time')
                error('Signal:InvalidTime', ...
                    'time must be empty [] or a bct.Time object');
            end

            % Validate dimensions
            if isempty(time)
                % Static domain signal
                if size(data,1) ~= domain.N
                    error('Signal:InvalidSize', ...
                        'Data must be [N×1] for static signal.');
                end
            else
                % Domain × Time signal
                if size(data,1) ~= domain.N
                    error('Signal:InvalidSize', ...
                        'First dimension must match Domain.N');
                end

                if size(data,2) ~= time.N
                    error('Signal:InvalidSize', ...
                        'Second dimension must match Time.N');
                end
            end

            % Assign
            obj.Data     = data;
            obj.Domain   = domain;
            obj.Time     = time;
            obj.Metadata = metadata;
            obj.Id       = char(java.util.UUID.randomUUID()); % unique ID
        end

        %% ----------------------------------------------------
        function n = get.N(obj)
            n = obj.Domain.N;
        end

        %% ----------------------------------------------------
        function t = get.T(obj)
            if isempty(obj.Time)
                t = 1;
            else
                t = obj.Time.N;
            end
        end

        %% ----------------------------------------------------
        function tf = get.IsJoint(obj)
            tf = ~isempty(obj.Time);
        end
    end

    methods (Static)
        %% ----------------------------------------------------
        function sig = fromBrush(manifold, varargin)
        %FROMBRUSH Generate signal from brush system
        %
        %   sig = Signal.fromBrush(manifold, 'Category', cat, 'Type', type, ...)
        %
        % Required Inputs:
        %   manifold - bct.Manifold object
        %
        % Name-Value Parameters:
        %   'Category'  - Brush category: 'patch', 'trajectory', 'time'
        %   'Type'      - Brush type: 'spectral', 'gaussian', 'heat', 'geodesic', 'nearest'
        %   'Time'      - bct.Time object (required for 'time' category)
        %   'Label'     - Signal label (default: auto-generated)
        %   ...         - Additional brush-specific parameters
        %
        % Brush-Specific Parameters:
        %   For 'patch' brushes:
        %     'Source'    - Seed vertex index
        %     'Kernel'    - Kernel name (for spectral)
        %     'Sigma'     - Sigma parameter
        %     'Tau'       - Tau parameter
        %     'Bandwidth' - Eigenmode bandwidth
        %
        %   For 'trajectory' brushes:
        %     'Source'    - Source vertex
        %     'Target'    - Target vertex
        %     'Sigma'     - Sigma parameter
        %     'Kernel'    - Kernel name (for spectral)
        %     'KernelParams' - Struct of kernel parameters
        %     'Metric'    - Distance metric
        %
        %   For 'time' brushes:
        %     All trajectory parameters plus:
        %     'TauRange'    - [start, end] for heat
        %     'TauProfile'  - 'linear', 'exponential', 'sigmoid'
        %
        % Examples:
        %   % Patch - Spectral gaussian
        %   sig = Signal.fromBrush(B.Manifold, 'Category', 'patch', ...
        %       'Type', 'spectral', 'Source', 1000, 'Kernel', 'gaussian', ...
        %       'Sigma', 15);
        %
        %   % Trajectory - Spectral with heat kernel
        %   sig = Signal.fromBrush(B.Manifold, 'Category', 'trajectory', ...
        %       'Type', 'spectral', 'Source', 100, 'Target', 500, ...
        %       'Kernel', 'heat', 'KernelParams', struct('tau', 0.1));
        %
        %   % Time - Moving spectral patch
        %   [path, ~] = B.Manifold.Graph.shortestPath(100, 500);
        %   sig = Signal.fromBrush(B.Manifold, 'Category', 'time', ...
        %       'Type', 'spectral', 'Time', B.Time, ...
        %       'Source', @(t,T) path(min(round(t/T*length(path)), length(path))), ...
        %       'Kernel', 'heat', 'Tau', 0.15);
        %
        % See also: bct.brush.patch, bct.brush.trajectory, bct.brush.time
        
            % Parse inputs
            p = inputParser;
            p.KeepUnmatched = true;
            p.addRequired('manifold', @(x) isa(x, 'bct.Manifold'));
            p.addParameter('Category', '', @(x) ischar(x) || isstring(x));
            p.addParameter('Type', '', @(x) ischar(x) || isstring(x));
            p.addParameter('Time', [], @(x) isempty(x) || isa(x, 'bct.Time'));
            p.addParameter('Label', '', @(x) ischar(x) || isstring(x));
            p.parse(manifold, varargin{:});
            
            category = string(p.Results.Category);
            type = string(p.Results.Type);
            time_domain = p.Results.Time;
            label = string(p.Results.Label);
            
            % Validate required parameters
            if isempty(category) || isempty(type)
                error('Signal:fromBrush:MissingParams', ...
                    'Both Category and Type must be specified');
            end
            
            % Build parameters struct from unmatched parameters
            params = struct();
            unmatched_fields = fieldnames(p.Unmatched);
            for i = 1:length(unmatched_fields)
                field = unmatched_fields{i};
                % Convert to lowercase for brush parameter names
                params.(lower(field)) = p.Unmatched.(field);
            end
            
            % Call appropriate brush function
            category_lower = lower(category);
            type_lower = lower(type);
            
            try
                switch category_lower
                    case 'patch'
                        % Call patch brush: bct.brush.patch.<type>
                        brush_fn = str2func(['bct.brush.patch.' char(type_lower)]);
                        w = brush_fn(manifold, params);
                        domain = manifold;
                        time_out = [];
                        
                    case 'trajectory'
                        % Call trajectory brush: bct.brush.trajectory.<type>
                        brush_fn = str2func(['bct.brush.trajectory.' char(type_lower)]);
                        w = brush_fn(manifold, params);
                        domain = manifold;
                        time_out = [];
                        
                    case 'time'
                        % Call time brush: bct.brush.time.<type>
                        if isempty(time_domain)
                            error('Signal:fromBrush:MissingTime', ...
                                'Time domain required for time category brushes');
                        end
                        brush_fn = str2func(['bct.brush.time.' char(type_lower)]);
                        w = brush_fn(manifold, time_domain, params);
                        domain = manifold;
                        time_out = time_domain;
                        
                    otherwise
                        error('Signal:fromBrush:UnknownCategory', ...
                            'Unknown brush category: %s. Use: patch, trajectory, time', ...
                            category);
                end
            catch ME
                if strcmp(ME.identifier, 'MATLAB:UndefinedFunction')
                    error('Signal:fromBrush:UnknownBrush', ...
                        'Brush not found: bct.brush.%s.%s\n%s', ...
                        category_lower, type_lower, ME.message);
                else
                    rethrow(ME);
                end
            end
            
            % Generate label if not provided
            if isempty(label)
                if ~isempty(time_out)
                    label = sprintf('%s_%s_spatiotemporal', category_lower, type_lower);
                else
                    label = sprintf('%s_%s', category_lower, type_lower);
                end
            end
            
            % Build metadata
            metadata = struct();
            metadata.generator = 'fromBrush';
            metadata.category = char(category);
            metadata.brush_type = char(type);
            metadata.brush_params = params;
            metadata.Label = char(label);
            
            % Create Signal object
            % For time category signals, create a Joint domain
            if ~isempty(time_out)
                joint_domain = bct.Joint(domain, time_out);
                sig = bct.Signal(full(w), joint_domain, [], metadata);
            else
                sig = bct.Signal(full(w), domain, [], metadata);
            end
        end
    end
    
    methods
        %% ----------------------------------------------------
        function s = copy(obj)
        %COPY Shallow copy of signal (cheap)
            s = bct.Signal(obj.Data, obj.Domain, obj.Time, obj.Metadata);
        end

        %% ----------------------------------------------------
        function s = withMetadata(obj, meta)
        %WITHMETADATA Return new Signal with merged metadata

            newMeta = obj.Metadata;
            fn = fieldnames(meta);
            for i = 1:numel(fn)
                newMeta.(fn{i}) = meta.(fn{i});
            end

            s = bct.Signal(obj.Data, obj.Domain, obj.Time, newMeta);
        end
        
        %% ----------------------------------------------------
        function s_spectral = mft(obj)
        %MFT Manifold Fourier Transform to spectral domain
        %
        %   s_spectral = signal.mft()
        %
        % Outputs:
        %   s_spectral - bct.Signal on Lambda domain (spectral coefficients)
        %
        % Description:
        %   Transforms the signal from Manifold domain to its spectral
        %   basis (Lambda domain) using the FEM-based Manifold Fourier
        %   Transform: x_hat = Phi' * M * x
        %
        %   where M is the mass matrix and Phi are the eigenmodes.
        %
        % Example:
        %   % Create signal on manifold
        %   sig = bct.Signal(data, manifold);
        %   
        %   % Transform to spectral domain
        %   sig_spectral = sig.mft();
        %   
        %   % Inverse transform back
        %   sig_reconstructed = sig_spectral.imft();
        %
        % See also: imft, bct.operator.transform.mft
        
            % Validate domain type
            if ~isa(obj.Domain, 'bct.Manifold')
                error('Signal:mft:InvalidDomain', ...
                    'MFT only defined for Manifold signals');
            end
            
            % Validate signal is static (not joint)
            if obj.IsJoint
                error('Signal:mft:JointSignal', ...
                    'MFT not implemented for joint signals');
            end
            
            % Transform using operator
            s_spectral = bct.operator.transform.mft(obj);
        end
        
        %% ----------------------------------------------------
        function s_spatial = imft(obj)
        %IMFT Inverse Manifold Fourier Transform to spatial domain
        %
        %   s_spatial = signal.imft()
        %
        % Outputs:
        %   s_spatial - bct.Signal on Manifold domain (vertex-based)
        %
        % Description:
        %   Transforms the signal from Lambda domain (spectral) back to
        %   Manifold domain (spatial) using the inverse Manifold Fourier
        %   Transform: x_rec = Phi * x_hat
        %
        % Example:
        %   % Transform spectral signal back to spatial
        %   sig_spatial = sig_spectral.imft();
        %
        % See also: mft, bct.operator.transform.imft
        
            % Validate domain type
            if ~isa(obj.Domain, 'bct.Lambda')
                error('Signal:imft:InvalidDomain', ...
                    'IMFT only defined for Lambda signals');
            end
            
            % Validate signal is static (not joint)
            if obj.IsJoint
                error('Signal:imft:JointSignal', ...
                    'IMFT not implemented for joint signals');
            end
            
            % Transform using operator
            s_spatial = bct.operator.transform.imft(obj);
        end
        
        %% ----------------------------------------------------
        function [gradW, gradW_unit, amplitude, phase] = gradient(obj)
        %GRADIENT Compute gradient of signal using DEC
        %
        %   gradW = signal.gradient()
        %   [gradW, gradW_unit] = signal.gradient()
        %   [gradW, gradW_unit, amplitude, phase] = signal.gradient()
        %
        % Outputs:
        %   gradW      - Gradient vectors [M×3] on faces
        %   gradW_unit - Unit gradient vectors [M×3]
        %   amplitude  - Gradient amplitude [M×1] in tangent frame
        %   phase      - Gradient phase [M×1] in tangent frame (radians)
        %
        % Note: Only valid for signals on Manifold domain. Result is cached.
        
            % Validate domain type
            if ~isa(obj.Domain, 'bct.Manifold')
                error('Signal:gradient:InvalidDomain', ...
                    'Gradient only defined for Manifold signals');
            end
            
            % Validate signal is static (not joint)
            if obj.IsJoint
                error('Signal:gradient:JointSignal', ...
                    'Gradient not implemented for joint signals');
            end
            
            % Compute if not cached
            if isempty(obj.Gradient)
                [obj.Gradient, gradW_unit, amplitude, phase] = ...
                    bct.operator.differential.gradient(obj.Domain, obj.Data);
            else
                gradW_unit = [];
                amplitude = [];
                phase = [];
            end
            
            % Return cached gradient
            gradW = obj.Gradient;
            
            % Compute additional outputs if requested and not cached
            if nargout > 1 && isempty(gradW_unit)
                [~, gradW_unit, amplitude, phase] = ...
                    bct.operator.differential.gradient(obj.Domain, obj.Data);
            end
        end
        
        %% ----------------------------------------------------
        function divU = divergence(obj, U, options)
        %DIVERGENCE Compute divergence of vector field
        %
        %   divU = signal.divergence(U)
        %   divU = signal.divergence(U, 'Negate', true)
        %
        % Inputs:
        %   U - Vector field [M×3] on faces (e.g., gradient)
        %
        % Name-Value Arguments:
        %   Negate - If true, negates U before computing divergence
        %
        % Outputs:
        %   divU - Divergence [N×1] on vertices
        %
        % Note: Only valid for signals on Manifold domain.
        
            arguments
                obj (1,1) bct.Signal
                U (:,3) double
                options.Negate (1,1) logical = false
            end
            
            % Validate domain type
            if ~isa(obj.Domain, 'bct.Manifold')
                error('Signal:divergence:InvalidDomain', ...
                    'Divergence only defined for Manifold signals');
            end
            
            % Compute divergence using operator
            divU = bct.operator.differential.divergence(obj.Domain, U, ...
                'Negate', options.Negate);
            
            % Cache if U is the gradient of this signal
            if isempty(obj.Divergence) && isequal(U, obj.Gradient)
                obj.Divergence = divU;
            end
        end
        
        %% ----------------------------------------------------
        function curlU = curl(obj, U, options)
        %CURL Compute curl of vector field
        %
        %   curlU = signal.curl(U)
        %   curlU = signal.curl(U, 'Negate', true)
        %
        % Inputs:
        %   U - Vector field [M×3] on faces (e.g., gradient)
        %
        % Name-Value Arguments:
        %   Negate - If true, negates U before computing curl
        %
        % Outputs:
        %   curlU - Curl (scalar) [N×1] on vertices
        %
        % Note: Only valid for signals on Manifold domain.
        
            arguments
                obj (1,1) bct.Signal
                U (:,3) double
                options.Negate (1,1) logical = false
            end
            
            % Validate domain type
            if ~isa(obj.Domain, 'bct.Manifold')
                error('Signal:curl:InvalidDomain', ...
                    'Curl only defined for Manifold signals');
            end
            
            % Compute curl using operator
            curlU = bct.operator.differential.curl(obj.Domain, U, ...
                'Negate', options.Negate);
            
            % Cache if U is the gradient of this signal
            if isempty(obj.Curl) && isequal(U, obj.Gradient)
                obj.Curl = curlU;
            end
        end
        
        %% ----------------------------------------------------
        function [rotU_mag, divU_mag, harmU_mag, rotU, divU, harmU, scalarP, vectorP] = hhdecomposition(obj)
        %HHDECOMPOSITION Compute Helmholtz-Hodge decomposition magnitudes
        %
        %   rotU_mag = signal.hhdecomposition()
        %   [rotU_mag, divU_mag, harmU_mag] = signal.hhdecomposition()
        %   [rotU_mag, divU_mag, harmU_mag, rotU, divU, harmU] = signal.hhdecomposition()
        %   [rotU_mag, divU_mag, harmU_mag, rotU, divU, harmU, scalarP, vectorP] = signal.hhdecomposition()
        %
        % Outputs:
        %   rotU_mag  - Curl-free component magnitude [N×1] on vertices
        %   divU_mag  - Divergence-free component magnitude [N×1] on vertices
        %   harmU_mag - Harmonic component magnitude [N×1] on vertices
        %   rotU      - Curl-free vector field [M×3] on faces
        %   divU      - Divergence-free vector field [M×3] on faces
        %   harmU     - Harmonic vector field [M×3] on faces
        %   scalarP   - Scalar potential (for curl-free component)
        %   vectorP   - Vector potential (for divergence-free component)
        %
        % Description:
        %   Performs Helmholtz-Hodge decomposition of the gradient of this
        %   signal and computes vertex-based magnitudes for visualization.
        %   Results are cached for efficiency.
        %
        % Note: Only valid for signals on Manifold domain.
        
            % Validate domain type
            if ~isa(obj.Domain, 'bct.Manifold')
                error('Signal:hhdecomposition:InvalidDomain', ...
                    'Helmholtz-Hodge decomposition only defined for Manifold signals');
            end
            
            % Validate signal is static (not joint)
            if obj.IsJoint
                error('Signal:hhdecomposition:JointSignal', ...
                    'Helmholtz-Hodge decomposition not implemented for joint signals');
            end
            
            % Compute gradient if not cached
            U = obj.gradient();
            
            % Compute decomposition if magnitudes not cached
            if isempty(obj.RotationalMagnitude) || ...
               isempty(obj.DivergenceMagnitude) || ...
               isempty(obj.HarmonicMagnitude)
                
                % Perform Helmholtz-Hodge decomposition
                [divU, rotU, harmU, scalarP, vectorP] = ...
                    bct.operator.differential.hhdecomposition(obj.Domain, U);
                
                % Compute magnitudes for coloring
                obj.RotationalMagnitude = ...
                    bct.operator.transform.faceVec2vertMag(obj.Domain, rotU);
                obj.DivergenceMagnitude = ...
                    bct.operator.transform.faceVec2vertMag(obj.Domain, divU);
                obj.HarmonicMagnitude = ...
                    bct.operator.transform.faceVec2vertMag(obj.Domain, harmU);
            else
                % Use cached values, but recompute components if requested
                if nargout > 3
                    [divU, rotU, harmU, scalarP, vectorP] = ...
                        bct.operator.differential.hhdecomposition(obj.Domain, U);
                else
                    divU = [];
                    rotU = [];
                    harmU = [];
                    scalarP = [];
                    vectorP = [];
                end
            end
            
            % Return cached magnitudes
            rotU_mag = obj.RotationalMagnitude;
            divU_mag = obj.DivergenceMagnitude;
            harmU_mag = obj.HarmonicMagnitude;
        end
    end

end
