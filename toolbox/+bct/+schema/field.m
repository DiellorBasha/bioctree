function spec = field()
%FIELD Return canonical schema specification for BCT field structures
%
% Syntax:
%   spec = bct.schema.field()
%
% Description:
%   Defines the authoritative schema for field structures in BCT.
%   A field structure represents data defined on manifold supports
%   (vertices, faces, edges, etc.) with optional time variation.
%
%   Field is a top-level group (like manifold) that can contain one or
%   more field datasets. In HDF5/Zarr serialization:
%     /field/data1      - First field dataset
%     /field/data2      - Second field dataset
%     /field/attributes - Group-level metadata
%
%   Each field dataset follows the bct.schema.dataset pattern with
%   .value (numeric array) and .attributes (metadata).
%
% Structure:
%   F = struct(...
%       'data', struct(...              % Field dataset (can have multiple)
%           'value', [...], ...         % Numeric array [S×...] or [S×...×T]
%           'attributes', struct(...)), % Dataset metadata
%       'Attributes', struct(...        % Group-level attributes
%           'path', '/field', ...
%           'schema', 'bct.field@1.1', ...
%           'package', 'bct', ...
%           'manifoldID', 'fsaverage_rh_pial', ...
%           'numFields', 1))
%
% Outputs:
%   spec - Structure with fields:
%     .name         - Schema name
%     .version      - Schema version string
%     .description  - Human-readable description
%     .attributes   - Group attributes specification
%     .datasets     - Dataset specifications
%     .validation   - Validation function handles
%
% Examples:
%   % Get field schema
%   spec = bct.schema.field();
%
%   % Create schema-compliant field
%   M = bct.Manifold(V, F);
%   data = randn(M.numVertices(), 1);
%   F = bct.schema.field.make(M, data, 'Name', 'myfield');
%
%   % Validate field structure
%   isValid = bct.schema.field.validate(F);
%
% See also: bct.Field, bct.schema.dataset, bct.schema.group, 
%           bct.field.make, bct.field.validate

% Schema metadata
spec.name = "bct.field";
spec.version = "1.1.0";
spec.description = "Schema for field structures (data-on-manifold)";
spec.package = "bct.schema";

%% Group Attributes (extends bct.schema.group)
spec.attributes = struct();

% Base fields (from bct.schema.group)
spec.attributes.base = struct(...
    'path', '/field', ...
    'schema', 'bct.field@1.1', ...
    'package', 'bct');

% Field-specific required attributes
spec.attributes.required = struct();

spec.attributes.required.manifoldID = struct(...
    'type', 'string', ...
    'description', 'Manifold identifier this field is defined on', ...
    'validation', @(x) isstring(x) || ischar(x));

% Field-specific optional attributes
spec.attributes.optional = struct();

spec.attributes.optional.numFields = struct(...
    'type', 'uint32', ...
    'description', 'Number of field datasets in this group', ...
    'default', uint32(1));

spec.attributes.optional.Source = struct(...
    'type', 'string', ...
    'description', 'Data source or provenance', ...
    'default', "");

spec.attributes.optional.Description = struct(...
    'type', 'string', ...
    'description', 'Human-readable description', ...
    'default', "");

%% Dataset Specifications
% Each field dataset has specific attributes beyond base dataset schema
spec.datasets = struct();

spec.datasets.support = struct(...
    'type', 'string', ...
    'description', 'Support type where field is defined', ...
    'allowedValues', ["vertex", "face", "edge", "halfedge", "dualFace", "dualVertex"], ...
    'required', true);

spec.datasets.valueType = struct(...
    'type', 'string', ...
    'description', 'Type of values stored in field', ...
    'allowedValues', ["scalar", "vector3", "tangent2", "complexScalar", "complexVector3"], ...
    'required', true);

spec.datasets.isTimeVarying = struct(...
    'type', 'logical', ...
    'description', 'Whether field varies in time', ...
    'default', false);

spec.datasets.time = struct(...
    'type', 'struct', ...
    'description', 'Time metadata for time-varying fields', ...
    'requiredIf', @(attrs) attrs.isTimeVarying, ...
    'fields', struct(...
        'nSamples', struct('type', 'uint32', 'required', true), ...
        'fs', struct('type', 'double', 'description', 'Sampling frequency'), ...
        't0', struct('type', 'double', 'description', 'Start time', 'default', 0.0), ...
        't', struct('type', 'double', 'description', 'Time vector'), ...
        'units', struct('type', 'string', 'default', "s")));

