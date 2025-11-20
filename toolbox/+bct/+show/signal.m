function viewer = signal(B, varargin)
%SIGNAL Display a static signal on the mesh.
%   viewer = bct.show.signal(B) displays the first signal from B.Signals
%   as vertex colors. If B has no Signals, displays a gray mesh with a warning.
%
%   viewer = bct.show.signal(B, signalIdx) displays signal at index signalIdx.
%
%   viewer = bct.show.signal(B, signalIdx, 'Parent', parent) uses specified
%   parent container.
%
%   Additional Name-Value Parameters:
%       'Parent'     - Parent container for the viewer
%       'ColorMap'   - Colormap to use (default: 'parula')
%       'TimePoint'  - Time point to display for time-varying signals (default: 1)
%
%   This function displays a single time point of a signal.
%   For animation of time-varying signals, use bct.show.animate instead.
%
%   Returns:
%       viewer - viewer3d handle

% Parse inputs
p = inputParser;
addOptional(p, 'signalIdx', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'Parent', [], @(x) isempty(x) || isgraphics(x) || isa(x, 'images.ui.graphics3d.Viewer3D'));
addParameter(p, 'ColorMap', 'parula', @(x) ischar(x) || isstring(x) || isnumeric(x));
addParameter(p, 'TimePoint', 1, @(x) isnumeric(x) && x > 0);
parse(p, varargin{:});

% Check if B has any Signals
if isempty(B.Signals)
    warning('bct:NoSignals', 'Bct object has no Signals. Displaying gray mesh.');
    viewer = bct.show.mesh(B, 'Parent', p.Results.Parent);
    return;
end

% Check if signal is time-varying
if ~isempty(B.Time) && B.Time.T > 1
    warning('bct:TimeVaryingSignal', ...
        'Signal has %d time points. Displaying time point %d. Use bct.show.animate for animation.', ...
        B.Time.T, p.Results.TimePoint);
end

% Use visualizer to display the signal
if isempty(p.Results.Parent)
    viewer = bct.show.visualizer(B, ...
        'Signal', p.Results.signalIdx, ...
        'TimePoint', p.Results.TimePoint, ...
        'ColorMap', p.Results.ColorMap, ...
        'Title', sprintf('Signal: %s', B.Signals(p.Results.signalIdx).Label));
else
    viewer = bct.show.visualizer(B, ...
        'Parent', p.Results.Parent, ...
        'Signal', p.Results.signalIdx, ...
        'TimePoint', p.Results.TimePoint, ...
        'ColorMap', p.Results.ColorMap);
end

end