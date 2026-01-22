function [arrays, schema] = flattenStruct(s, prefix)
%FLATTENSTRUCT Recursively flatten a nested structure for binary export
%
% Syntax:
%   [arrays, schema] = bct.file.write.flattenStruct(s)
%   [arrays, schema] = bct.file.write.flattenStruct(s, prefix)
%
% Inputs:
%   s      - Structure to flatten (can have nested structures)
%   prefix - Path prefix for nested fields (default: '')
%
% Outputs:
%   arrays - Cell array of structs, each with fields:
%            .path  - Full field path (e.g., 'geometry.face.areas')
%            .data  - Flattened numeric array data
%            .dtype - Data type string
%            .shape - Original array shape
%   schema - Nested structure describing the data organization
%
% Description:
%   Recursively traverses a structure and extracts all numeric arrays.
%   String fields are preserved in schema but not exported to binary.
%   Nested structures are flattened with dot-separated paths.
%
% Examples:
%   s.Vertices = rand(100, 3);
%   s.geometry.face.areas = rand(200, 1);
%   [arrays, schema] = bct.file.write.flattenStruct(s);

if nargin < 2
    prefix = '';
end

arrays = {};
schema = struct();

fields = fieldnames(s);

for i = 1:numel(fields)
    field = fields{i};
    value = s.(field);
    
    % Build full path
    if isempty(prefix)
        fullPath = field;
    else
        fullPath = [prefix '.' field];
    end
    
    if isstruct(value)
        % Recursively process nested structure
        [nestedArrays, nestedSchema] = bct.file.write.flattenStruct(value, fullPath);
        arrays = [arrays; nestedArrays]; %#ok<AGROW>
        schema.(field) = nestedSchema;
        
    elseif isnumeric(value) || islogical(value)
        % Skip sparse arrays (too large for binary export)
        if issparse(value)
            schema.(field) = struct(...
                'type', 'sparse', ...
                'dtype', class(value), ...
                'shape', size(value), ...
                'nnz', nnz(value), ...
                'note', 'Sparse arrays not exported to binary');
            continue;
        end
        
        % Extract numeric/logical array
        originalShape = size(value);
        
        % Convert logical to uint8 for storage
        if islogical(value)
            value = uint8(value);
        end
        
        % Flatten to column vector
        flatData = reshape(value, [], 1);
        
        % Infer data type
        dtype = bct.file.write.inferDtype(value);
        
        % Create array entry
        entry = struct();
        entry.path = fullPath;
        entry.data = flatData;
        entry.dtype = dtype;
        entry.shape = originalShape;
        
        arrays{end+1, 1} = entry; %#ok<AGROW>
        
        % Add to schema
        schema.(field) = struct(...
            'dtype', dtype, ...
            'shape', originalShape, ...
            'count', numel(value));
        
    elseif isstring(value) || ischar(value)
        % Preserve string/char in schema only
        schema.(field) = struct(...
            'type', 'string', ...
            'value', string(value));
        
    elseif isa(value, 'dictionary')
        % Handle dictionary type
        schema.(field) = struct(...
            'type', 'dictionary', ...
            'note', 'Dictionary type not exported to binary');
        
    else
        % Unknown type, add note to schema
        schema.(field) = struct(...
            'type', class(value), ...
            'note', 'Type not exported to binary');
    end
end

end
