function success = exportDerivedMaps(outPath, mapsStruct, varargin)
% EXPORTDERIVEDMAPS Export derived per-vertex maps for downstream applications
%
% success = exportDerivedMaps(outPath, mapsStruct) exports derived scalar
% maps and time series to files for use in other applications.
%
% success = exportDerivedMaps(outPath, mapsStruct, 'param', value, ...) 
% specifies additional parameters:
%   'Format'    - 'mat' (default), 'csv', 'nii', 'vtk' output format
%   'Precision' - 'single' or 'double' (default) for numeric precision
%   'Compress'  - true/false to compress output files (default: false)
%   'Metadata'  - struct with additional metadata to include
%   'Verbose'   - true/false for detailed output (default: false)
%
% Input:
%   outPath    - Output file path or directory
%   mapsStruct - Structure containing derived maps with fields:
%     .scalarMaps - Per-vertex scalar values (N x K matrix)
%     .mapNames   - Names for each scalar map (cell array, length K)
%     .timeSeries - Time-varying maps (N x T matrix, optional)  
%     .tvec       - Time vector (1 x T, optional)
%     .vertices   - Vertex coordinates (N x 3, optional)
%     .faces      - Face connectivity (F x 3, optional)
%
% Returns:
%   success - true if export completed successfully
%
% Example:
%   % Export gradient magnitude and TV maps
%   maps.scalarMaps = [gradMag, tvMap];
%   maps.mapNames = {'GradientMagnitude', 'TotalVariation'};
%   maps.vertices = S.V;
%   maps.faces = S.F;
%   meg_gsp.io.exportDerivedMaps('output/derived_maps.mat', maps);
%
%   % Export time series with metadata
%   maps.timeSeries = filteredSeries;
%   maps.tvec = S.tvec;
%   metadata.processingDate = datestr(now);
%   metadata.filterType = 'joint_lowpass';
%   meg_gsp.io.exportDerivedMaps('output/', maps, 'Metadata', metadata);
%
% See also: loadBrainstormSource, meg_gsp.viz.plotCortexMap

% Input validation
p = inputParser;
addRequired(p, 'outPath', @(x) ischar(x) || isstring(x));
addRequired(p, 'mapsStruct', @isstruct);
addParameter(p, 'Format', 'mat', @(x) ismember(x, {'mat', 'csv', 'nii', 'vtk'}));
addParameter(p, 'Precision', 'double', @(x) ismember(x, {'single', 'double'}));
addParameter(p, 'Compress', false, @islogical);
addParameter(p, 'Metadata', struct(), @isstruct);
addParameter(p, 'Verbose', false, @islogical);
parse(p, outPath, mapsStruct, varargin{:});

opts = p.Results;

try
    % Validate required fields
    if ~isfield(mapsStruct, 'scalarMaps') && ~isfield(mapsStruct, 'timeSeries')
        error('mapsStruct must contain either scalarMaps or timeSeries field');
    end
    
    % Prepare output directory
    if isfolder(outPath)
        outDir = outPath;
        baseFilename = 'derived_maps';
    else
        [outDir, baseFilename, ~] = fileparts(outPath);
        if isempty(outDir)
            outDir = '.';
        end
    end
    
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    
    if opts.Verbose
        fprintf('Exporting derived maps to: %s\n', outDir);
    end
    
    % Convert precision if requested
    if strcmp(opts.Precision, 'single')
        if isfield(mapsStruct, 'scalarMaps')
            mapsStruct.scalarMaps = single(mapsStruct.scalarMaps);
        end
        if isfield(mapsStruct, 'timeSeries')
            mapsStruct.timeSeries = single(mapsStruct.timeSeries);
        end
        if isfield(mapsStruct, 'vertices')
            mapsStruct.vertices = single(mapsStruct.vertices);
        end
    end
    
    % Export based on format
    switch opts.Format
        case 'mat'
            success = exportMAT(outDir, baseFilename, mapsStruct, opts);
            
        case 'csv'
            success = exportCSV(outDir, baseFilename, mapsStruct, opts);
            
        case 'vtk'
            success = exportVTK(outDir, baseFilename, mapsStruct, opts);
            
        case 'nii'
            success = exportNIfTI(outDir, baseFilename, mapsStruct, opts);
            
        otherwise
            error('Unsupported export format: %s', opts.Format);
    end
    
    if success && opts.Verbose
        fprintf('Export completed successfully.\n');
    end
    
catch ME
    warning('MEG_GSP:ExportFailed', 'Export failed: %s', ME.message);
    success = false;
end

end

function success = exportMAT(outDir, baseFilename, mapsStruct, opts)
% Export to MATLAB .mat format
filename = fullfile(outDir, [baseFilename, '.mat']);

% Prepare data structure
exportData = mapsStruct;

% Add metadata
exportData.exportInfo = struct();
exportData.exportInfo.exportDate = datestr(now);
exportData.exportInfo.toolbox = 'MEG-GSP';
exportData.exportInfo.format = 'MAT';
exportData.exportInfo.precision = opts.Precision;

% Merge user metadata
if ~isempty(fieldnames(opts.Metadata))
    exportData.metadata = opts.Metadata;
end

