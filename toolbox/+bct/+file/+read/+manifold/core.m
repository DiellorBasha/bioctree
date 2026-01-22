function M = core(file, options)
%CORE Read core manifold data (vertices, faces, edges) from HDF5
%
% Syntax:
%   M = bct.file.read.manifold.core(file)
%   M = bct.file.read.manifold.core(file, 'ConvertIndices', true)
%
% Inputs:
%   file - string, HDF5 file path
%
% Name-Value Arguments:
%   ConvertIndices - logical (default true), convert 0-based to 1-based
%   Path           - string (default '/manifold'), HDF5 group path
%
% Outputs:
%   M - bct.Manifold object with core data
%
% Description:
%   Reads core manifold mesh data from /manifold group:
%   - Vertices: [N×3] coordinates
%   - Faces: [F×3] connectivity (converts to 1-based if needed)
%   - Edges: [E×2] connectivity (converts to 1-based if needed)
%   - Group attributes
%
% Examples:
%   M = bct.file.read.manifold.core('mesh.h5');
%
% See also: bct.file.read.manifold, bct.Manifold

arguments
    file (1,1) string
    options.ConvertIndices (1,1) logical = true
    options.Path (1,1) string = "/manifold"
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:read:manifold:core:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Read datasets
groupPath = char(options.Path);
V = h5read(file, [groupPath '/vertices']);
F = h5read(file, [groupPath '/faces']);
E = h5read(file, [groupPath '/edges']);

%% Convert indices if needed
if options.ConvertIndices
    % Check index_base attribute
    try
        faceInfo = h5info(file, [groupPath '/faces']);
        indexBase = 1; % Default to 1-based
        for i = 1:numel(faceInfo.Attributes)
            if strcmp(faceInfo.Attributes(i).Name, 'index_base')
                indexBase = double(faceInfo.Attributes(i).Value);
                break;
            end
        end
        
        if indexBase == 0
            F = F + 1;
            E = E + 1;
        end
    catch
        % If no attribute, assume 0-based and convert
        F = F + 1;
        E = E + 1;
    end
end

%% Create Manifold
M = bct.Manifold(V, F, E);

%% Read and set group attributes
try
    groupInfo = h5info(file, groupPath);
    attrs = struct();
    
    for i = 1:numel(groupInfo.Attributes)
        attrName = groupInfo.Attributes(i).Name;
        attrValue = groupInfo.Attributes(i).Value;
        
        % Map HDF5 attributes back to Manifold attributes
        switch attrName
            case 'id'
                attrs.ID = char(attrValue);
            case 'name'
                attrs.Name = char(attrValue);
            case 'source'
                attrs.Source = char(attrValue);
            case 'created_at'
                attrs.CreatedAt = datetime(char(attrValue), 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss');
            case 'created_by'
                attrs.CreatedBy = char(attrValue);
            case 'face_winding'
                attrs.FaceWinding = char(attrValue);
            case 'normal_convention'
                attrs.NormalConvention = char(attrValue);
            case 'coordinate_system'
                attrs.CoordinateSystem = char(attrValue);
            case 'metric_units'
                if ~isfield(attrs, 'Metric')
                    attrs.Metric = struct();
                end
                attrs.Metric.units = char(attrValue);
        end
    end
    
    % Set attributes if any were found
    if ~isempty(fieldnames(attrs))
        M.setAttributes(attrs);
    end
catch ME
    warning('bct:file:read:manifold:core:AttributeReadFailed', ...
        'Failed to read group attributes: %s', ME.message);
end

end
