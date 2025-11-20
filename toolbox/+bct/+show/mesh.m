function viewer = mesh(B, varargin)
%MESH Create a 3D visualization of the mesh with light gray vertex colors.
%   viewer = bct.show.mesh(B) creates a visualization using the high-performance
%   visualizer with light gray default coloring.
%
%   viewer = bct.show.mesh(B, 'Parent', parent) creates the viewer in the
%   specified parent container (e.g., a panel in a UI).
%
%   Additional Name-Value Parameters:
%       'Parent'     - Parent container for the viewer
%       'ColorMap'   - Colormap to use (default: 'gray')
%       'WireFrame'  - Show wireframe (true/false)
%       'Center'     - Center mesh at origin (true/false), default: true
%       'Title'      - Figure title
%
%   Inputs:
%       B      - Bct object with Manifold
%
%   Returns:
%       viewer - viewer3d handle for further customization
%
%   Example:
%       B = bct.io.import.mesh('mesh.mat');
%       viewer = bct.show.mesh(B);
%       viewer = bct.show.mesh(B, 'Parent', myPanel);

% Parse optional arguments
p = inputParser;
addParameter(p, 'Parent', [], @(x) isempty(x) || isgraphics(x) || isa(x, 'images.ui.graphics3d.Viewer3D'));
addParameter(p, 'ColorMap', 'gray', @(x) ischar(x) || isstring(x) || isnumeric(x));
addParameter(p, 'WireFrame', false, @islogical);
addParameter(p, 'Center', true, @islogical);
addParameter(p, 'Title', 'Surface Mesh', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});

% Use visualizer for high-performance rendering
if isempty(p.Results.Parent)
    viewer = bct.show.visualizer(B, ...
        'ColorMap', p.Results.ColorMap, ...
        'WireFrame', p.Results.WireFrame, ...
        'Center', p.Results.Center, ...
        'Title', p.Results.Title);
else
    viewer = bct.show.visualizer(B, ...
        'Parent', p.Results.Parent, ...
        'ColorMap', p.Results.ColorMap, ...
        'WireFrame', p.Results.WireFrame, ...
        'Center', p.Results.Center);
end

end