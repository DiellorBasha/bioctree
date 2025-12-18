function viewer = plot(obj, varargin)
%PLOT Visualize data on the manifold mesh
%
%   viewer = manifold.plot()
%   viewer = manifold.plot('data', signalData)
%   viewer = manifold.plot('data', signalData, 'colormap', 'turbo')
%
% Name-Value Parameters:
%   'data'       - Signal data [N×1] to visualize (default: uniform gray)
%   'colormap'   - Colormap name ('parula', 'turbo', 'jet', 'redblue', 'hot')
%                  (default: 'parula')
%   'shading'    - Shading mode: 'interp' (default) or 'flat'
%   'symmetric'  - Use symmetric colormap scaling (default: false)
%   'wireframe'  - Show wireframe (default: false)
%   'alpha'      - Transparency 0-1 (default: 1)
%   'title'      - Figure title (default: '')
%   'parent'     - Parent container (default: create new figure)
%
% Outputs:
%   viewer - viewer3d handle
%
% Examples:
%   % Uniform gray mesh
%   viewer = manifold.plot();
%
%   % Signal with default colormap
%   viewer = manifold.plot('data', signal);
%
%   % Signal with turbo colormap
%   viewer = manifold.plot('data', signal, 'colormap', 'turbo');
%
%   % Symmetric colormap (for diverging data)
%   viewer = manifold.plot('data', signal, 'symmetric', true, ...
%       'colormap', 'redblue');
%
%   % Wireframe overlay
%   viewer = manifold.plot('data', signal, 'wireframe', true);
%
% See also: bct.show.visualizer, bct.show.x2rgb

arguments
    obj (1,1) bct.Manifold
end

% Parse name-value arguments
p = inputParser;
p.addParameter('data', [], @(x) isempty(x) || isnumeric(x));
p.addParameter('colormap', 'parula', @(x) ischar(x) || isstring(x));
p.addParameter('shading', 'interp', @(x) ischar(x) || isstring(x));
p.addParameter('symmetric', false, @islogical);
p.addParameter('wireframe', false, @islogical);
p.addParameter('alpha', 1, @(x) isnumeric(x) && x >= 0 && x <= 1);
p.addParameter('title', '', @(x) ischar(x) || isstring(x));
p.addParameter('parent', [], @(x) isempty(x) || isgraphics(x));
p.parse(varargin{:});

signalData = p.Results.data;
cmapName = p.Results.colormap;
useSymmetric = p.Results.symmetric;
wireFrame = p.Results.wireframe;
alpha = p.Results.alpha;
titleStr = p.Results.title;
parent = p.Results.parent;

% Get mesh geometry
V = obj.Vertices;
F = obj.Faces;

% Create surfaceMesh if not cached
if isempty(obj.SurfaceMesh)
    obj.SurfaceMesh = surfaceMesh(double(V), double(F));
end
sMesh = obj.SurfaceMesh;

% Process signal data to RGB colors
if isempty(signalData)
    % No signal - uniform mid-gray
    vertexColors = repmat([0.7 0.7 0.7], size(V, 1), 1);
else
    % Validate signal data size
    if numel(signalData) ~= size(V, 1)
        error('Manifold:plot:InvalidDataSize', ...
            'Signal data must be [N×1] where N=%d', size(V, 1));
    end
    
    % Convert signal to RGB using x2rgb
    vertexColors = bct.show.x2rgb(signalData(:), ...
        'colormap', cmapName, ...
        'symmetric', useSymmetric);
end

% Create triangulation for visualization
tri = triangulation(double(F), double(V));

% Create visualization
if isempty(parent)
    % Create new viewer
    viewer = viewer3d('BackgroundColor', [0 0 0], ...
        'BackgroundGradient', 'off', ...
        'RenderingQuality', 'high');
    viewer.Mode.Default.CameraVector = [-1 -1 1];
    newFigure = true;
else
    % Use provided parent
    viewer = viewer3d(parent, ...
        'BackgroundColor', [0 0 0], ...
        'BackgroundGradient', 'off', ...
        'RenderingQuality', 'high');
    viewer.Mode.Default.CameraVector = [-1 -1 1];
    newFigure = false;
end

viewer.Busy = true;

% Render surface
images.ui.graphics3d.Surface(viewer, 'Data', tri, ...
    'Alpha', alpha, ...
    'Color', vertexColors, ...
    'WireFrame', wireFrame);

% Set title if provided
if ~isempty(titleStr)
    parentObj = viewer.Parent;
    if isa(parentObj, 'matlab.ui.Figure')
        parentObj.Name = titleStr;
    end
end

drawnow;

% Make visible if new figure
if newFigure
    viewer.Parent.Visible = 'on';
end

viewer.Busy = false;

end