% Save with optional compression
if opts.Compress
    save(filename, '-struct', 'exportData', '-v7.3');
else
    save(filename, '-struct', 'exportData');
end

if opts.Verbose
    fprintf('  Saved MAT file: %s\n', filename);
end

success = true;
end

function success = exportCSV(outDir, baseFilename, mapsStruct, opts)
% Export to CSV format
success = true;

% Export scalar maps
if isfield(mapsStruct, 'scalarMaps')
    filename = fullfile(outDir, [baseFilename, '_scalars.csv']);
    
    % Create table with map names as column headers
    if isfield(mapsStruct, 'mapNames') && length(mapsStruct.mapNames) == size(mapsStruct.scalarMaps, 2)
        T = array2table(mapsStruct.scalarMaps, 'VariableNames', mapsStruct.mapNames);
    else
        mapNames = arrayfun(@(i) sprintf('Map_%d', i), 1:size(mapsStruct.scalarMaps, 2), 'UniformOutput', false);
        T = array2table(mapsStruct.scalarMaps, 'VariableNames', mapNames);
    end
    
    writetable(T, filename);
    
    if opts.Verbose
        fprintf('  Saved scalar maps CSV: %s\n', filename);
    end
end

% Export time series
if isfield(mapsStruct, 'timeSeries')
    filename = fullfile(outDir, [baseFilename, '_timeseries.csv']);
    
    % Add time vector as first column if available
    if isfield(mapsStruct, 'tvec')
        data = [mapsStruct.tvec(:), mapsStruct.timeSeries.'];
        headers = ['Time', arrayfun(@(i) sprintf('Vertex_%d', i), 1:size(mapsStruct.timeSeries, 1), 'UniformOutput', false)];
        T = array2table(data, 'VariableNames', headers);
    else
        T = array2table(mapsStruct.timeSeries.');
    end
    
    writetable(T, filename);
    
    if opts.Verbose
        fprintf('  Saved time series CSV: %s\n', filename);
    end
end

% Export vertices if available
if isfield(mapsStruct, 'vertices')
    filename = fullfile(outDir, [baseFilename, '_vertices.csv']);
    T = array2table(mapsStruct.vertices, 'VariableNames', {'X', 'Y', 'Z'});
    writetable(T, filename);
    
    if opts.Verbose
        fprintf('  Saved vertices CSV: %s\n', filename);
    end
end

end

function success = exportVTK(outDir, baseFilename, mapsStruct, opts)
% Export to VTK format for visualization in ParaView/VTK viewers
filename = fullfile(outDir, [baseFilename, '.vtk']);

if ~isfield(mapsStruct, 'vertices')
    warning('VTK export requires vertices. Skipping VTK export.');
    success = false;
    return;
end

fid = fopen(filename, 'w');
if fid == -1
    error('Cannot open file for writing: %s', filename);
end

try
    % Write VTK header
    fprintf(fid, '# vtk DataFile Version 3.0\n');
    fprintf(fid, 'MEG-GSP Derived Maps\n');
    fprintf(fid, 'ASCII\n');
    fprintf(fid, 'DATASET POLYDATA\n');
    
    % Write vertices
    nVertices = size(mapsStruct.vertices, 1);
    fprintf(fid, 'POINTS %d float\n', nVertices);
    for i = 1:nVertices
        fprintf(fid, '%.6f %.6f %.6f\n', mapsStruct.vertices(i, :));
    end
    
    % Write faces if available
    if isfield(mapsStruct, 'faces') && ~isempty(mapsStruct.faces)
        nFaces = size(mapsStruct.faces, 1);
        fprintf(fid, 'POLYGONS %d %d\n', nFaces, 4 * nFaces);
        for i = 1:nFaces
            fprintf(fid, '3 %d %d %d\n', mapsStruct.faces(i, :) - 1); % VTK uses 0-based indexing
        end
    end
    
    % Write scalar data
    if isfield(mapsStruct, 'scalarMaps')
        fprintf(fid, 'POINT_DATA %d\n', nVertices);
        
        nMaps = size(mapsStruct.scalarMaps, 2);
        for j = 1:nMaps
            if isfield(mapsStruct, 'mapNames') && j <= length(mapsStruct.mapNames)
                mapName = mapsStruct.mapNames{j};
            else
                mapName = sprintf('Map_%d', j);
            end
            
            fprintf(fid, 'SCALARS %s float\n', mapName);
            fprintf(fid, 'LOOKUP_TABLE default\n');
            for i = 1:nVertices
                fprintf(fid, '%.6f\n', mapsStruct.scalarMaps(i, j));
            end
        end
    end
    
    fclose(fid);
    
    if opts.Verbose
        fprintf('  Saved VTK file: %s\n', filename);
    end
    
    success = true;
    
catch ME
    fclose(fid);
    rethrow(ME);
end

end

function success = exportNIfTI(~, ~, ~, ~)
% Export to NIfTI format (requires mapping to volume space)
warning('NIfTI export not yet implemented. Use MAT or VTK format instead.');
success = false;

% TODO: Implement NIfTI export
% This would require:
% 1. Volume space mapping of cortical vertices
% 2. Interpolation to regular grid
% 3. NIfTI header creation
% 4. Writing using appropriate MATLAB NIfTI tools

end