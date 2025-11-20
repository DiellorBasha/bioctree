function raw = readMat(filepath)
%READMAT Read mesh vertices and faces from MATLAB .mat file
%
%   raw = readMat(filepath) loads V and F from .mat file
%
%   The .mat file must contain:
%     V - [N×3] vertex coordinates (x, y, z)
%     F - [M×3] face indices (1-based)
%
%   Input:
%     filepath - Path to .mat file
%
%   Output:
%     raw - Structure with fields:
%       .V - [N×3] vertices
%       .F - [M×3] faces
%
%   Example:
%     raw = bct.io.in.readMat('toolbox/data/fsaverage_lh_pial.mat');
%     % raw.V is [N×3] vertices
%     % raw.F is [M×3] faces
%
%   See also: bct.io.import.mesh, bct.io.convert.matlabRawToSnapshot

    % Validate input
    if ~exist(filepath, 'file')
        error('bct:io:in:readMat:FileNotFound', ...
            'File not found: %s', filepath);
    end
    
    % Load .mat file
    try
        data = load(filepath);
    catch ME
        error('bct:io:in:readMat:LoadFailed', ...
            'Failed to load .mat file: %s', ME.message);
    end
    
    % Check for required variables
    if ~isfield(data, 'V')
        error('bct:io:in:readMat:MissingV', ...
            'Variable "V" not found in .mat file');
    end
    if ~isfield(data, 'F')
        error('bct:io:in:readMat:MissingF', ...
            'Variable "F" not found in .mat file');
    end
    
    % Extract V and F
    V = data.V;
    F = data.F;
    
    % Validate dimensions
    if size(V, 2) ~= 3
        error('bct:io:in:readMat:InvalidV', ...
            'V must be [N×3] array, got [%d×%d]', size(V, 1), size(V, 2));
    end
    if size(F, 2) ~= 3
        error('bct:io:in:readMat:InvalidF', ...
            'F must be [M×3] array, got [%d×%d]', size(F, 1), size(F, 2));
    end
    
    % Create raw structure
    raw = struct();
    raw.V = V;
    raw.F = F;
    
end
