function animate(B, viewer, sig)
%ANIMATE Animate a time-varying signal on the mesh.
%   bct.show.animate(B, viewer) animates the first signal in B.Signals
%   over time using the time vector from B.Time.
%
%   bct.show.animate(B, viewer, sig) animates a specific signal object.
%
%   The animation updates the vertex colors of the mesh in the viewer
%   for each time point in B.Time.t_vec.
%
%   Inputs:
%       B      - Bct object with Time and Signals
%       viewer - viewer3d handle from bct.show.mesh
%       sig    - (optional) specific Signal object to animate

% Check if signal was provided
if nargin < 3
    if isempty(B.Signals)
        error('bct:NoSignals', 'Bct object has no Signals to animate.');
    end
    sig = B.Signals(1);
end

% Check if B.Time exists and has time vector
if isempty(B.Time) || isempty(B.Time.t_vec)
    warning('bct:NoTimeVector', ...
        'B.Time has no time vector. Cannot animate. Use bct.show.signal for static display.');
    return;
end

% Get number of time points
T = B.Time.T;

% Validate signal has correct dimensions
if size(sig.Data, 2) ~= T
    error('bct:DimensionMismatch', ...
        'Signal has %d time points but B.Time.T = %d', size(sig.Data, 2), T);
end

% Animate through time
for k = 1:T
    viewer.Children.VertexColors = bct.show.x2rgb(real(sig.Data(:, k)));
    drawnow;
end

end