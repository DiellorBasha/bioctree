%% ------------------------------------------------------------------------
%  Export fsaverage mesh + FreeSurfer UVs to three.js-compatible JSON
%  Purpose: testing geometry orientation, indexing, and UV parametrization
% -------------------------------------------------------------------------

%% INPUTS (as requested)

V = M.Vertices;              % [N x 3] double, RAS coordinates
F = M.Faces;                 % [M x 3] int32, 1-based indexing

UVstruct = load( ...
  'C:\CodingProjects\bioctree\toolbox\+bct\+data\assets\fsaverage6\surf\fsaverage6_hemi-lh_sphere.mat' ...
);

savePathJSON = ...
 'C:\CodingProjects\bioctree-ui-library\+bct\+ui\+manifold\+viewer\web\assets\fsaverage.json';


%% ------------------------------------------------------------------------
%  BASIC VALIDATION
% -------------------------------------------------------------------------

assert(size(V,2) == 3, 'Vertices must be N x 3');
assert(size(F,2) == 3, 'Faces must be M x 3');

assert(isfield(UVstruct,'UV'), ...
    'Loaded sphere file does not contain UV field');

UVcoords = UVstruct.UV;      % [N x 2] double

assert(size(UVcoords,1) == size(V,1), ...
    'Number of UVs must match number of vertices');


%% ------------------------------------------------------------------------
%  ORIENTATION CHECK (FACE WINDING)
% -------------------------------------------------------------------------
% three.js expects counter-clockwise (CCW) winding for front faces.
% We test whether face normals generally point outward.

TR = triangulation(double(F), V);
FN = faceNormal(TR);                   % [M x 3]
faceCenters = ( ...
    V(F(:,1),:) + V(F(:,2),:) + V(F(:,3),:) ) / 3;

% For a roughly spherical surface, outward normals should correlate
dotVals = dot(FN, faceCenters, 2);
meanDot = mean(dotVals);

fprintf('Mean normal · position = %.4f\n', meanDot);

if meanDot < 0
    warning('Face normals appear inverted. Flipping face winding.');
    F = F(:,[1 3 2]);   % flip orientation
else
    fprintf('Face orientation appears correct (CCW).\n');
end


%% ------------------------------------------------------------------------
%  COORDINATE SYSTEM CHECK
% -------------------------------------------------------------------------
% FreeSurfer + MATLAB use right-handed RAS coordinates.
% three.js also uses a right-handed system.
% -> No axis flip is applied here.

fprintf('Coordinate system assumed: Right-handed (RAS).\n');


%% ------------------------------------------------------------------------
%  CONVERT TO THREE.JS BUFFER FORMAT
% -------------------------------------------------------------------------

% ---- Vertices ----
vertices = single(V');        % 3 x N
vertices = vertices(:)';      % 1 x (3N)

% ---- Faces (0-based indexing!) ----
faces = int32(F' - 1);        % 3 x M
faces = faces(:)';            % 1 x (3M)

assert(all(faces >= 0), 'Faces contain negative indices after conversion');

% ---- UVs ----
uv = single(UVcoords');       % 2 x N
uv = uv(:)';                  % 1 x (2N)


%% ------------------------------------------------------------------------
%  ASSEMBLE JSON STRUCT
% -------------------------------------------------------------------------

meshJSON = struct( ...
    'meta', struct( ...
        'name', 'fsaverage6-lh', ...
        'coordinateSystem', 'RAS', ...
        'handedness', 'right', ...
        'indexing', '0-based', ...
        'hasUV', true, ...
        'uvInfo', UVstruct.UVInfo ...
    ), ...
    'vertices', vertices, ...
    'faces', faces, ...
    'uv', uv ...
);


%% ------------------------------------------------------------------------
%  WRITE JSON FILE
% -------------------------------------------------------------------------

jsonText = jsonencode(meshJSON);

% Optional pretty formatting (useful for inspection)
if exist('prettyjson','file')
    jsonText = prettyjson(jsonText);
end

fid = fopen(savePathJSON, 'w');
assert(fid ~= -1, 'Failed to open JSON file for writing');

fwrite(fid, jsonText, 'char');
fclose(fid);

fprintf('Mesh JSON successfully written to:\n%s\n', savePathJSON);


%% ------------------------------------------------------------------------
%  FINAL SANITY PRINT
% -------------------------------------------------------------------------

fprintf('Vertices: %d\n', size(V,1));
fprintf('Faces:    %d\n', size(F,1));
fprintf('UVs:      %d\n', size(UVcoords,1));

fprintf('Export complete. Ready for three.js testing.\n');
