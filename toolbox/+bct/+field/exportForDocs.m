function exportForDocs(F, fileName, options)
%EXPORTFORDOCS Export field data for documentation viewer
%
% Exports field data in JSON format for use with the mkdocs three.js
% viewer component. The JSON format is designed to be easily consumed
% by the viewer's colormap system.
%
% Syntax:
%   bct.field.exportForDocs(F, fileName)
%   bct.field.exportForDocs(F, fileName, Name=Value)
%
% Inputs:
%   F        - bct.Field object or field struct
%   fileName - Output file path (with .json extension)
%
% Name-Value Arguments:
%   OutputDir      - Output directory (default: 'docs/docs/assets/data')
%   TimeIndex      - For time-varying fields, which time index to export (default: 1)
%   ExportAllTimes - Export all time steps (default: false)
%   Normalize      - Normalize values to [0,1] range (default: false)
%
% Outputs:
%   Creates JSON file with structure:
%   {
%     "metadata": {
%       "manifoldId": "...",
%       "support": "vertex"|"face"|"edge",
%       "valueType": "scalar"|"vector3"|"tangent2",
%       "isTimeVarying": true/false,
%       "numSamples": N,
%       "format": "bioctree-field-v1"
%     },
%     "values": [...],  // field values
%     "statistics": {
%       "min": ...,
%       "max": ...,
%       "mean": ...,
%       "std": ...
%     },
%     "time": {  // optional, for time-varying fields
%       "fs": 100,
%       "timeIndex": 1,
%       "totalTimeSteps": T
%     }
%   }
%
% Examples:
%   % Export scalar field
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   field = randn(M.numVertices(), 1);
%   F = bct.Field(M, field);
%   bct.field.exportForDocs(F, 'random_field.json');
%
%   % Export specific time point of time-varying field
%   field_tv = randn(M.numVertices(), 100);
%   F_tv = bct.Field(M, field_tv, Time=struct('fs', 100));
%   bct.field.exportForDocs(F_tv, 'field_t50.json', TimeIndex=50);
%
%   % Export with normalization
%   bct.field.exportForDocs(F, 'field_norm.json', Normalize=true);
%
% See also: bct.manifold.exportForDocs, bct.Field

arguments
    F  % bct.Field or struct
    fileName string
    options.OutputDir string = "docs/docs/assets/data"
    options.TimeIndex (1,1) double = 1
    options.ExportAllTimes (1,1) logical = false
    options.Normalize (1,1) logical = false
end

% Convert Field object to struct if necessary
if isa(F, 'bct.Field')
    fieldStruct = F.toStruct();
else
    fieldStruct = F;
    bct.field.validate(fieldStruct);
end

% Ensure output directory exists
if ~isfolder(options.OutputDir)
    mkdir(options.OutputDir);
end

% Construct full path
if ~endsWith(fileName, '.json')
    fileName = fileName + ".json";
end
outputPath = fullfile(options.OutputDir, fileName);

fprintf('Exporting field for documentation viewer...\n');
fprintf('  Output: %s\n', outputPath);

% =========================================================================
% Build JSON data structure
% =========================================================================
data = struct();

% Metadata
data.metadata = struct();
data.metadata.manifoldId = char(fieldStruct.meshId);
data.metadata.support = char(fieldStruct.support);
data.metadata.valueType = char(fieldStruct.valueType);
data.metadata.format = 'bioctree-field-v1';
data.metadata.exportDate = datestr(now, 'yyyy-mm-dd HH:MM:SS');

% Check if time-varying
isTimeVarying = bct.field.isTimeVarying(fieldStruct);
data.metadata.isTimeVarying = isTimeVarying;

% Extract values
if isTimeVarying && ~options.ExportAllTimes
    % Extract single time point
    values = extractTimePoint(fieldStruct, options.TimeIndex);
    data.metadata.numSamples = size(values, 1);
    
    % Add time metadata
    if isfield(fieldStruct, 'time') && ~isempty(fieldStruct.time)
        data.time = struct();
        if isfield(fieldStruct.time, 'fs')
            data.time.fs = fieldStruct.time.fs;
        end
        data.time.timeIndex = options.TimeIndex;
        data.time.totalTimeSteps = getNumTimeSteps(fieldStruct);
    end
