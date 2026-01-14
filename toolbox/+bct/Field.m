classdef Field < handle
    %FIELD Data-on-manifold with support semantics
    %
    % Ergonomic wrapper around bct.field package (struct-based schema).
    % Provides object-oriented interface for fields defined on discrete
    % manifold supports with automatic validation and type safety.
    %
    % Syntax:
    %   F = bct.Field(manifold, value)
    %   F = bct.Field(manifold, value, Name=Value)
    %   F = bct.Field.fromStruct(fieldStruct)
    %
    % Inputs:
    %   manifold - bct.Manifold object
    %   value    - Numeric array [S×...] where S matches support size
    %
    % Name-Value Arguments:
    %   Support    - "vertex"|"face"|"edge"|"halfedge"|"dualFace"|"dualVertex" (default: inferred)
    %   ValueType  - "scalar"|"vector3"|"tangent2"|"complexScalar"|"complexVector3" (default: inferred)
    %   Time       - Time struct for time-varying fields
    %   Frame      - Tangent frame for tangent2 fields
    %   Meta       - Metadata struct
    %
    % Properties (Read-Only):
    %   Value         - Numeric array (primary data)
    %   Support       - Support type
    %   ValueType     - Value type
    %   ManifoldID    - Manifold identifier (not reference)
    %   Time          - Time metadata (empty for static fields)
    %   Meta          - Metadata struct
    %
    % Dependent Properties:
    %   IsTimeVarying - true if time-varying
    %   NumSamples    - Support cardinality
    %   NumTimeSteps  - Number of time samples
    %
    % Methods:
    %   toStruct      - Convert to struct representation
    %   manifold      - Resolve manifold from ID
    %
    % Examples:
    %   % Create scalar vertex field
    %   M = bct.Manifold(V, F);
    %   data = randn(M.numVertices(), 1);
    %   F = bct.Field(M, data);  % Auto-infers support and valueType
    %
    %   % Create time-varying field
    %   data = randn(M.numVertices(), 100);
    %   F = bct.Field(M, data, Time=struct('fs', 100, 'units', 's'));
    %
    %   % Explicit specification
    %   F = bct.Field(M, data, Support="face", ValueType="scalar");
    %
    %   % From struct
    %   s = bct.field.make('support', 'vertex', 'valueType', 'scalar', 'value', data);
    %   F = bct.Field.fromStruct(s);
    %
    %   % Convert back to struct
    %   s = F.toStruct();
    %
    % See also: bct.Manifold, bct.field.make, bct.field.validate

    properties (SetAccess = private)
        Value        % [S×...] numeric array (primary data)
        Support      % "vertex"|"face"|"edge"|"halfedge"|"dualFace"|"dualVertex"
        ValueType    % "scalar"|"vector3"|"tangent2"|"complexScalar"|"complexVector3"
        ManifoldID   % string - manifold identifier
        Time         % [] or time struct with fields: fs, t0, nSamples, units
        Meta         % struct - metadata (provenance, etc.)
        Metric       % struct - physical units and dimensions
        Frame        % [] or tangent frame basis (for tangent2 fields)
    end

    properties (Dependent)
        IsTimeVarying  % true if time dimension present
        NumSamples     % support cardinality (S)
        NumTimeSteps   % T if time-varying, else 1
    end

    properties (Access = private)
        SchemaVersion = "bct.field@1"
    end

    methods
        %% Constructor
        function obj = Field(manifold, value, options)
            %FIELD Construct Field object
            %
            % F = bct.Field(manifold, value)
            % F = bct.Field(manifold, value, Name=Value)
            
            arguments
                manifold = []
                value {mustBeNumeric} = []
                options.Support (1,1) string = ""
                options.ValueType (1,1) string = ""
                options.Time = []
                options.Frame {mustBeNumeric} = []
                options.Meta struct = struct()
                options.Metric struct = struct()
                options.Internal (1,1) logical = false
            end

            % Skip normal initialization if Internal flag set (for fromStruct)
            if options.Internal
                return;
            end
            
            % Validate manifold is provided for normal construction
            if isempty(manifold) || ~isa(manifold, 'bct.Manifold')
                error('bct:Field:InvalidManifold', ...
                    'First argument must be a bct.Manifold object');
            end

            % Store manifold ID (not reference - avoids circular refs)
            obj.ManifoldID = manifold.ID;
            obj.Value = value;
            obj.Meta = options.Meta;
            obj.Frame = options.Frame;
            
            % Initialize Metric (required field)
            if ~isempty(fieldnames(options.Metric))
                obj.Metric = options.Metric;
            else
                obj.Metric = bct.field.metric.default();
            end
            
            % Only set Time if non-empty
            if ~isempty(options.Time)
                obj.Time = options.Time;
            else
                obj.Time = [];
            end

            % Infer or validate support
            if options.Support == ""
                obj.Support = obj.inferSupport(manifold, value);
            else
                obj.Support = options.Support;
                obj.validateSupportSize(manifold);
            end

            % Infer or validate valueType
            if options.ValueType == ""
                obj.ValueType = obj.inferValueType(value);
            else
                obj.ValueType = options.ValueType;
            end

            % Validate against schema
            obj.validateField();
        end

        %% Dependent Properties
        function tf = get.IsTimeVarying(obj)
            %ISTIMEVARYING Check if field is time-varying
            tf = bct.field.isTimeVarying(obj.toStruct());
        end

        function n = get.NumSamples(obj)
            %NUMSAMPLES Get support cardinality
            n = size(obj.Value, 1);
        end

        function t = get.NumTimeSteps(obj)
            %NUMTIMESTEPS Get number of time samples
            if obj.IsTimeVarying
                switch obj.ValueType
                    case {"scalar", "complexScalar"}
                        t = size(obj.Value, 2);
                    case {"vector3", "tangent2", "complexVector3"}
                        t = size(obj.Value, 3);
                end
            else
                t = 1;
            end
        end

        %% Conversion Methods
        function s = toStruct(obj)
            %TOSTRUCT Convert to struct representation
            %
            % S = F.toStruct() converts Field object to validated struct
            % conforming to bct.field schema.
            %
            % The struct can be used with bct.field package functions
            % and serialized to disk.
            %
            % See also: bct.Field.fromStruct, bct.field.validate

            s = struct();
            s.schemaVersion = char(obj.SchemaVersion);
            s.meshId = char(obj.ManifoldID);
            s.support = char(obj.Support);
            s.valueType = char(obj.ValueType);
            s.value = obj.Value;
            s.meta = obj.Meta;
            s.metric = obj.Metric;
            
            % Only include time if non-empty (don't set empty [] to avoid validation warnings)
            if ~isempty(obj.Time)
                s.time = obj.Time;
            end
            
            % Only include frame if non-empty
            if ~isempty(obj.Frame)
                s.frame = obj.Frame;
            end

            % Validate before returning
            bct.field.validate(s);
        end

        %% Manifold Resolution
        function M = manifold(obj)
            %MANIFOLD Resolve manifold from ID
            %
            % M = F.manifold() retrieves the bct.Manifold object
            % associated with this field by resolving the ManifoldID.
            %
            % Note: Currently requires the manifold to be in the workspace.
            % Future versions will use bct.runtime.manifolds.resolve()
            
            % For now, search in caller workspace
            % TODO: Implement bct.runtime.manifolds registry
            vars = evalin('caller', 'whos');
            for i = 1:length(vars)
                if strcmp(vars(i).class, 'bct.Manifold')
                    M = evalin('caller', vars(i).name);
                    if M.ID == obj.ManifoldID
                        return;
                    end
                end
            end
            
            error('bct:Field:ManifoldNotFound', ...
                'Manifold with ID "%s" not found in workspace', obj.ManifoldID);
        end

        %% Display
        function disp(obj)
            %DISP Display field information
            
            fprintf('  <a href="matlab:helpPopup bct.Field">bct.Field</a> with properties:\n\n');
            fprintf('         Support: %s\n', obj.Support);
            fprintf('      ValueType: %s\n', obj.ValueType);
            fprintf('          Value: [%s] %s\n', mat2str(size(obj.Value)), class(obj.Value));
            fprintf('     ManifoldID: %s\n', obj.ManifoldID);
            
            if obj.IsTimeVarying
                fprintf('  IsTimeVarying: true (%d samples)\n', obj.NumTimeSteps);
                if ~isempty(obj.Time)
                    if isfield(obj.Time, 'fs')
                        fprintf('     SampleRate: %.1f Hz\n', obj.Time.fs);
                    end
                end
            else
                fprintf('  IsTimeVarying: false\n');
            end
            
            if ~isempty(obj.Meta)
                fprintf('           Meta: [struct with %d fields]\n', length(fieldnames(obj.Meta)));
            end
            
            % Show metric status
            if ~isempty(obj.Metric)
                fprintf('     MetricUnit: %s (status: %s)\n', obj.Metric.unit, obj.Metric.status);
            end
            
            fprintf('\n');
        end
    end

    methods (Static)
        %% Static Constructors
        function obj = fromStruct(s)
            %FROMSTRUCT Create Field from validated struct
            %
            % F = bct.Field.fromStruct(s) creates a Field object from
            % a struct conforming to bct.field schema.
            %
            % Input:
            %   s - Field struct (from bct.field.make or similar)
            %
            % See also: bct.Field.toStruct, bct.field.make

            arguments
                s struct
            end

            % Validate struct
            bct.field.validate(s);

            % Create object with Internal flag (skip normal initialization)
            obj = bct.Field([], [], Internal=true);
            
            % Set all properties directly
            obj.SchemaVersion = string(s.schemaVersion);
            obj.ManifoldID = string(s.meshId);
            obj.Support = string(s.support);
            obj.ValueType = string(s.valueType);
            obj.Value = s.value;
            
            % Handle metric (required field)
            if isfield(s, 'metric')
                obj.Metric = s.metric;
            else
                obj.Metric = bct.field.metric.default();
            end
            
            if isfield(s, 'time') && ~isempty(s.time)
                obj.Time = s.time;
            else
                obj.Time = [];
            end
            
            if isfield(s, 'frame') && ~isempty(s.frame)
                obj.Frame = s.frame;
            else
                obj.Frame = [];
            end
            
            if isfield(s, 'meta')
                obj.Meta = s.meta;
            else
                obj.Meta = struct();
            end
        end
    end

    methods (Access = private)
        %% Private Validation and Inference
        function support = inferSupport(obj, manifold, value)
            %INFERSUPPORT Infer support type from value size and manifold
            
            S = size(value, 1);
            
            % Try to match support size
            if S == manifold.numVertices()
                support = "vertex";
            elseif S == manifold.numFaces()
                support = "face";
            elseif S == manifold.numEdges()
                support = "edge";
            elseif S == 3 * manifold.numFaces()
                support = "halfedge";
            else
                error('bct:Field:CannotInferSupport', ...
                    'Cannot infer support: value size [%d] does not match any manifold support', S);
            end
        end

        function valueType = inferValueType(obj, value)
            %INFERVALUETYPE Infer value type from array shape
            
            sz = size(value);
            isComplex = ~isreal(value);
            
            % Check dimensionality
            if ndims(value) == 2
                % [S×D] - static field
                if sz(2) == 1
                    valueType = "scalar";
                    if isComplex, valueType = "complexScalar"; end
                elseif sz(2) == 2
                    valueType = "tangent2";
                elseif sz(2) == 3
                    valueType = "vector3";
                    if isComplex, valueType = "complexVector3"; end
                else
                    % Assume time-varying scalar [S×T]
                    valueType = "scalar";
                    if isComplex, valueType = "complexScalar"; end
                end
            elseif ndims(value) == 3
                % [S×D×T] - time-varying field
                if sz(2) == 2
                    valueType = "tangent2";
                elseif sz(2) == 3
                    valueType = "vector3";
                    if isComplex, valueType = "complexVector3"; end
                else
                    error('bct:Field:CannotInferValueType', ...
                        'Cannot infer valueType from shape [%s]', mat2str(sz));
                end
            else
                error('bct:Field:InvalidDimensions', ...
                    'Field value must be 2D or 3D array');
            end
        end

        function validateSupportSize(obj, manifold)
            %VALIDATESUPPORTSIZE Validate value size matches support
            
            expectedSize = bct.field.sizeOfSupport(obj.Support, manifold);
            actualSize = size(obj.Value, 1);
            
            if actualSize ~= expectedSize
                error('bct:Field:SizeMismatch', ...
                    'Value size [%d] does not match %s support size [%d]', ...
                    actualSize, obj.Support, expectedSize);
            end
        end

        function validateField(obj)
            %VALIDATEFIELD Validate field against schema
            
            % Convert to struct and validate
            s = obj.toStruct();
            bct.field.validate(s);
        end
    end

    methods (Static, Access = private)
        function M = createDummyManifold(s)
            %CREATEDUMMYMANIFOLD Create minimal manifold for fromStruct
            
            % Create a minimal object that satisfies constructor requirements
            M = struct();
            M.ID = string(s.meshId);
            
            % Add size methods based on support
            supportSize = size(s.value, 1);
            switch s.support
                case "vertex"
                    M.numVertices = @() supportSize;
                    M.numFaces = @() 0;
                    M.numEdges = @() 0;
                case "face"
                    M.numVertices = @() 0;
                    M.numFaces = @() supportSize;
                    M.numEdges = @() 0;
                case "edge"
                    M.numVertices = @() 0;
                    M.numFaces = @() 0;
                    M.numEdges = @() supportSize;
                case "halfedge"
                    M.numVertices = @() 0;
                    M.numFaces = @() supportSize / 3;
                    M.numEdges = @() 0;
                otherwise
                    M.numVertices = @() supportSize;
                    M.numFaces = @() 0;
                    M.numEdges = @() 0;
            end
            
            % Convert to Manifold-like object
            M = struct('ID', M.ID, ...
                      'numVertices', M.numVertices, ...
                      'numFaces', M.numFaces, ...
                      'numEdges', M.numEdges);
            M = bct.Field.wrapStruct(M);
        end
        
        function obj = wrapStruct(s)
            %WRAPSTRUCT Wrap struct as object with methods
            obj = s;
        end
    end

    methods
        %% Serialization
        function s = saveobj(obj)
            %SAVEOBJ Save Field as struct
            s = obj.toStruct();
        end
    end

    methods (Static)
        function obj = loadobj(s)
            %LOADOBJ Load Field from struct
            if isstruct(s)
                obj = bct.Field.fromStruct(s);
            else
                obj = s;
            end
        end
    end
end
