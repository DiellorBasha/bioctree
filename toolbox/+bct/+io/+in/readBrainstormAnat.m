function raw = readBrainstormAnat(path, opts)
%READBRAINSTORMANAT Read Brainstorm anatomy mesh file
%
%   raw = readBrainstormAnat(path) reads a Brainstorm tess file
%   or automatically finds and loads mesh from protocol directory
%
%   Path Types:
%     - Direct file:     'path/to/tess_cortex_pial_low.mat'
%     - Protocol dir:    'Z:\brainstorm_protocols\TutorialOmega'
%     - Subject anat:    'Z:\brainstorm_protocols\TutorialOmega\anat\sub-0002'
%
%   Options:
%     'Subject'     - Subject name (default: first subject in anat/)
%     'Structure'   - 'cortex' or 'head' (default: 'cortex')
%     'Surface'     - 'pial', 'white', 'mid' (default: 'pial')
%     'Resolution'  - 'low' or 'high' (default: 'low')
%
%   Examples:
%     % Load default (first subject, cortex_pial_low)
%     raw = readBrainstormAnat('Z:\brainstorm_protocols\TutorialOmega');
%
%     % Specify subject and resolution
%     raw = readBrainstormAnat('Z:\protocols\MyStudy', ...
%         'Subject', 'sub-0002', 'Resolution', 'high');
%
%     % Direct file load
%     raw = readBrainstormAnat('path/to/tess_cortex_pial_high.mat');
%
%   Returns:
%     raw.V     - Nx3 vertices (double)
%     raw.F     - Mx3 faces (int32)
%     raw.meta  - Metadata structure with Brainstorm fields

    if nargin < 2
        opts = struct();
    end
    
    % Parse options
    if ~isfield(opts, 'Subject'), opts.Subject = ''; end
    if ~isfield(opts, 'Structure'), opts.Structure = 'cortex'; end
    if ~isfield(opts, 'Surface'), opts.Surface = 'pial'; end
    if ~isfield(opts, 'Resolution'), opts.Resolution = 'low'; end
    
    % Determine actual file path
    filepath = resolveBrainstormPath(path, opts);
    
    % Verify file exists
    if ~isfile(filepath)
        error('bct:io:in:FileNotFound', ...
            'Brainstorm anatomy file not found: %s', filepath);
    end
    
    % Load .mat file
    try
        bstMesh = load(filepath);
    catch ME
        error('bct:io:in:LoadFailed', ...
            'Failed to load Brainstorm file: %s\n%s', filepath, ME.message);
    end
    
    % Extract vertices and faces
    if ~isfield(bstMesh, 'Vertices') || ~isfield(bstMesh, 'Faces')
        error('bct:io:in:InvalidBrainstorm', ...
            'File does not contain required Vertices/Faces fields: %s', filepath);
    end
    
    V = bstMesh.Vertices;
    F = bstMesh.Faces;
    
    % Build metadata
    meta = struct();
    meta.source = 'brainstorm';
    meta.file = string(filepath);
    
    % Extract optional Brainstorm fields
    if isfield(bstMesh, 'Comment'), meta.comment = bstMesh.Comment; end
    if isfield(bstMesh, 'Atlas'), meta.atlas = bstMesh.Atlas; end
    if isfield(bstMesh, 'iAtlas'), meta.iAtlas = bstMesh.iAtlas; end
    if isfield(bstMesh, 'VertNormals'), meta.vertNormals = bstMesh.VertNormals; end
    if isfield(bstMesh, 'Curvature'), meta.curvature = bstMesh.Curvature; end
    if isfield(bstMesh, 'SulciMap'), meta.sulciMap = bstMesh.SulciMap; end
    
    % Parse filename for structure info
    [~, fname, ~] = fileparts(filepath);
    meta.filename = fname;
    meta.structure = opts.Structure;
    meta.surface = opts.Surface;
    meta.resolution = opts.Resolution;
    
    % Build output structure
    raw = struct(...
        'V', double(V), ...
        'F', int32(F), ...
        'meta', meta ...
    );
end

function filepath = resolveBrainstormPath(path, opts)
    % Resolve various path types to actual .mat file
    
    % If already a .mat file, use directly
    [~, ~, ext] = fileparts(path);
    if strcmpi(ext, '.mat')
        filepath = path;
        return;
    end
    
    % Otherwise, need to construct filename
    % Check if path is protocol root or anat directory
    if exist(fullfile(path, 'anat'), 'dir')
        % Protocol root - need to find anat/subject
        anat_dir = fullfile(path, 'anat');
    elseif contains(path, 'anat') && exist(path, 'dir')
        % Already in anat directory
        anat_dir = path;
    else
        error('bct:io:in:InvalidPath', ...
            'Path must be: protocol root, anat directory, or .mat file: %s', path);
    end
    
    % Find subject directory
    if isempty(opts.Subject)
        % Auto-detect first subject
        subjects = dir(fullfile(anat_dir, 'sub-*'));
        if isempty(subjects)
            % Try without sub- prefix
            subjects = dir(anat_dir);
            subjects = subjects([subjects.isdir] & ~startsWith({subjects.name}, '.'));
        end
        
        if isempty(subjects)
            error('bct:io:in:NoSubjects', ...
                'No subject directories found in: %s', anat_dir);
        end
        
        subject_name = subjects(1).name;
    else
        subject_name = opts.Subject;
    end
    
    subject_dir = fullfile(anat_dir, subject_name);
    
    if ~exist(subject_dir, 'dir')
        error('bct:io:in:SubjectNotFound', ...
            'Subject directory not found: %s', subject_dir);
    end
    
    % Construct filename: tess_<structure>_<surface>_<resolution>.mat
    if strcmpi(opts.Structure, 'cortex')
        % Cortex includes surface and resolution
        filename = sprintf('tess_cortex_%s_%s.mat', opts.Surface, opts.Resolution);
    else
        % Head/other structures may not have surface/resolution
        filename = sprintf('tess_%s.mat', opts.Structure);
    end
    
    filepath = fullfile(subject_dir, filename);
    
    % If file doesn't exist, try to find similar files
    if ~exist(filepath, 'file')
        % List available tess files
        tess_files = dir(fullfile(subject_dir, 'tess_*.mat'));
        
        if isempty(tess_files)
            error('bct:io:in:NoTessFiles', ...
                'No tess files found in: %s', subject_dir);
        end
        
        % Try to find closest match
        fprintf('Warning: Exact file not found: %s\n', filename);
        fprintf('Available tess files:\n');
        for i = 1:length(tess_files)
            fprintf('  %s\n', tess_files(i).name);
        end
        
        % Use first available tess file
        filepath = fullfile(subject_dir, tess_files(1).name);
        fprintf('Using: %s\n', tess_files(1).name);
    end
end
