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
