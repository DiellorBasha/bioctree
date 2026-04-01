function Atlas = freesurfer_get_atlas(subjectDir, options)
%FREESURFER_GET_ATLAS Load FreeSurfer hemisphere atlas from .annot file.
%
% Syntax:
%   Atlas = freesurfer_get_atlas(subjectDir)
%   Atlas = freesurfer_get_atlas(subjectDir, Hemi="lh", Atlas="aparc")
%   Atlas = freesurfer_get_atlas(subjectDir, ..., NumVertices=nV)
%   Atlas = freesurfer_get_atlas(subjectDir, ..., SavePath=pathToMat)
%
% Inputs:
%   subjectDir   - Path to FreeSurfer subject directory (e.g., fsaverage6)
%
% Name-Value Options:
%   Hemi         - Hemisphere: "lh" (default) or "rh"
%   Atlas        - Atlas name in label/<hemi>.<atlas>.annot (default: "aparc")
%   NumVertices  - Optional expected vertex count for strict validation
%   SavePath     - Optional MAT file path to save resulting Atlas struct
%   Verbose      - Print informative messages (default: false)
%
% Output:
%   Atlas struct with fields:
%     .SubjectDir          FreeSurfer subject directory
%     .SubjectName         Subject folder name (e.g., "fsaverage6")
%     .Hemi                Hemisphere string
%     .Name                Atlas name (e.g., "aparc")
%     .AnnotPath           Absolute path to source .annot file
%     .VertexIds           Annotation vertex ids (MATLAB 1-based)
%     .LabelCode           Packed FreeSurfer annotation code per vertex id
%     .RegionNames         Region names from annotation colortable
%     .RegionCodes         Packed region code per region
%     .RegionColorRGBA     Region colortable RGBA (Nx4)
%     .VertexRegionIndex   Region index per vertex (0 for unknown/unmapped)
%     .RegionVertexIndices Cell array, vertices for each region
%     .UnknownVertices     Vertex ids not mapped to any region code
%     .ColorTable          Original FreeSurfer colortable struct
%
% Notes:
%   - This function expects freesurfer_read_annotation_ctab on MATLAB path.
%   - FreeSurfer annotation codes are matched against colortable.table(:,5).

arguments
    subjectDir (1,1) string
    options.Hemi (1,1) string = "lh"
    options.Atlas (1,1) string = "aparc"
    options.NumVertices (1,1) double {mustBeNonnegative} = 0
    options.SavePath (1,1) string = ""
    options.Verbose (1,1) logical = false
end

hemi = lower(options.Hemi);
if ~ismember(hemi, ["lh", "rh"])
    error('bct:freesurfer:InvalidHemi', ...
        'Hemi must be "lh" or "rh", got "%s"', options.Hemi);
end

if ~isfolder(subjectDir)
    error('bct:freesurfer:SubjectDirNotFound', ...
        'FreeSurfer subject directory not found: %s', subjectDir);
end

subjectName = string(local_basename(subjectDir));
annotPath = fullfile(subjectDir, 'label', sprintf('%s.%s.annot', hemi, options.Atlas));
if ~exist(annotPath, 'file')
    error('bct:freesurfer:AnnotNotFound', ...
        'Atlas annotation file not found: %s', annotPath);
end

if options.Verbose
    fprintf('[freesurfer_get_atlas] Loading %s\n', annotPath);
end

[vertexIds, labelCode, ctab] = freesurfer_read_annotation_ctab(annotPath);

if isempty(ctab)
    error('bct:freesurfer:MissingColorTable', ...
        'Annotation file has no embedded color table: %s', annotPath);
end

vertexIds = double(vertexIds(:));
labelCode = double(labelCode(:));

% Normalize annotation vertex ids to MATLAB 1-based indexing.
if ~isempty(vertexIds) && min(vertexIds) == 0
    vertexIds = vertexIds + 1;
end

if options.NumVertices > 0
    if numel(labelCode) ~= options.NumVertices
        error('bct:freesurfer:VertexCountMismatch', ...
            ['Annotation label length (%d) does not match expected ', ...
             'NumVertices (%d).'], numel(labelCode), options.NumVertices);
    end
    if max(vertexIds) > options.NumVertices
        error('bct:freesurfer:VertexIndexOutOfRange', ...
            'Annotation vertex id exceeds NumVertices: %d > %d', ...
            max(vertexIds), options.NumVertices);
    end
end

regionNames = string(ctab.struct_names(:));
regionCodes = double(ctab.table(:,5));
regionRGBA = double(ctab.table(:,1:4));

[isKnown, regionIndexAnnotOrder] = ismember(labelCode, regionCodes);
regionIndexAnnotOrder(~isKnown) = 0;

if options.NumVertices > 0
    nV = options.NumVertices;
else
    nV = numel(labelCode);
end

vertexRegionIndex = zeros(nV, 1, 'int32');
vertexRegionIndex(vertexIds) = int32(regionIndexAnnotOrder);

nR = numel(regionNames);
regionVertexIndices = cell(nR, 1);
for k = 1:nR
    regionVertexIndices{k} = find(vertexRegionIndex == k);
end

unknownVertices = find(vertexRegionIndex == 0);

Atlas = struct();
Atlas.SubjectDir = subjectDir;
Atlas.SubjectName = subjectName;
Atlas.Hemi = hemi;
Atlas.Name = string(options.Atlas);
Atlas.AnnotPath = string(annotPath);
Atlas.VertexIds = vertexIds;
Atlas.LabelCode = labelCode;
Atlas.RegionNames = regionNames;
Atlas.RegionCodes = regionCodes;
Atlas.RegionColorRGBA = regionRGBA;
Atlas.VertexRegionIndex = vertexRegionIndex;
Atlas.RegionVertexIndices = regionVertexIndices;
Atlas.UnknownVertices = unknownVertices;
Atlas.ColorTable = ctab;

if options.SavePath ~= ""
    outDir = fileparts(options.SavePath);
    if ~isempty(outDir) && ~isfolder(outDir)
        mkdir(outDir);
    end
    save(options.SavePath, 'Atlas', '-v7.3');
    if options.Verbose
        fprintf('[freesurfer_get_atlas] Saved Atlas to %s\n', options.SavePath);
    end
end

end

function name = local_basename(p)
[~, name, ext] = fileparts(char(p));
if isempty(name) && ~isempty(ext)
    name = ext;
elseif ~isempty(ext)
    name = [name ext];
end
end
