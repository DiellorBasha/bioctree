function dataNormalized = normalize(spec, data)
%NORMALIZE Apply normalization rules to data according to schema
%
% Applies type conversions and normalization transformations defined
% in the schema specification. This ensures data is in the canonical
% form expected by bct.Manifold (e.g., Faces as uint32, Vertices as double).
%
% Syntax:
%   dataNormalized = bct.manifold.schema.normalize(spec, data)
%
% Inputs:
%   spec - Schema specification (from bct.manifold.schema.manifold)
%   data - Structure with fields to normalize
%
% Outputs:
%   dataNormalized - Structure with normalized fields
%                    - Vertices → double
%                    - Faces → uint32
%                    - Edges → uint32
%
% Normalization Rules:
%   Each field's normalization function is applied if present.
%   Normalization typically includes:
%   - Type casting (e.g., double → uint32 for indices)
%   - Value clamping or rounding
%   - Format standardization
%
% Examples:
%   % Normalize data before creating Manifold
%   spec = bct.manifold.schema.manifold();
%   data = struct('Vertices', V, 'Faces', F);
%   data = bct.manifold.schema.normalize(spec, data);
%   M = bct.Manifold(data);
%
%   % Check types after normalization
%   class(data.Vertices)  % 'double'
%   class(data.Faces)     % 'uint32'
%
% See also: bct.manifold.schema.manifold, bct.manifold.schema.validate

arguments
    spec (1,1) struct
    data (1,1) struct
end

% Initialize output
dataNormalized = data;

% Handle two-section schema (mesh + meta)
if isfield(spec, 'mesh') && isfield(spec, 'meta')
    dataNormalized = normalizeSection(spec.mesh, dataNormalized);
    dataNormalized = normalizeSection(spec.meta, dataNormalized);
    return;
end

% Handle single-section schema (legacy)
dataNormalized = normalizeSection(spec, dataNormalized);

end

%% =================================================================
%% SECTION NORMALIZATION HELPER
%% =================================================================

function data = normalizeSection(section, data)
%NORMALIZESECTION Apply normalization rules from a schema section

% Get fields from section
if isfield(section, 'fields')
    fields = section.fields;
else
    fields = section;  % Legacy
end

% Extract field names
fieldNames = fieldnames(fields);

% Apply normalization to each field
for i = 1:numel(fieldNames)
    fieldName = fieldNames{i};
    fieldSpec = fields.(fieldName);
    
    % Apply default value if field is missing
    if ~isfield(data, fieldName) && isfield(fieldSpec, 'default')
        data.(fieldName) = fieldSpec.default;
        continue;
    end
    
    % Skip if field not present (optional without default)
    if ~isfield(data, fieldName)
        continue;
    end
    
    value = data.(fieldName);
    
    % Apply normalization function if defined
    if isfield(fieldSpec, 'normalize') && ~isempty(fieldSpec.normalize)
        try
            normalizedValue = fieldSpec.normalize(value);
            data.(fieldName) = normalizedValue;
        catch ME
            warning('bct:schema:normalizeFailed', ...
                'Failed to normalize field "%s": %s', fieldName, ME.message);
        end
    end
end

end
