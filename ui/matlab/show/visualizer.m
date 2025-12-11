function viewer = visualizer(varargin)
%VISUALIZER High-performance 3D visualization for Bct objects
%   viewer = bct.show.visualizer(B) visualizes a Bct object's mesh
%   viewer = bct.show.visualizer(B, 'Signal', idx) visualizes a specific signal
%   viewer = bct.show.visualizer(surfaceMesh) visualizes a surfaceMesh object
%
%   Inputs:
%       B - Bct object with Manifold (and optionally Signals)
%       surfaceMesh - MATLAB surfaceMesh object
%       vertices, faces - Nx3 and Mx3 arrays for mesh geometry
%
%   Name-Value Parameters:
%       'Signal'          - Signal index to display (1-based), default: 1
%       'SignalData'      - Custom signal data [Nx1] or [NxT] to display
%       'TimePoint'       - Time point to display for time-varying signals (1-based)
%       'ColorMap'        - Colormap name or Mx3 array (default: 'parula')
%       'Alpha'           - Transparency (0-1), default: 1
%       'BackgroundColor' - Background color [R G B], default: [0 0 0]
%       'WireFrame'       - Show wireframe (true/false), default: false
%       'VerticesOnly'    - Show vertices as points (true/false), default: false
%       'Title'           - Figure title string
%       'Parent'          - Parent container (viewer3d, uifigure, uipanel, etc.)
%       'Center'          - Center mesh at origin (true/false), default: true
%
%   Returns:
%       viewer - viewer3d handle
%
%   Examples:
%       % Visualize Bct mesh with default gray
%       viewer = bct.show.visualizer(B);
%
%       % Visualize first signal
%       viewer = bct.show.visualizer(B, 'Signal', 1);
%
%       % Visualize with custom colormap
%       viewer = bct.show.visualizer(B, 'Signal', 1, 'ColorMap', 'turbo');
%
%       % Visualize time point 50
%       viewer = bct.show.visualizer(B, 'Signal', 1, 'TimePoint', 50);
%
%       % Visualize in a panel
%       fig = uifigure; panel = uipanel(fig);
%       viewer = bct.show.visualizer(B, 'Parent', panel);

[B, sMesh, signalData, alpha, color, bgcolor, wireFrame, points, name, useColorMap, parent, centerMesh] = parseInputs(varargin{:});

[B, sMesh, signalData, alpha, color, bgcolor, wireFrame, points, name, useColorMap, parent, centerMesh] = parseInputs(varargin{:});

% Process surfaceMesh (either from Bct or directly provided)
if ~isempty(sMesh)
    % surfaceMesh already created
    data = sMesh;
    
    % Center mesh if requested
    if centerMesh
        center = vertexCenter(sMesh);
        translate(sMesh, -center);
    end
    
    % Set up mesh data
    dataLocations = sMesh.Vertices;
    dataTriConnectivity = sMesh.Faces;
    dataInput = triangulation(double(dataTriConnectivity), double(dataLocations));
    
    % Get mesh color from signal data or vertex colors
    if ~isempty(signalData)
        % Use provided signal data
        meshColor = signalData;
    elseif ~isempty(sMesh.FaceColors)
        meshColor = sMesh.FaceColors;
    elseif ~isempty(sMesh.VertexColors)
        meshColor = sMesh.VertexColors;
    else
        meshColor = [];
    end
    
else
    % Legacy support for direct vertices/faces or triangulation
    if isa(B, 'triangulation')
        dataInput = B;
        dataLocations = B.Points;
        meshColor = [];
    else
        error('bct:visualizer:InvalidInput', 'Input must be Bct, surfaceMesh, or triangulation');
    end
end

% Apply colormap if needed
if isempty(meshColor)
    % No signal data - use uniform mid-gray color
    meshColor = repmat([0.7 0.7 0.7], size(dataLocations, 1), 1);
elseif useColorMap
    % Signal data provided with colormap - use Z-coordinate for coloring
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

% Create or use existing viewer
newfigure = false;

if isa(parent,'images.ui.graphics3d.Viewer3D')
    % Parent is an existing Viewer3D object
    viewer = parent;
elseif isempty(parent)
    % No parent provided - create new viewer in standalone figure
    viewer = viewer3d("BackgroundColor",bgcolor,"BackgroundGradient","off","RenderingQuality","high");
    viewer.Mode.Default.CameraVector = [-1 -1 1];
    newfigure = true;
