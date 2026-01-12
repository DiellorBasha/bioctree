function F = make(varargin)
%MAKE Create validated Field struct
%
% F = MAKE(Name, Value, ...) creates Field struct with specified properties.
%
% Required Name-Value Arguments:
%   support    - Support type: 'vertex', 'face', 'edge', 'halfedge', 'dualFace', 'dualVertex'
%   valueType  - Value type: 'scalar', 'vector3', 'tangent2', 'complexScalar', 'complexVector3'
%   value      - Numeric array with shape matching valueType and support
%
% Optional Name-Value Arguments:
%   meshId          - Mesh identifier (char/string)
%   time            - Time struct with fields: t0, dt, unit, samples
%   frame           - Frame basis [S×2×3] or [S×2×3×T] (required for tangent2)
%   metadata        - Arbitrary metadata struct
%   schemaVersion   - Schema version (default: 'bct.field@1')
%
% The function normalizes inputs, validates against schema, and returns
% a valid Field struct. Throws descriptive errors if validation fails.
%
% Examples:
%   % Static scalar vertex field
%   F = bct.field.make('support', 'vertex', ...
%                       'valueType', 'scalar', ...
%                       'value', rand(1000, 1));
%
%   % Time-varying vector face field
%   F = bct.field.make('support', 'face', ...
%                       'valueType', 'vector3', ...
%                       'value', rand(500, 3, 100), ...
%                       'time', struct('t0', 0, 'dt', 0.01, 'unit', 's'));
%
%   % Tangent field with frame
%   tangents = rand(1000, 2);
%   frames = rand(1000, 2, 3);
%   F = bct.field.make('support', 'vertex', ...
%                       'valueType', 'tangent2', ...
%                       'value', tangents, ...
%                       'frame', frames);

arguments (Repeating)
    varargin
end

% Parse name-value pairs
p = inputParser;
p.addParameter('support', '', @(x) ischar(x) || isstring(x));
p.addParameter('valueType', '', @(x) ischar(x) || isstring(x));
p.addParameter('value', [], @isnumeric);
p.addParameter('meshId', '', @(x) ischar(x) || isstring(x));
p.addParameter('time', struct([]), @isstruct);
p.addParameter('frame', [], @isnumeric);
p.addParameter('metadata', struct(), @isstruct);
p.addParameter('schemaVersion', 'bct.field@1', @(x) ischar(x) || isstring(x));

p.parse(varargin{:});
args = p.Results;

% Check required fields
if isempty(args.support)
    error('bct:Field:MissingArgument', 'support is required');
end
if isempty(args.valueType)
    error('bct:Field:MissingArgument', 'valueType is required');
end
if isempty(args.value)
    error('bct:Field:MissingArgument', 'value is required');
end

% Initialize Field struct
F = struct();
F.schemaVersion = char(args.schemaVersion);
F.support = char(args.support);
F.valueType = char(args.valueType);
F.value = args.value;

% Get schema for validation
schema = bct.field.schema();

% Validate support
validateSupport_(F.support, schema);

% Validate valueType
valueTypeStr = string(F.valueType);
if ~ismember(valueTypeStr, schema.valueTypes)
    error('bct:Field:InvalidValueType', ...
        'Invalid valueType: %s (must be one of: %s)', ...
        F.valueType, strjoin(schema.valueTypes, ', '));
end

% Determine support size from value
supportSize = size(F.value, 1);

% Validate value shape
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

% Handle time field
if isTimeVarying
    if ~isempty(args.time)
        % Normalize and validate provided time
        F.time = normalizeTime_(args.time, numTimeSamples);
    else
        % Create default time struct
        F.time = struct('t0', 0.0, ...
                       'dt', 1.0, ...
                       'unit', 's', ...
                       'samples', 0:numTimeSamples-1);
    end
else
    % Static field: don't add time field even if provided
    if ~isempty(args.time)
        warning('bct:Field:UnusedTimeField', ...
            'time field provided but value is not time-varying; ignoring');
    end
end

% Handle frame field (required for tangent2)
if valueTypeStr == "tangent2"
    if isempty(args.frame)
        error('bct:Field:MissingFrame', ...
            'frame is required for tangent2 valueType');
    end
    
    % Validate frame shape
    if isTimeVarying
        expectedShape = [supportSize, 2, 3, numTimeSamples];
    else
        expectedShape = [supportSize, 2, 3];
    end
    
    if ~isequal(size(args.frame), expectedShape)
        error('bct:Field:InvalidFrame', ...
            'frame shape [%s] must match [%s]', ...
            sprintf('%d×', size(args.frame)), sprintf('%d×', expectedShape));
    end
    
    F.frame = args.frame;
elseif ~isempty(args.frame)
    warning('bct:Field:UnusedFrame', ...
        'frame provided but valueType is not tangent2; ignoring');
end

% Add optional fields if provided
if ~isempty(args.meshId)
    F.meshId = char(args.meshId);
end

if ~isempty(fieldnames(args.metadata))
    F.metadata = args.metadata;
end

% Final validation
bct.field.validate(F);

end