spec.datasets.frame = struct(...
    'type', 'struct', ...
    'description', 'Tangent frame basis for tangent2 fields', ...
    'requiredIf', @(attrs) strcmp(attrs.valueType, 'tangent2'), ...
    'fields', struct(...
        'domain', struct('type', 'string', 'allowedValues', ["vertex", "face"], 'required', true), ...
        'e1', struct('type', 'double', 'description', 'First tangent basis [S×3]', 'required', true), ...
        'e2', struct('type', 'double', 'description', 'Second tangent basis [S×3]', 'required', true), ...
        'normal', struct('type', 'double', 'description', 'Normal vectors [S×3]'), ...
        'convention', struct('type', 'string', 'description', 'Frame convention'), ...
        'source', struct('type', 'string', 'description', 'Frame source')));

spec.datasets.metric = struct(...
    'type', 'struct', ...
    'description', 'Physical units and dimensions', ...
    'fields', struct(...
        'units', struct('type', 'string', 'default', "1"), ...
        'dimensions', struct('type', 'string', 'description', 'Physical dimensions'), ...
        'scale', struct('type', 'double', 'default', 1.0)));

%% Value Shape Rules
spec.shapes = struct();

% Shape functions return expected size given support size S and time samples T
spec.shapes.scalar = struct(...
    'static', @(S) [S, 1], ...
    'timeSeries', @(S, T) [S, T]);

spec.shapes.vector3 = struct(...
    'static', @(S) [S, 3], ...
    'timeSeries', @(S, T) [S, 3, T]);

spec.shapes.tangent2 = struct(...
    'static', @(S) [S, 2], ...
    'timeSeries', @(S, T) [S, 2, T]);

spec.shapes.complexScalar = struct(...
    'static', @(S) [S, 1], ...
    'timeSeries', @(S, T) [S, T]);

spec.shapes.complexVector3 = struct(...
    'static', @(S) [S, 3], ...
    'timeSeries', @(S, T) [S, 3, T]);

%% Structure Specification
spec.structure = struct();
spec.structure.description = 'Field group must have Attributes and at least one dataset';
spec.structure.minDatasets = 1;
spec.structure.maxDatasets = Inf;

%% Validation
spec.validate = @validateField;

%% Helper Functions
spec.make = @makeField;

%% Documentation
spec.documentation = struct(...
    'purpose', 'Enforce uniform field structure across BCT', ...
    'usage', 'All field representations should conform to this schema', ...
    'examples', struct(...
        'create', 'F = bct.schema.field.make(M, data, "Name", "myfield")', ...
        'validate', 'bct.schema.field.validate(F)', ...
        'access', 'data = F.data.value; attrs = F.data.attributes'));

end

%% =================================================================
%% VALIDATION FUNCTIONS
%% =================================================================

