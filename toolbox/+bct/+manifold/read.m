function M = read(fileName, options)
%READ Read Manifold from standard mesh file formats
%
% Syntax:
%   M = bct.manifold.read(fileName)
%   M = bct.manifold.read(fileName, 'Format', fmt)
%
% Supported File Formats:
%   - .stl  - STL (STereoLithography) format
%   - .ply  - PLY (Polygon File Format)
%   - .obj  - OBJ (Wavefront) format
%   - .glb  - GLB (Binary glTF)
%   - .gltf - GLTF (GL Transmission Format)
%   - .mat  - MATLAB data file (via bct.manifold.load)
%
% Inputs:
%   fileName - String or char path to mesh file
%
% Optional Parameters:
%   Format - Explicitly specify file format (auto-detected from extension)
%
% Outputs:
%   M - bct.Manifold object
%
% Notes:
%   - For .stl, .ply, .obj, .glb, .gltf: Uses MATLAB's readSurfaceMesh
%   - For .mat files: Uses bct.manifold.load directly
%   - Automatically converts surfaceMesh → Manifold
%
% Examples:
%   % Read from PLY file
%   M = bct.manifold.read('mesh.ply');
%
%   % Read from STL file
%   M = bct.manifold.read('model.stl');
%
%   % Read from OBJ file
%   M = bct.manifold.read('surface.obj');
%
%   % Read MATLAB data file
%   M = bct.manifold.read('data/mesh/fsaverage_lh_pial.mat');
%
% See also: bct.manifold.write, bct.manifold.load, readSurfaceMesh

arguments
    fileName {mustBeFile}
    options.Format string = ""
end

% Convert to string for consistency
fileName = string(fileName);

% Determine file format
if options.Format == ""
    [~, ~, ext] = fileparts(fileName);
    ext = lower(ext);
else
    ext = lower(options.Format);
    if ~startsWith(ext, '.')
        ext = "." + ext;
    end
end

% Dispatch based on file format
switch ext
    case {".stl", ".ply", ".obj", ".glb", ".gltf"}
        % Use MATLAB's readSurfaceMesh for standard mesh formats
        try
            smesh = readSurfaceMesh(fileName);
        catch ME
            error('bct:manifold:ReadError', ...
                'Failed to read mesh file "%s": %s', fileName, ME.message);
        end
        
        % Convert surfaceMesh to Manifold
        M = bct.manifold.in(smesh);
        
    case ".mat"
        % Use bct.manifold.load for MATLAB data files
        M = bct.manifold.load(fileName);
        
    otherwise
        error('bct:manifold:UnsupportedFormat', ...
            'Unsupported file format: %s. Supported formats: .stl, .ply, .obj, .glb, .gltf, .mat', ...
            ext);
end

end

% Validation function
function mustBeFile(fileName)
    if ~isfile(fileName)
        error('bct:manifold:FileNotFound', ...
            'File not found: %s', fileName);
    end
end
