function validate(F, varargin)
%VALIDATE Validate Field struct against schema
%
% VALIDATE(F) validates Field struct F against bct.field.schema
%
% VALIDATE(F, M) additionally validates meshId consistency with Manifold M
%
% Throws descriptive errors if validation fails with identifiers:
%   bct:Field:MissingField       - Required field missing
%   bct:Field:InvalidSchemaVersion - Unsupported schema version
%   bct:Field:InvalidSupport     - Invalid support type
%   bct:Field:InvalidValueType   - Invalid valueType
%   bct:Field:InvalidValueShape  - Value shape inconsistent with schema
%   bct:Field:MismatchedMeshId   - meshId doesn't match Manifold
%   bct:Field:MissingFrame       - Frame required but missing for tangent2
%   bct:Field:InvalidFrame       - Frame shape inconsistent
%
% Examples:
%   % Validate without Manifold check
%   bct.field.validate(F);
%
%   % Validate with Manifold consistency check
%   M = bct.Manifold(...);
%   bct.field.validate(F, M);

arguments
    F struct
end

arguments (Repeating)
    varargin
end

% Parse optional Manifold
M = [];
if ~isempty(varargin)
    M = varargin{1};
    if ~isa(M, 'bct.Manifold')
        error('bct:Field:InvalidArgument', ...
            'Second argument must be bct.Manifold');
    end
end

% Get schema
schema = bct.field.schema();

% Check required fields
requiredFields = ["schemaVersion", "support", "valueType", "value"];
for i = 1:length(requiredFields)
    if ~isfield(F, requiredFields(i))
        error('bct:Field:MissingField', ...
            'Field missing required field: %s', requiredFields(i));
    end
end

% Validate schemaVersion
if ~ischar(F.schemaVersion) && ~isstring(F.schemaVersion)
    error('bct:Field:InvalidSchemaVersion', ...
        'schemaVersion must be char or string');
end
schemaVer = string(F.schemaVersion);
if schemaVer ~= schema.version
    error('bct:Field:InvalidSchemaVersion', ...
        'Unsupported schema version: %s (expected %s)', ...
        schemaVer, schema.version);
end

% Validate support
validateSupport_(F.support, schema);

% Get support size
if ~isempty(M)
    supportSize = bct.field.sizeOfSupport(F.support, M);
else
    % Cannot validate size without Manifold, just check shape consistency
    supportSize = size(F.value, 1);
end

% Validate valueType
valueTypeStr = string(F.valueType);
if ~ismember(valueTypeStr, schema.valueTypes)
    error('bct:Field:InvalidValueType', ...
        'Invalid valueType: %s (must be one of: %s)', ...
        F.valueType, strjoin(schema.valueTypes, ', '));
end

% Validate value shape and type
validateValue_(F.value, valueTypeStr, string(F.support), supportSize, schema);

% Determine if time-varying
isTimeVarying = false;
numTimeSamples = 1;

switch valueTypeStr
    case {"scalar", "complexScalar"}
        if size(F.value, 2) > 1
            isTimeVarying = true;
            numTimeSamples = size(F.value, 2);
        end
    case {"vector3", "tangent2", "complexVector3"}
        if ndims(F.value) == 3
            isTimeVarying = true;
            numTimeSamples = size(F.value, 3);
        end
end

% Validate time if present
if isfield(F, 'time')
    if ~isTimeVarying
        warning('bct:Field:UnusedTimeField', ...
            'time field present but value is not time-varying');
    else
        validateTime_(F.time, numTimeSamples);
    end
elseif isTimeVarying
    warning('bct:Field:MissingTimeField', ...
        'value is time-varying but time field missing');
end

% Validate frame if present (required for tangent2)
if valueTypeStr == "tangent2"
    if ~isfield(F, 'frame')
        error('bct:Field:MissingFrame', ...
            'tangent2 valueType requires frame field');
    end
    
    % Validate frame shape: [S×2×3] or [S×2×3×T]
    if isTimeVarying
        expectedShape = [supportSize, 2, 3, numTimeSamples];
        if ~isequal(size(F.frame), expectedShape)
            error('bct:Field:InvalidFrame', ...
                'frame shape [%s] must match [S×2×3×T] = [%s]', ...
                sprintf('%d×', size(F.frame)), sprintf('%d×', expectedShape));
        end
    else
        expectedShape = [supportSize, 2, 3];
        if ~isequal(size(F.frame), expectedShape)
            error('bct:Field:InvalidFrame', ...
                'frame shape [%s] must match [S×2×3] = [%s]', ...
                sprintf('%d×', size(F.frame)), sprintf('%d×', expectedShape));
        end
    end
end

% Validate meshId if Manifold provided
if ~isempty(M)
    if isfield(F, 'meshId')
        if ~strcmp(F.meshId, M.ID)
            error('bct:Field:MismatchedMeshId', ...
                'Field meshId "%s" does not match Manifold.ID "%s"', ...
                F.meshId, M.ID);
        end
    end
end

% Validate metadata if present (just check it's a struct)
if isfield(F, 'metadata')
    if ~isstruct(F.metadata)
        error('bct:Field:InvalidMetadata', ...
            'metadata must be a struct');
    end
end

% Validate metric if present (optional field)
if isfield(F, 'metric') && ~isempty(F.metric)
    bct.field.metric.validate(F.metric);
end

end