function isValid = validateField(F, varargin)
    %VALIDATEFIELD Validate complete field structure
    %
    % Inputs:
    %   F - Field structure to validate
    %
    % Name-Value Arguments:
    %   Strict - true (default) to throw errors, false to return report
    %
    % Outputs:
    %   isValid - true if valid, false otherwise
    
    p = inputParser;
    p.addRequired('F');
    p.addParameter('Strict', true, @islogical);
    p.parse(F, varargin{:});
    
    strict = p.Results.Strict;
    
    try
        % Get schema
        spec = bct.schema.field();
        
        %% Check if struct
        if ~isstruct(F)
            error('bct:schema:field:InvalidType', ...
                'Field must be a struct');
        end
        
        %% Check for Attributes field (group-level metadata)
        if ~isfield(F, 'Attributes')
            error('bct:schema:field:MissingAttributes', ...
                'Field must have Attributes field');
        end
        
        % Validate base group attributes
        bct.schema.group.validate(F.Attributes);
        
        % Validate required field-specific attributes
        if ~isfield(F.Attributes, 'manifoldID')
            error('bct:schema:field:MissingManifoldID', ...
                'Field.Attributes must have manifoldID');
        end
        
        manifoldID = F.Attributes.manifoldID;
        if ~isstring(manifoldID) && ~ischar(manifoldID)
            error('bct:schema:field:InvalidManifoldID', ...
                'manifoldID must be string or char');
        end
        
        % Validate optional attributes if present
        if isfield(F.Attributes, 'numFields')
            if ~isnumeric(F.Attributes.numFields) || F.Attributes.numFields < 1
                error('bct:schema:field:InvalidNumFields', ...
                    'numFields must be positive integer');
            end
        end
        
        %% Find dataset fields (exclude Attributes)
        allFields = fieldnames(F);
        datasetFields = setdiff(allFields, {'Attributes'});
        
        if isempty(datasetFields)
            error('bct:schema:field:NoDatasets', ...
                'Field must contain at least one dataset');
        end
        
        numDatasets = numel(datasetFields);
        
        % Check numFields matches if specified
        if isfield(F.Attributes, 'numFields')
            if F.Attributes.numFields ~= numDatasets
                error('bct:schema:field:NumFieldsMismatch', ...
                    'numFields attribute (%d) does not match actual datasets (%d)', ...
                    F.Attributes.numFields, numDatasets);
            end
        end
        
        %% Validate each dataset
        for i = 1:numDatasets
            fieldName = datasetFields{i};
            dataset = F.(fieldName);
            
            % Validate dataset structure (must have .value and .attributes)
            bct.schema.dataset.validate(dataset);
            
            % Validate field-specific dataset attributes
            attrs = dataset.attributes;
            
            % Required: support
            if ~isfield(attrs, 'support')
                error('bct:schema:field:MissingSupport', ...
                    'Dataset "%s" missing required attribute: support', fieldName);
            end
            supportStr = string(attrs.support);
            if ~ismember(supportStr, spec.datasets.support.allowedValues)
                error('bct:schema:field:InvalidSupport', ...
                    'Dataset "%s" has invalid support: %s', fieldName, supportStr);
            end
            
            % Required: valueType
            if ~isfield(attrs, 'valueType')
                error('bct:schema:field:MissingValueType', ...
                    'Dataset "%s" missing required attribute: valueType', fieldName);
            end
            valueTypeStr = string(attrs.valueType);
            if ~ismember(valueTypeStr, spec.datasets.valueType.allowedValues)
                error('bct:schema:field:InvalidValueType', ...
                    'Dataset "%s" has invalid valueType: %s', fieldName, valueTypeStr);
            end
            
            % Validate value shape
            value = dataset.value;
            S = size(value, 1);  % Support cardinality
            
            % Determine if time-varying
            isTimeVarying = false;
            T = 1;
            
            switch valueTypeStr
                case {"scalar", "complexScalar"}
                    if size(value, 2) > 1
                        isTimeVarying = true;
                        T = size(value, 2);
                    end
                case {"vector3", "tangent2", "complexVector3"}
                    if ndims(value) == 3
                        isTimeVarying = true;
                        T = size(value, 3);
                    end
            end
            
            % Check shape matches valueType
            if isTimeVarying
                expectedShape = spec.shapes.(valueTypeStr).timeSeries(S, T);
            else
                expectedShape = spec.shapes.(valueTypeStr).static(S);
            end
            
            if ~isequal(size(value), expectedShape)
                error('bct:schema:field:InvalidShape', ...
                    'Dataset "%s" value shape [%s] does not match expected [%s]', ...
                    fieldName, sprintf('%d×', size(value)), sprintf('%d×', expectedShape));
            end
            
            % Check isTimeVarying attribute consistency
            if isfield(attrs, 'isTimeVarying')
                if attrs.isTimeVarying ~= isTimeVarying
                    error('bct:schema:field:TimeVaryingMismatch', ...
                        'Dataset "%s" isTimeVarying attribute does not match value shape', ...
                        fieldName);
                end
            end
            
            % Validate time metadata for time-varying fields
            if isTimeVarying
                if ~isfield(attrs, 'time')
                    warning('bct:schema:field:MissingTime', ...
                        'Dataset "%s" is time-varying but missing time metadata', fieldName);
                else
                    timeStruct = attrs.time;
                    if ~isfield(timeStruct, 'nSamples')
                        error('bct:schema:field:MissingNSamples', ...
                            'Dataset "%s" time metadata missing nSamples', fieldName);
                    end
                    if timeStruct.nSamples ~= T
                        error('bct:schema:field:NSamplesMismatch', ...
                            'Dataset "%s" nSamples (%d) does not match value shape (%d)', ...
                            fieldName, timeStruct.nSamples, T);
                    end
                end
            end
            
            % Validate frame for tangent2 fields
            if valueTypeStr == "tangent2"
                if ~isfield(attrs, 'frame')
                    error('bct:schema:field:MissingFrame', ...
                        'Dataset "%s" with valueType tangent2 requires frame', fieldName);
                end
                frame = attrs.frame;
                if ~isfield(frame, 'domain') || ~isfield(frame, 'e1') || ~isfield(frame, 'e2')
                    error('bct:schema:field:InvalidFrame', ...
                        'Dataset "%s" frame must have domain, e1, e2', fieldName);
                end
                
                % Validate frame basis shapes
                if ~isequal(size(frame.e1), [S, 3])
                    error('bct:schema:field:InvalidFrameBasis', ...
                        'Dataset "%s" frame.e1 must be [%d×3]', fieldName, S);
                end
                if ~isequal(size(frame.e2), [S, 3])
                    error('bct:schema:field:InvalidFrameBasis', ...
                        'Dataset "%s" frame.e2 must be [%d×3]', fieldName, S);
                end
            end
            
            % Validate complex type
            switch valueTypeStr
                case {"complexScalar", "complexVector3"}
                    if ~iscomplex(value)
                        warning('bct:schema:field:NotComplex', ...
                            'Dataset "%s" valueType is complex but value is real', fieldName);
                    end
            end
        end
        
        %% Validation passed
        isValid = true;
        
    catch ME
        if strict
            rethrow(ME);
        end
        warning('bct:schema:field:ValidationFailed', ...
            'Field validation failed: %s', ME.message);
        isValid = false;
    end
