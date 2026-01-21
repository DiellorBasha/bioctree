function [isValid, report] = validateSchema(data, schema)
%VALIDATESCHEMA Validate a vertex geometry structure against schema
%
% Syntax:
%   isValid = bct.manifold.geometry.vertex.validateSchema(data, schema)
%   [isValid, report] = bct.manifold.geometry.vertex.validateSchema(data, schema)
%
% Inputs:
%   data   - Structure to validate (output from bct.manifold.geometry.vertex)
%   schema - Schema structure (from bct.manifold.geometry.vertex.schema)
%            If omitted, loads default schema automatically
%
% Outputs:
%   isValid - Logical, true if data conforms to schema
%   report  - Structure with validation details:
%             .passed       - Logical, same as isValid
%             .errors       - Cell array of error messages
%             .warnings     - Cell array of warning messages
%             .missingFields - Cell array of missing required fields
%             .extraFields  - Cell array of unexpected fields
%             .fieldStatus  - Structure with per-field validation results
%
% Description:
%   Validates that a vertex geometry structure conforms to the expected
%   schema. Checks:
%   - Presence of required fields
%   - Data types match specification
%   - Array dimensions are compatible
%   - No unexpected extra fields (warnings only)
%
%   Useful for debugging, testing, and ensuring data integrity before
%   serialization or further processing.
%
% Examples:
%   % Validate computed geometry
%   M = bct.Manifold(V, F);
%   vg = bct.manifold.geometry.vertex(M);
%   [isValid, report] = bct.manifold.geometry.vertex.validateSchema(vg);
%   
%   if ~isValid
%       disp('Validation errors:');
%       disp(report.errors);
%   end
%
%   % Validate with custom schema
%   s = bct.manifold.geometry.vertex.schema();
%   [isValid, report] = bct.manifold.geometry.vertex.validateSchema(vg, s);
%
% See also: bct.manifold.geometry.vertex.schema, bct.manifold.geometry.vertex

% Handle default schema
if nargin < 2 || isempty(schema)
    schema = bct.manifold.geometry.vertex.schema();
end

% Initialize report
report = struct();
report.passed = true;
report.errors = {};
report.warnings = {};
report.missingFields = {};
report.extraFields = {};
report.fieldStatus = struct();

% Validate input is a structure
if ~isstruct(data)
    report.passed = false;
    report.errors{end+1} = sprintf('Expected struct, got %s', class(data));
    isValid = false;
    return;
end

% Get actual field names
actualFields = fieldnames(data);

% Check each expected field
for i = 1:numel(schema.fields)
    field = schema.fields{i};
    fieldName = field.name;
    
    % Check if field exists
    if ~isfield(data, fieldName)
        if field.required
            report.passed = false;
            report.errors{end+1} = sprintf('Missing required field: %s', fieldName);
            report.missingFields{end+1} = fieldName;
            report.fieldStatus.(fieldName) = struct('present', false, 'valid', false);
        else
            report.warnings{end+1} = sprintf('Optional field missing: %s', fieldName);
            report.fieldStatus.(fieldName) = struct('present', false, 'valid', true);
        end
        continue;
    end
    
    % Field exists, validate it
    fieldData = data.(fieldName);
    fieldValid = true;
    
    % Check type
    actualType = class(fieldData);
    if ~strcmp(actualType, field.type)
        % Allow some type flexibility (e.g., single vs double)
        if ~((strcmp(field.type, 'double') && strcmp(actualType, 'single')) || ...
             (strcmp(field.type, 'single') && strcmp(actualType, 'double')))
            report.passed = false;
            fieldValid = false;
            report.errors{end+1} = sprintf('%s: Expected type %s, got %s', ...
                fieldName, field.type, actualType);
        end
    end
    
    % Check dimensions (for numeric arrays)
    if isnumeric(fieldData) && ~strcmp(field.shape, 'scalar')
        dims = size(fieldData);
        
        % Parse expected shape
        if contains(field.shape, 'Nv')
            % Expected Nv×3 format
            if length(dims) ~= 2
                report.passed = false;
                fieldValid = false;
                report.errors{end+1} = sprintf('%s: Expected 2D array, got %dD', ...
                    fieldName, length(dims));
            elseif dims(2) ~= 3
                report.passed = false;
                fieldValid = false;
                report.errors{end+1} = sprintf('%s: Expected Nv×3 shape, got %d×%d', ...
                    fieldName, dims(1), dims(2));
            end
            
            % Check consistency of Nv across fields
            if i > 2  % Skip header, check against normals
                normalsSize = size(data.normals, 1);
                if dims(1) ~= normalsSize
                    report.passed = false;
                    fieldValid = false;
                    report.errors{end+1} = sprintf('%s: Inconsistent Nv (%d vs %d in normals)', ...
                        fieldName, dims(1), normalsSize);
                end
            end
        end
    end
    
    % Check struct subfields (for header)
    if strcmp(field.type, 'struct') && isfield(field, 'subfields')
        for j = 1:numel(field.subfields)
            subfieldName = field.subfields{j};
            if ~isfield(fieldData, subfieldName)
                report.warnings{end+1} = sprintf('%s.%s: Expected subfield missing', ...
                    fieldName, subfieldName);
            end
        end
    end
    
    % Record field status
    report.fieldStatus.(fieldName) = struct('present', true, 'valid', fieldValid);
end

% Check for extra fields (warnings only)
expectedFieldNames = cellfun(@(f) f.name, schema.fields, 'UniformOutput', false);
for i = 1:numel(actualFields)
    if ~ismember(actualFields{i}, expectedFieldNames)
        report.warnings{end+1} = sprintf('Unexpected field: %s', actualFields{i});
        report.extraFields{end+1} = actualFields{i};
    end
end

% Final validation status
isValid = report.passed;

end
