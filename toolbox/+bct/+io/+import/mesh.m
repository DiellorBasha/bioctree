function B = mesh(source, varargin)
%MESH Import mesh-type Manifold from various sources
%
%   B = bct.io.import.mesh(path) - Auto-detect format and import
%   B = bct.io.import.mesh(path, 'Format', 'FreeSurfer') - Specify format
%
%   Supported Formats:
%     'FreeSurfer'   - FreeSurfer surface files (.pial, .white, etc.)
%                      Automatically loads .sphere.reg for UV parametrization
%     'Brainstorm'   - Brainstorm anatomy files (tess_*.mat)
%     'auto'         - Auto-detect format (default)
%
%   FreeSurfer Import:
%     When importing FreeSurfer surfaces, the function automatically:
%     1. Loads the surface geometry (vertices and faces)
%     2. Searches for corresponding .sphere.reg file in same directory
%     3. If found: Computes UV parametrization from spherical coordinates
%        and stores in B.Manifold.UV [N×2]
%     4. If not found: B.Manifold.UV remains empty (no error)
%
%     UV parametrization is OPTIONAL. Functions requiring UV will warn
%     via B.Manifold.checkUV() if UV is not available.
%
%     UV Computation (when .sphere.reg exists):
%       Given sphere coordinates (x, y, z):
%         theta = atan2(y, x)      % Azimuthal angle [-π, π]
%         phi   = acos(z)          % Polar angle [0, π]
%         u = (theta + π) / (2π)   % Normalize to [0, 1]
%         v = phi / π              % Normalize to [0, 1]
%
%   Brainstorm Options:
%     'Subject'     - Subject name (default: first subject in anat/)
%     'Structure'   - 'cortex' or 'head' (default: 'cortex')
%     'Surface'     - 'pial', 'white', 'mid' (default: 'pial')
%     'Resolution'  - 'low' or 'high' (default: 'low')
%
%   Returns:
%     B - bct object with mesh-type Manifold
%
%   Examples:
%     % Import FreeSurfer surface (with automatic UV loading)
%     B = bct.io.import.mesh('test-data/freesurfer/fsaverage/surf/lh.pial');
%     UV = B.Manifold.UV;  % [N×2] UV coordinates (if .sphere.reg exists)
%
%     % Import Brainstorm surface
%     B = bct.io.import.mesh('Z:\protocols\Study\anat\sub-001');
%
%     % Import with specific options
%     B = bct.io.import.mesh('Z:\protocols\Study', ...
%         'Format', 'Brainstorm', 'Subject', 'sub-002', 'Resolution', 'high');
%
%   See also: bct.io.import.graph, bct.io.import.findSphereReg, 
%             bct.io.import.computeUVFromSphere

    p = inputParser;
    addRequired(p, 'source');
    addParameter(p, 'Format', 'auto', @ischar);
    addParameter(p, 'Subject', '', @ischar);
    addParameter(p, 'Structure', 'cortex', @ischar);
    addParameter(p, 'Surface', 'pial', @ischar);
    addParameter(p, 'Resolution', 'low', @ischar);
    parse(p, source, varargin{:});
    
    format = p.Results.Format;
    
    % Auto-detect format if needed
    if strcmpi(format, 'auto')
        format = bct.io.convert.detectFormat(source);
    end
    
    % Build options structure for Brainstorm
    opts = struct();
    opts.Subject = p.Results.Subject;
    opts.Structure = p.Results.Structure;
    opts.Surface = p.Results.Surface;
    opts.Resolution = p.Results.Resolution;
    
    % Import based on format
    switch lower(format)
        case 'freesurfer'
            raw = bct.io.in.readFreeSurferSurf(source);
            snap = bct.io.convert.freeSurferRawToSnapshot(raw);
            B = bct.io.construct.mesh(snap.V, snap.F);
            
            % Try to load corresponding .sphere.reg file for UV parametrization
            sphere_reg_path = bct.io.import.findSphereReg(source);
            if ~isempty(sphere_reg_path)
                try
                    sphere_raw = bct.io.in.readFreeSurferSurf(sphere_reg_path);
                    UV = bct.io.import.computeUVFromSphere(sphere_raw.V);
                    B.Manifold.UV = UV;
                    fprintf('  ✓ UV parametrization loaded from: %s\n', sphere_reg_path);
                catch ME
                    warning('bct:io:import:SphereRegFailed', ...
                        'Failed to load sphere.reg: %s. UV parametrization not available.', ME.message);
                end
            else
                % UV parametrization is optional - no warning needed for missing sphere.reg
                % Functions that require UV will warn when checkUV() is called
            end
            
        case 'brainstorm'
            raw = bct.io.in.readBrainstormAnat(source, opts);
            snap = bct.io.convert.brainstormRawToSnapshot(raw);
            B = bct.io.construct.mesh(snap.V, snap.F);
            
        otherwise
            error('bct:io:import:UnsupportedFormat', ...
                'Unsupported format: %s', format);
    end
end
