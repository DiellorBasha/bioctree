function OutputFile = savemap2bst(MriFileSrc, map, varargin)
% SAVE_GSP_VERTEX_MAP_TO_BRAINSTORM  Save an N×T vertex map as a Brainstorm result.
%
% Usage:
%   OutputFile = save_gsp_vertex_map_to_brainstorm(MriFileSrc, map, ...
%                   'Condition','GSP_Wavelet_Curvature', ...
%                   'Comment','Alpha emitters', ...
%                   'TimeVector', t, ...
%                   'DisplayUnits','A', ...
%                   'SurfaceRegex','cortex_pial_low\.mat$', ...
%                   'ViewAfter', true, ...
%                   'DuplicateIfSingle', true);
%
% Inputs:
%   MriFileSrc    - Full path to subject MRI .mat (e.g., subjectimage_T1_reslice.mat)
%   map           - N×T vertex map (double). If N×1 and DuplicateIfSingle=true,
%                   it will be duplicated to N×2 (Brainstorm displays time).
%
% Name-Value (optional):
%   'Condition'         (char)   Study/condition name to store under (default 'GSP_Wavelet_Curvature')
%   'Comment'           (char)   ResultsMat.Comment (default 'GSP Vertex Map')
%   'TimeVector'        (double) 1×T time vector (default 0:(T-1))
%   'DisplayUnits'      (char)   Units label (default 'A')
%   'SurfaceRegex'      (char)   Regex to pick surface file (default 'cortex_pial_low\.mat$')
%   'ViewAfter'         (logical)Open viewer after saving (default true)
%   'DuplicateIfSingle' (logical)If T==1, duplicate to two time points (default true)
%
% Returns:
%   OutputFile - Full path to saved results file in the Brainstorm database.
%
% Notes:
%   - Run inside a Brainstorm session (GUI or 'brainstorm nogui'), with protocol loaded.
%   - The number of vertices in 'map' must match the chosen surface.

% ----------- Parse Name-Value pairs -----------
Condition         = 'GSP_Wavelet_Curvature';
Comment           = 'GSP Vertex Map';
TimeVector        = [];
DisplayUnits      = 'A';
SurfaceRegex      = 'cortex_pial_low\.mat$';
ViewAfter         = true;
DuplicateIfSingle = true;

k = 1;
while k <= numel(varargin)
    key = varargin{k};
    val = varargin{k+1};
    switch lower(key)
        case 'condition',          Condition = val;
        case 'comment',            Comment = val;
        case 'timevector',         TimeVector = val;
        case 'displayunits',       DisplayUnits = val;
        case 'surfacereregex',     SurfaceRegex = val;   % (typo-safe)
        case 'surfaceregex',       SurfaceRegex = val;
        case 'viewafter',          ViewAfter = logical(val);
        case 'duplicateifsingle',  DuplicateIfSingle = logical(val);
        otherwise, error('Unknown parameter: %s', key);
    end
    k = k + 2;
end

% ----------- Validate Brainstorm context -----------
if ~exist('bst_get','file')
    error('Brainstorm functions not on path. Start Brainstorm and load your protocol.');
end
if ~exist(MriFileSrc,'file')
    error('MRI file not found: %s', MriFileSrc);
end

% ----------- Get subject from MRI -----------
[sSubject, iSubject] = bst_get('MriFile', MriFileSrc);
if isempty(iSubject)
    error('No Brainstorm subject is linked to MRI file: %s', MriFileSrc);
end
sMriSrc = in_mri_bst(MriFileSrc);

% ----------- Ensure Study / Condition exists -----------
[sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, Condition));
if isempty(iStudy)
    iStudy = db_add_condition(sSubject.Name, Condition);
    sStudy = bst_get('Study', iStudy);
end

% ----------- Pick the surface file -----------
allFiles = {sSubject.Surface.FileName};
idx = find(~cellfun('isempty', regexp(allFiles, SurfaceRegex, 'once')), 1);
if isempty(idx)
    % Fallbacks if the exact regex wasn't found
    idx = find(contains(allFiles, 'cortex', 'IgnoreCase', true), 1);
end
if isempty(idx)
    error('No cortex surface found for subject "%s".', sSubject.Name);
end
pialFile = allFiles{idx};
sPial = in_tess_bst(pialFile);
Nsurf = size(sPial.Vertices, 1);

% ----------- Prepare the vertex map -----------
if ~isfloat(map), map = double(map); end
if isvector(map)
    map = map(:);
end
if size(map,1) ~= Nsurf && size(map,2) == Nsurf
    map = map.'; % transpose if provided as 1×N
end
if size(map,1) ~= Nsurf
    error('Map has %d vertices, but surface has %d.', size(map,1), Nsurf);
end

% If single time point, duplicate if requested (Brainstorm displays time)
T = size(map,2);
if T == 1 && DuplicateIfSingle
    map = [map, map];
    T = 2;
end

% ----------- Time vector -----------
if isempty(TimeVector) || numel(TimeVector) ~= T
    TimeVector = 0:(T-1);
end
if numel(TimeVector) == 2 && TimeVector(1) == TimeVector(2)
    TimeVector(2) = TimeVector(2) + 0.001; % avoid identical times
end

% ----------- Build ResultsMat -----------
ResultsMat = db_template('resultsmat');
ResultsMat.ImageGridAmp  = map;                                % N×T
ResultsMat.ImagingKernel = [];
ResultsMat.Time          = TimeVector(:).';
ResultsMat.Comment       = Comment;
ResultsMat.DataFile      = [];
ResultsMat.SurfaceFile   = file_win2unix(file_short(pialFile));
ResultsMat.HeadModelFile = [];
ResultsMat.nComponents   = 1;
ResultsMat.DisplayUnits  = DisplayUnits;
if isequal(DisplayUnits, 's')     % keep your original convention
    ResultsMat.ColormapType = 'time';
end
ResultsMat.HeadModelType = 'surface';

% History
ResultsMat = bst_history('add', ResultsMat, 'project', ['Projected from: ' sMriSrc.Comment]);

% ----------- Save Results to database -----------
FileType   = 'results';
outBaseDir = bst_fileparts(sStudy.FileName);
baseName   = [FileType, '_', ResultsMat.HeadModelType, '_', file_standardize(ResultsMat.Comment)];
OutputFile = bst_process('GetNewFilename', outBaseDir, baseName);

bst_save(OutputFile, ResultsMat, 'v7');
db_add_data(iStudy, OutputFile, ResultsMat);

% Update tree & save DB
panel_protocols('UpdateNode', 'Study', iStudy);
db_save();

% ----------- Optional: open in viewer -----------
if ViewAfter
    view_surface_data(pialFile, file_short(OutputFile));
end
end