end

function F = makeField(manifold, value, varargin)
    %MAKEFIELD Create schema-compliant field structure
    %
    % Syntax:
    %   F = bct.schema.field.make(manifold, value)
    %   F = bct.schema.field.make(manifold, value, Name=Value)
    %
    % Inputs:
    %   manifold - bct.Manifold object
    %   value    - Numeric array [S×...] or [S×...×T]
    %
    % Name-Value Arguments:
    %   Name        - Dataset name (default: 'data')
    %   Support     - Support type (default: inferred from size)
    %   ValueType   - Value type (default: inferred from shape)
    %   Time        - Time metadata struct
    %   Frame       - Tangent frame for tangent2 fields
    %   Metric      - Physical units and dimensions
    %   Source      - Data source/provenance
    %   Description - Human-readable description
    %
    % Examples:
    %   % Simple scalar field
    %   M = bct.Manifold(V, F);
    %   data = randn(M.numVertices(), 1);
    %   F = bct.schema.field.make(M, data);
    %
    %   % Time-varying with metadata
    %   data = randn(M.numVertices(), 100);
    %   time = struct('nSamples', 100, 'fs', 100, 'units', 's');
    %   F = bct.schema.field.make(M, data, 'Time', time, 'Name', 'timeseries');
    
    p = inputParser;
    p.addRequired('manifold');
    p.addRequired('value', @isnumeric);
    p.addParameter('Name', 'data', @(x) ischar(x) || isstring(x));
    p.addParameter('Support', "", @(x) ischar(x) || isstring(x));
    p.addParameter('ValueType', "", @(x) ischar(x) || isstring(x));
    p.addParameter('Time', struct.empty, @isstruct);
    p.addParameter('Frame', struct.empty, @isstruct);
    p.addParameter('Metric', struct.empty, @isstruct);
    p.addParameter('Source', "", @(x) ischar(x) || isstring(x));
    p.addParameter('Description', "", @(x) ischar(x) || isstring(x));
    p.parse(manifold, value, varargin{:});
    
    datasetName = char(p.Results.Name);
    supportStr = string(p.Results.Support);
    valueTypeStr = string(p.Results.ValueType);
    
    % Get manifold ID
    if isa(manifold, 'bct.Manifold')
        if isfield(manifold.Attributes, 'ID') && ~isempty(manifold.Attributes.ID)
            manifoldID = string(manifold.Attributes.ID);
        else
            manifoldID = "unknown";
        end
    else
        error('bct:schema:field:InvalidManifold', ...
            'manifold must be bct.Manifold object');
    end
    
    % Infer support if not provided
    S = size(value, 1);
    if supportStr == ""
        if S == manifold.numVertices()
            supportStr = "vertex";
        elseif S == manifold.numFaces()
            supportStr = "face";
        elseif S == size(manifold.Edges, 1)
            supportStr = "edge";
        else
            error('bct:schema:field:CannotInferSupport', ...
                'Cannot infer support from value size %d', S);
        end
    end
    
    % Infer valueType if not provided
    if valueTypeStr == ""
        valueShape = size(value);
        if numel(valueShape) == 2
            if valueShape(2) == 1
                valueTypeStr = "scalar";
            elseif valueShape(2) == 2
                valueTypeStr = "tangent2";
            elseif valueShape(2) == 3
                valueTypeStr = "vector3";
            else
                % Time-varying scalar
                valueTypeStr = "scalar";
            end
        elseif numel(valueShape) == 3
            if valueShape(2) == 2
                valueTypeStr = "tangent2";
            elseif valueShape(2) == 3
                valueTypeStr = "vector3";
            else
                error('bct:schema:field:CannotInferValueType', ...
                    'Cannot infer valueType from shape [%s]', sprintf('%d×', valueShape));
            end
        end
    end
    
    % Detect time-varying
    isTimeVarying = false;
    T = 1;
    switch valueTypeStr
        case {"scalar", "complexScalar"}
            if size(value, 2) > 1
                isTimeVarying = true;
                T = size(value, 2);
            end
        case {"vector3", "tangent2", "complexVector3"}
            if ndims(value) == 3
                isTimeVarying = true;
                T = size(value, 3);
            end
    end
    
    % Create dataset using bct.schema.dataset.make
    datasetPath = sprintf('/field/%s', datasetName);
    datasetAttrs = bct.schema.dataset.make(value, ...
        'Name', datasetName, ...
        'Path', datasetPath, ...
        'Description', sprintf('%s %s field', supportStr, valueTypeStr), ...
        'Support', char(supportStr), ...
        'ComputedBy', 'bct.schema.field.make');
    
    % Add field-specific attributes
    datasetAttrs.attributes.support = char(supportStr);
    datasetAttrs.attributes.valueType = char(valueTypeStr);
    datasetAttrs.attributes.isTimeVarying = isTimeVarying;
    
    % Add time metadata if time-varying
    if isTimeVarying
        if ~isempty(p.Results.Time)
            timeStruct = p.Results.Time;
            if ~isfield(timeStruct, 'nSamples')
                timeStruct.nSamples = T;
            end
        else
            timeStruct = struct('nSamples', T, 'units', 's');
        end
        datasetAttrs.attributes.time = timeStruct;
    end
    
    % Add frame if provided or required
    if ~isempty(p.Results.Frame)
        datasetAttrs.attributes.frame = p.Results.Frame;
    elseif valueTypeStr == "tangent2"
        error('bct:schema:field:MissingFrame', ...
            'Frame required for tangent2 valueType');
    end
    
    % Add metric
    if ~isempty(p.Results.Metric)
        datasetAttrs.attributes.metric = p.Results.Metric;
    else
        datasetAttrs.attributes.metric = struct('units', '1', 'scale', 1.0);
    end
    
    % Create field group structure
    F = struct();
    
    % Add dataset
    F.(datasetName) = datasetAttrs;
    
    % Create group-level attributes
    F.Attributes = bct.schema.group.make(...
        'Path', '/field', ...
        'Schema', 'bct.field@1.1', ...
        'Package', 'bct');
    
    % Add field-specific group attributes
    F.Attributes.manifoldID = char(manifoldID);
    F.Attributes.numFields = uint32(1);
    
    if p.Results.Source ~= ""
        F.Attributes.Source = char(p.Results.Source);
    end
    if p.Results.Description ~= ""
        F.Attributes.Description = char(p.Results.Description);
    end
    
    % Validate
    bct.schema.field.validate(F);
end
