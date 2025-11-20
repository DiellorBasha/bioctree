function B = mesh(source, varargin)
%MESH Import mesh-type Manifold from various sources
%
%   B = bct.io.import.mesh(path) - Auto-detect format and import
%   B = bct.io.import.mesh(path, 'Format', 'FreeSurfer') - Specify format
%
%   Supported Formats:
%     'FreeSurfer'   - FreeSurfer surface files (.pial, .white, etc.)
%     'Brainstorm'   - Brainstorm anatomy files (tess_*.mat)
%     'MATLAB'       - Generic MATLAB .mat files with V and F variables
%     'auto'         - Auto-detect format (default)
%
%   FreeSurfer Import:
%     UV parametrization is NOT computed by default to speed up import.
%     To compute UV parametrization after import, use:
%       B.Manifold.computeUV()  % Requires .sphere.reg file
%     Or enable during import:
%       B = bct.io.import.mesh(path, 'ComputeUV', true)
%
%   Common Options:
%     'ComputeUV'    - Compute UV parametrization from .sphere.reg (default: false)
%                      Only applies to FreeSurfer format
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
%     % Import FreeSurfer surface (UV NOT computed by default - faster)
%     B = bct.io.import.mesh('test-data/freesurfer/fsaverage/surf/lh.pial');
%
%     % Compute UV later when needed
%     B.Manifold.computeUV('test-data/freesurfer/fsaverage/surf/lh.pial');
%     UV = B.Manifold.UV;  % [N×2] UV coordinates
%
%     % Or enable UV during import (slower)
%     B = bct.io.import.mesh('test-data/freesurfer/fsaverage/surf/lh.pial', ...
%         'ComputeUV', true);
%
%     % Import Brainstorm surface
%     B = bct.io.import.mesh('Z:\protocols\Study\anat\sub-001');
%
%     % Import with specific options
%     B = bct.io.import.mesh('Z:\protocols\Study', ...
%         'Format', 'Brainstorm', 'Subject', 'sub-002', 'Resolution', 'high');
%
%   See also: bct.io.import.graph, bct.io.import.findSphereReg, 
%             bct.io.import.computeUVFromSphere, bct.io.import.populateUV,
%             bct.manifold.Manifold.computeUV

    p = inputParser;
    addRequired(p, 'source');
    addParameter(p, 'Format', 'auto', @ischar);
    addParameter(p, 'ComputeUV', false, @islogical);  % UV computation opt-in
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
            
            % Optionally compute UV parametrization (if requested)
            if p.Results.ComputeUV
                try
                    bct.io.import.populateUV(B.Manifold, source);
                catch ME
                    warning('bct:io:import:UVComputeFailed', ...
                        'Failed to compute UV parametrization: %s', ME.message);
                end
            end
            
        case 'brainstorm'
            raw = bct.io.in.readBrainstormAnat(source, opts);
            snap = bct.io.convert.brainstormRawToSnapshot(raw);
            B = bct.io.construct.mesh(snap.V, snap.F);
            
        case 'matlab'
            raw = bct.io.in.readMat(source);
            snap = bct.io.convert.matlabRawToSnapshot(raw);
            B = bct.io.construct.mesh(snap.V, snap.F);
            
        otherwise
            error('bct:io:import:UnsupportedFormat', ...
                'Unsupported format: %s', format);
    end
end