elseif isTimeVarying && options.ExportAllTimes
    % Export all time points
    values = fieldStruct.value;
    data.metadata.numSamples = size(values, 1);
    data.metadata.exportAllTimes = true;
    
    if isfield(fieldStruct, 'time') && ~isempty(fieldStruct.time)
        data.time = fieldStruct.time;
        data.time.totalTimeSteps = getNumTimeSteps(fieldStruct);
    end
else
    % Static field
    values = fieldStruct.value;
    data.metadata.numSamples = size(values, 1);
end

% Normalize if requested
if options.Normalize
    if strcmp(data.metadata.valueType, 'scalar') || ...
       strcmp(data.metadata.valueType, 'complexScalar')
        values = normalizeScalar(values);
        data.metadata.normalized = true;
    else
        warning('Normalization only supported for scalar fields. Skipping.');
    end
end

% Store values
data.values = values;

% Compute statistics
if strcmp(data.metadata.valueType, 'scalar')
    data.statistics = struct();
    data.statistics.min = min(values(:));
    data.statistics.max = max(values(:));
    data.statistics.mean = mean(values(:));
    data.statistics.std = std(values(:));
    data.statistics.range = data.statistics.max - data.statistics.min;
end

% =========================================================================
% Write JSON file
% =========================================================================
fprintf('  Writing JSON...\n');

jsonStr = jsonencode(data);

fid = fopen(outputPath, 'w');
if fid == -1
    error('bct:field:exportForDocs:CannotWriteFile', ...
        'Cannot write to file: %s', outputPath);
end
fprintf(fid, '%s', jsonStr);
fclose(fid);

fprintf('Export complete!\n');
fprintf('  File: %s (%.2f KB)\n', outputPath, length(jsonStr) / 1024);
fprintf('  Support: %s, ValueType: %s\n', ...
    data.metadata.support, data.metadata.valueType);
if isfield(data, 'statistics')
    fprintf('  Range: [%.3f, %.3f]\n', ...
        data.statistics.min, data.statistics.max);
end

end

% =========================================================================
% Helper functions
% =========================================================================

function values = extractTimePoint(fieldStruct, timeIdx)
    %EXTRACTTIMEPOINT Extract values at specific time index
    
    valueType = fieldStruct.valueType;
    allValues = fieldStruct.value;
    
    switch valueType
        case {'scalar', 'complexScalar'}
            % [S×T] → extract column
            if timeIdx > size(allValues, 2)
                error('Time index %d exceeds available time steps (%d)', ...
                    timeIdx, size(allValues, 2));
            end
            values = allValues(:, timeIdx);
            
        case {'vector3', 'tangent2', 'complexVector3'}
            % [S×D×T] → extract time slice
            if timeIdx > size(allValues, 3)
                error('Time index %d exceeds available time steps (%d)', ...
                    timeIdx, size(allValues, 3));
            end
            values = allValues(:, :, timeIdx);
            
        otherwise
            error('Unknown value type: %s', valueType);
    end
end

function nSteps = getNumTimeSteps(fieldStruct)
    %GETNUMTIMESTEPS Get total number of time steps
    
    valueType = fieldStruct.valueType;
    sz = size(fieldStruct.value);
    
    switch valueType
        case {'scalar', 'complexScalar'}
            nSteps = sz(2);
        case {'vector3', 'tangent2', 'complexVector3'}
            nSteps = sz(3);
        otherwise
            nSteps = 1;
    end
end

function normalized = normalizeScalar(values)
    %NORMALIZESCALAR Normalize scalar values to [0, 1]
    
    minVal = min(values(:));
    maxVal = max(values(:));
    
    if maxVal == minVal
        normalized = zeros(size(values));
    else
        normalized = (values - minVal) / (maxVal - minVal);
    end
end