else
    % Parent is a container (uifigure, uipanel, GridLayout, Tab)
    % Create viewer3d inside the parent container
    viewer = viewer3d(parent, "BackgroundColor",bgcolor,"BackgroundGradient","off","RenderingQuality","high");
    viewer.Mode.Default.CameraVector = [-1 -1 1];
end

viewer.Busy = true;

% Set title if provided
if ~isempty(name)
    parentObj = viewer.Parent;
    if isa(parentObj, 'matlab.ui.Figure')
        parentObj.Name = name;
    end
end

% Render surface/points using high-performance API
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

viewer.Busy = false;
end

%--------------------------------------------------------------------------
function [B, sMesh, signalData, alpha, color, bgcolor, wireFrame, points, name, useColorMap, parent, centerMesh] = parseInputs(varargin)
%PARSEINPUTS Parse and validate inputs for visualizer
narginchk(1, 20)
matlab.images.internal.errorIfgpuArray(varargin{:});

% Initialize outputs
B = [];
sMesh = [];
signalData = [];

% Parse first argument (required)
firstArg = varargin{1};

if isa(firstArg, 'bct.bct')
    % Bct object provided
    B = firstArg;
    parseIndex = 2;
    
elseif isa(firstArg, 'surfaceMesh')
    % surfaceMesh provided directly
    sMesh = firstArg;
    parseIndex = 2;
    
elseif isa(firstArg, 'triangulation')
    % triangulation provided directly (legacy support)
    B = firstArg;  % Store in B for later processing
    parseIndex = 2;
    
elseif isnumeric(firstArg) && length(varargin) > 1 && isnumeric(varargin{2})
    % Vertices and faces provided
    [vertices, faces] = validateFacesVertices(firstArg, varargin{2});
    B = triangulation(faces, vertices);  % Store as triangulation
    parseIndex = 3;
    
else
    error('bct:visualizer:InvalidInput', ...
        'First argument must be Bct object, surfaceMesh, triangulation, or vertices array');
end

% Process parent and remaining name-value pairs
[parent, remainingInputs] = processParent(varargin{parseIndex:end});

% Parse name-value pairs
[signalIdx, customSignalData, timePoint, alpha, color, bgcolor, wireFrame, points, name, useColorMap, centerMesh] = ...
    validateNameValue(remainingInputs{:});

% Process Bct object if provided
if isa(B, 'bct.bct')
    % Create surfaceMesh from Manifold
    sMesh = bct.io.convert.manifoldToSurfaceMesh(B.Manifold);
    
    % Extract signal data if requested
    if ~isempty(customSignalData)
        % Custom signal data provided
        signalData = processSignalData(customSignalData, B.Manifold.N, timePoint, color);
        
    elseif ~isempty(signalIdx) && ~isempty(B.Signals)
        % Extract signal from Bct
        if signalIdx > length(B.Signals)
            error('bct:visualizer:InvalidSignalIndex', ...
                'Signal index %d out of range (1-%d)', signalIdx, length(B.Signals));
        end
        
        sig = B.Signals(signalIdx);
        
        % Extract spatial data based on signal domain
        if isa(sig.Domain, 'bct.Joint')
            % Joint domain signal (e.g., Manifold-Time)
            % Extract spatial component for specified time point
            if isempty(timePoint)
                timePoint = 1;  % Default to first time point
            end
            
            % Check if Joint is Manifold × Time (spatial-temporal)
            if isa(sig.Domain.A, 'bct.Manifold') || isa(sig.Domain.B, 'bct.Time')
                % Data is [N × T], extract time slice
                if size(sig.Data, 2) < timePoint
                    error('bct:visualizer:InvalidTimePoint', ...
                        'Time point %d out of range (1-%d)', timePoint, size(sig.Data, 2));
                end
                signalData = sig.Data(:, timePoint);
            else
                error('bct:visualizer:UnsupportedJoint', ...
                    'Can only visualize Joint signals with Manifold as first domain');
            end
            
        elseif isa(sig.Domain, 'bct.Manifold')
            % Signal defined on Manifold domain [N × 1]
            signalData = sig.Data;
            if size(signalData, 2) > 1
                % Take first column if multi-column
                signalData = signalData(:, 1);
            end
            
        else
            error('bct:visualizer:UnsupportedDomain', ...
                'Can only visualize signals on Manifold or Joint (Manifold×Time) domains');
        end
        
        % Convert signal to RGB colors using colormap
        signalData = processSignalData(signalData, B.Manifold.N, 1, color);
    end
    
    % Set vertex colors on surfaceMesh
    if ~isempty(signalData)
        sMesh.VertexColors = signalData;
    end
