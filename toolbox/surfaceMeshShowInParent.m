function surfaceMeshShowInParent(varargin)

[data, alpha, color, bgcolor, wireFrame, points, name, useColorMap, parent] = parseInputs(varargin{:});

if isa(data, 'bct.bct')
B=data;
% Create surfaceMesh from Manifold
sMesh = bct.io.convert.manifoldToSurfaceMesh(B.Manifold);

% Get the vertex center before centering (for camera positioning)
center = vertexCenter(sMesh);

% Recenter the mesh to align with camera at origin
translate(sMesh, -center);  % translate modifies in-place

% Set light gray default vertex colors
% Convert scalar values to RGB using gray colormap
defaultColor = 0.5 * ones(B.Manifold.N, 1);  % Mid-range values for gray
grayColormap = gray(256);
% Map scalar values [0,1] to RGB using gray colormap
colorIndices = round(defaultColor * (size(grayColormap, 1) - 1)) + 1;
rgbColors = grayColormap(colorIndices, :);
sMesh.VertexColors = rgbColors;

% Calculate bounding box for automatic camera positioning
vertices = sMesh.Vertices;
meshSize = max(vertices) - min(vertices);
meshRadius = norm(meshSize) / 2;
data=sMesh;
end

meshColor = [];
if isa(data, 'surfaceMesh')
    dataLocations = data.Vertices;
    dataTriConnectivity = data.Faces;
    dataInput = triangulation(double(dataTriConnectivity), double(dataLocations));
    if ~isempty(data.FaceColors)
        meshColor  = data.FaceColors;
    elseif(~isempty(data.VertexColors))
        meshColor  = data.VertexColors;
    end
else
    dataLocations = data.Points;
    dataInput = data;
end

if isempty(meshColor) || useColorMap

    minVal = min(dataLocations(:,3));
    maxVal = max(dataLocations(:,3));

    if (maxVal ~= minVal)

        numOfColorBins = size(color, 1);
        index = round((numOfColorBins-1)*((maxVal - dataLocations(:,3))/(maxVal - minVal)))+1;
        meshColor = color(index,:);
    else
        meshColor = color(1,:);
    end
end

newfigure = false;

if isa(parent,'images.ui.graphics3d.Viewer3D')
    % Parent is an existing Viewer3D object
    viewer = parent;

elseif isempty(parent)
    % No parent provided
    viewer = viewer3d("BackgroundColor",bgcolor,"BackgroundGradient","off","RenderingQuality","high");
    viewer.Mode.Default.CameraVector = [-1 -1 1];
    newfigure = true;

else
    % Parent is a graphics object
    viewer = viewer3d(parent);
end
viewer.Busy = true;

% if ~isempty(name)
%     viewer.Parent.Name = name;
% end
if ~isempty(name)
    parentObj = viewer.Parent;
    if isa(parentObj, 'matlab.ui.Figure')
        parentObj.Name = name;
    end
end


if points
    images.ui.graphics3d.Points(viewer, 'Data', dataLocations, 'Alpha', alpha, ...
        'Color', meshColor, 'PointSize', 4);
    if wireFrame
        images.ui.graphics3d.Surface(viewer, 'Data', dataInput, 'Alpha', alpha, ...
            'Color', meshColor, 'WireFrame', wireFrame);
    end
else
    images.ui.graphics3d.Surface(viewer, 'Data', dataInput, 'Alpha', alpha, ...
        'Color', meshColor, 'WireFrame', wireFrame);
end
drawnow;

if newfigure
    viewer.Parent.Visible='on';
end
end

%--------------------------------------------------------------------------
function [data, alpha, color, bgcolor, wireFrame, points, name, useColorMap, parent] = parseInputs(varargin)
narginchk(1, 14)
matlab.images.internal.errorIfgpuArray(varargin{:});

if length(varargin) > 1 && isnumeric(varargin{1})

    [vertices, faces] = validateFacesVertices(varargin{1:2});

    data = triangulation(faces, vertices);
    parseIndex = 3;
else
    data = varargin{1};

    validateattributes(data,{'triangulation', ...
        'surfaceMesh'},{'real','nonsparse'}, mfilename,'data',1);
    parseIndex = 2;
end

[parent, remainingInputs] = processParent(varargin{parseIndex:end});

[alpha, color, bgcolor, wireFrame, points, name, useColorMap] = validateNameValue(remainingInputs{:});
end

