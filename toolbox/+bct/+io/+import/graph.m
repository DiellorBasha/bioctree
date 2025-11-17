function B = graph(source, varargin)
%GRAPH Import graph-type Manifold from various sources
%
%   B = bct.io.import.graph(path) - Auto-detect format and import
%   B = bct.io.import.graph(path, 'Format', 'FreeSurfer') - Specify format
%
%   Supported Formats:
%     'FreeSurfer'   - FreeSurfer surface files (.pial, .white, etc.)
%     'Brainstorm'   - Brainstorm anatomy files (tess_*.mat)
%     'auto'         - Auto-detect format (default)
%
%   Brainstorm Options:
%     'Subject'     - Subject name (default: first subject in anat/)
%     'Structure'   - 'cortex' or 'head' (default: 'cortex')
%     'Surface'     - 'pial', 'white', 'mid' (default: 'pial')
%     'Resolution'  - 'low' or 'high' (default: 'low')
%
%   Returns:
%     B - bct object with graph-type Manifold (edges extracted from faces)
%
%   Examples:
%     B = bct.io.import.graph('lh.pial');
%     B = bct.io.import.graph('Z:\protocols\Study\anat\sub-001');
%     B = bct.io.import.graph('Z:\protocols\Study', ...
%         'Subject', 'sub-002', 'Resolution', 'high');
%
%   See also: bct.io.import.mesh

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
            B = bct.io.construct.graph(snap.V, snap.F);
            
        case 'brainstorm'
            raw = bct.io.in.readBrainstormAnat(source, opts);
            snap = bct.io.convert.brainstormRawToSnapshot(raw);
            B = bct.io.construct.graph(snap.V, snap.F);
            
        otherwise
            error('bct:io:import:UnsupportedFormat', ...
                'Unsupported format: %s', format);
    end
end