end

end

%--------------------------------------------------------------------------
function rgbColors = processSignalData(signalData, expectedN, timePoint, colormap_data)
%PROCESSSIGNALDATA Convert signal data to RGB colors
%   Handles scalar data [Nx1] or time-varying data [NxT]

% Validate size
if size(signalData, 1) ~= expectedN
    error('bct:visualizer:SignalSizeMismatch', ...
        'Signal data has %d vertices but mesh has %d', size(signalData, 1), expectedN);
end

% Extract time point if multi-column
if size(signalData, 2) > 1
    if nargin < 3 || isempty(timePoint)
        timePoint = 1;
    end
    signalData = signalData(:, timePoint);
end

% Check if already RGB
if size(signalData, 2) == 3
    rgbColors = signalData;
    return;
end

% Convert scalar to RGB using provided colormap
% Normalize to [0, 1]
minVal = min(signalData);
maxVal = max(signalData);

if maxVal > minVal
    normalized = (signalData - minVal) / (maxVal - minVal);
else
    normalized = 0.5 * ones(size(signalData));
end

% Use provided colormap or default to parula
if nargin >= 4 && ~isempty(colormap_data)
    cmap = colormap_data;
else
    cmap = parula(256);
end

colorIndices = round(normalized * (size(cmap, 1) - 1)) + 1;
rgbColors = cmap(colorIndices, :);
end

%--------------------------------------------------------------------------
function [signalIdx, signalData, timePoint, alpha, color, bgcolor, wireFrame, points, name, useColorMap, centerMesh] = validateNameValue(nvPairs)
arguments
    nvPairs.Signal {mustBeNumeric, mustBePositive, mustBeInteger} = []
    nvPairs.SignalData {mustBeNumeric} = []
    nvPairs.TimePoint {mustBeNumeric, mustBePositive, mustBeInteger} = []
    nvPairs.ColorMap {isempty(nvPairs.ColorMap)} = 'Not Set'
    nvPairs.Alpha {validateAlpha(nvPairs.Alpha)} = 1
    nvPairs.BackgroundColor {validateBackgroundColor(nvPairs.BackgroundColor)} = [0 0 0]
    nvPairs.WireFrame {validateWireFrame(nvPairs.WireFrame)} = false
    nvPairs.VerticesOnly {validateVerticesOnly(nvPairs.VerticesOnly)} = false
    nvPairs.Title {validateTitle(nvPairs.Title)} = ""
    nvPairs.Center {mustBeNumericOrLogical} = true
end

signalIdx = nvPairs.Signal;
signalData = nvPairs.SignalData;
timePoint = nvPairs.TimePoint;

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
centerMesh = logical(nvPairs.Center);
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
        
        % Check if parent is a valid type for viewer3d
        validParent = false;
        
        if isa(parent,'images.ui.graphics3d.Viewer3D')
            validParent = true;
        elseif isa(parent,'matlab.ui.Figure') && ~isa(getCanvas(parent), 'matlab.graphics.primitive.canvas.JavaCanvas')
            validParent = true;
        elseif isa(parent,'matlab.ui.container.Panel')  % uipanel
            validParent = true;
        elseif isa(parent,'matlab.ui.container.GridLayout')  % GridLayout
            validParent = true;
        elseif isa(parent,'matlab.ui.container.Tab')  % Tab
            validParent = true;
        end
        
        if validParent
            remainingInputs([parentIndices * 2, parentIndices * 2 - 1]) = [];
        else
            error('bct:visualizer:invalidParent', ...
                'Parent must be a viewer3d, uifigure, uipanel, GridLayout, or Tab object');
        end
    end
end
end
%--------------------------------------------------------------------------
function tf = iIsParam(arg, paramName)
tf = matlab.internal.datatypes.isScalarText(arg) ...
    && startsWith(paramName, arg, "IgnoreCase", true);
end

%--------------------------------------------------------------------------
function mustBeNumericOrLogical(x)
    if ~(isnumeric(x) || islogical(x))
        error('bct:visualizer:InvalidType', 'Value must be numeric or logical');
    end
end

% Copyright 2022-2024 The MathWorks, Inc.