%--------------------------------------------------------------------------
function [alpha, color, bgcolor, wireFrame, points, name, useColorMap] = validateNameValue(nvPairs)
arguments
    nvPairs.ColorMap {isempty(nvPairs.ColorMap)} = 'Not Set'
    nvPairs.Alpha {validateAlpha(nvPairs.Alpha)} = 1
    nvPairs.BackgroundColor {validateBackgroundColor(nvPairs.BackgroundColor)} = [0 0 0]
    nvPairs.WireFrame {validateWireFrame(nvPairs.WireFrame)} = false
    nvPairs.VerticesOnly {validateVerticesOnly(nvPairs.VerticesOnly)} = false
    nvPairs.Title {validateTitle(nvPairs.Title)} = ""

end
useColorMap = true;
if(strcmp(nvPairs.ColorMap,'Not Set'))
    useColorMap = false;
    nvPairs.ColorMap = 'Parula';
end
color = validateColorMap(nvPairs.ColorMap);
alpha = nvPairs.Alpha;
bgcolor = nvPairs.BackgroundColor;
wireFrame = nvPairs.WireFrame;
points = nvPairs.VerticesOnly;
name = nvPairs.Title;
end
%--------------------------------------------------------------------------
function cmap = validateColorMap(cmap)
try
    if ischar(cmap) || isstring(cmap)
        validateattributes(cmap,{'char','string'}, {'scalartext'}, ...
            'pattern', 'Colormap');

        % Use colormap approach of performing feval on text
        cmap = char(lower(cmap));
        k = min(strfind(cmap,'('));
        if ~isempty(k)
            cmap = feval(cmap(1:k-1),str2double(cmap(k+1:end-1)));
        else
            cmap = feval(cmap);
        end
    else
        % If string, let colormap function validate
        if ~ischar(cmap) && ~isstring(cmap)
            validateattributes(cmap,{'numeric'}, ...
                {'real','finite','nonnan','nonsparse','ncols',3,'>=',0,'<=',1}, ...
                'pattern', 'Colormap');
        end
    end
catch ME
    throwAsCaller(ME);
end
end

%--------------------------------------------------------------------------
function validateAlpha(alpha)
validateattributes(alpha, ...
    {'single','double'},{'real','scalar','nonsparse','>=',0,'<=',1});
end

%--------------------------------------------------------------------------
function validateBackgroundColor(bgColor)
pointclouds.internal.pcui.validateBackgroundColor ...
    ('surfaceMeshShow', bgColor);
end

%--------------------------------------------------------------------------
function validateWireFrame(wireFrame)
validateattributes(wireFrame,{'logical'}, {'scalar'});
end

%--------------------------------------------------------------------------
function validateVerticesOnly(vertices)
validateattributes(vertices,{'logical'}, {'scalar'});
end

%--------------------------------------------------------------------------
function validateTitle(title)
validateattributes(title, {'string', 'char'}, {});
end

%--------------------------------------------------------------------------
function [v, f] = validateFacesVertices(v, f)

validateattributes(v,{'single','double'},{'real','finite','nonsparse','ncols',3},mfilename,'vertices',1);
validateattributes(f,{'single','double'},{'integer','positive','ncols',3},mfilename,'faces',2);

% Validate that maximum of faces is less than the number of
% points
isValid = max(f(:)) <= size(v,1);
assert(isempty(isValid) || isValid, 'Invalid Input Data');
end
%--------------------------------------------------------------------------
function [parent, remainingInputs] = processParent(varargin)
parent = gobjects(0);
remainingInputs = {};

if nargin > 1
    % Expand struct inputs
    inputs = {};
    for i=1:length(varargin)
        if isstruct(varargin{i})
            inputs = [inputs namedargs2cell(varargin{i})]; %#ok<AGROW>
        else
            inputs{end+1} = varargin{i}; %#ok<AGROW>
        end
    end
    % Find parent and remove any parent references from 'remaining Inputs'
    parentIndices = find(cellfun(@(x)  iIsParam(x,"Parent"), inputs(1:2:end)));
    remainingInputs = inputs;
    if ~isempty(parentIndices)
        parent = inputs{parentIndices(end) * 2};
        if isa(parent,'images.ui.graphics3d.Viewer3D')
            remainingInputs([parentIndices * 2, parentIndices * 2 - 1]) = [];
        else
            if isa(parent,'matlab.ui.Figure') && ~isa(getCanvas(parent), ...
                    'matlab.graphics.primitive.canvas.JavaCanvas')

                remainingInputs([parentIndices * 2, parentIndices * 2 - 1]) = [];
            else
                error(message('images:volume:invalidViewer'));
            end
        end
    end
end
end
%--------------------------------------------------------------------------
function tf = iIsParam(arg, paramName)
tf = matlab.internal.datatypes.isScalarText(arg) ...
    && startsWith(paramName, arg, "IgnoreCase", true);
end

% Copyright 2022-2024 The MathWorks, Inc.