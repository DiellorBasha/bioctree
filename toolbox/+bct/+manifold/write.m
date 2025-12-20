function write(M, fileName, options)
%WRITE Write Manifold to standard mesh file formats
%
% Syntax:
%   bct.manifold.write(M, fileName)
%   bct.manifold.write(M, fileName, 'Encoding', enc)
%   bct.manifold.write(M, fileName, 'Format', fmt)
%
% Supported File Formats:
%   - .stl  - STL (STereoLithography) format
%   - .ply  - PLY (Polygon File Format)
%   - .obj  - OBJ (Wavefront) format
%   - .glb  - GLB (Binary glTF)
%   - .gltf - GLTF (GL Transmission Format)
%   - .mat  - MATLAB data file (saves V and F variables)
%
% Inputs:
%   M        - bct.Manifold object
%   fileName - String or char path for output file
%
% Optional Parameters:
%   Encoding - 'binary' or 'ascii' (for formats that support it, e.g., STL)
%   Format   - Explicitly specify file format (auto-detected from extension)
%
% Outputs:
%   None (writes to file)
%
% Notes:
%   - For .stl, .ply, .obj, .glb, .gltf: Uses MATLAB's writeSurfaceMesh
%   - For .mat files: Saves Vertices as V and Faces as F
%   - Automatically converts Manifold → surfaceMesh for supported formats
%
% Examples:
%   % Write to STL file
%   M = bct.Manifold(V, F);
%   bct.manifold.write(M, 'output.stl');
%
%   % Write to PLY file
%   bct.manifold.write(M, 'output.ply');
%
%   % Write to STL with binary encoding
%   bct.manifold.write(M, 'output.stl', 'Encoding', 'binary');
%
%   % Write to OBJ file
%   bct.manifold.write(M, 'model.obj');
%
%   % Write to MATLAB data file
%   bct.manifold.write(M, 'mesh_data.mat');
%
% See also: bct.manifold.read, bct.manifold.out, writeSurfaceMesh

arguments
    M        bct.Manifold
    fileName string
    options.Encoding string = ""
    options.Format string = ""
end

% Convert fileName to string
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
        % Convert Manifold to surfaceMesh
        smesh = bct.manifold.out(M, 'surfaceMesh');
        
        % Write using MATLAB's writeSurfaceMesh
        try
            if options.Encoding ~= ""
                writeSurfaceMesh(smesh, fileName, 'Encoding', options.Encoding);
            else
                writeSurfaceMesh(smesh, fileName);
            end
        catch ME
            error('bct:manifold:WriteError', ...
                'Failed to write mesh file "%s": %s', fileName, ME.message);
        end
        
    case ".mat"
        % Save as MATLAB data file with V and F variables
        V = M.Vertices; %#ok<NASGU>
        F = M.Faces;    %#ok<NASGU>
        
        try
            save(fileName, 'V', 'F', '-v7.3');
        catch ME
            error('bct:manifold:WriteError', ...
                'Failed to write MATLAB file "%s": %s', fileName, ME.message);
        end
        
    otherwise
        error('bct:manifold:UnsupportedFormat', ...
            'Unsupported file format: %s. Supported formats: .stl, .ply, .obj, .glb, .gltf, .mat', ...
            ext);
end

end
