function segments = toSegments(streamlines)
%TOSEGMENTS Convert streamlines to line segments for visualization
%
% Syntax:
%   segments = bct.field.toSegments(streamlines)
%
% Inputs:
%   streamlines - Cell array {N×1} where each cell contains [K×3] polyline
%
% Outputs:
%   segments - [M×6] array of line segments [x1,y1,z1,x2,y2,z2]
%              where M is the total number of segments across all streamlines
%
% Description:
%   Converts a cell array of polylines (streamlines) into a flat array
%   of line segments suitable for viewer.addLine() method.
%   
%   Each polyline with K points generates K-1 segments.
%   Segments from all streamlines are concatenated into one array.
%
% Examples:
%   % Generate streamlines
%   M = bct.data.load(Dataset="fsaverage6", Hemi="rh", Surface="pial");
%   [parallels, meridians] = bct.field.grid(M, 6653, 978);
%   
%   % Convert to segments
%   meridianSegs = bct.field.toSegments(meridians);
%   parallelSegs = bct.field.toSegments(parallels);
%   
%   % Visualize
%   viewer = bct.ui.show(M);
%   viewer.addLine('Segments', meridianSegs, 'Color', 0xff0000);
%   viewer.addLine('Segments', parallelSegs, 'Color', 0x0000ff);
%
% See also: bct.field.streamline, bct.field.grid, bct.ui.manifold.Viewer.addLine

% Input validation
if ~iscell(streamlines)
    error('bct:field:toSegments:InvalidInput', ...
        'Input must be a cell array of streamlines');
end

% Preallocate (estimate total segments)
totalSegments = 0;
for i = 1:length(streamlines)
    line = streamlines{i};
    if ~isempty(line) && size(line, 1) >= 2
        totalSegments = totalSegments + size(line, 1) - 1;
    end
end

segments = zeros(totalSegments, 6);
segIdx = 1;

% Convert each streamline to segments
for i = 1:length(streamlines)
    polyline = streamlines{i};
    
    % Skip empty or single-point polylines
    N = size(polyline, 1);
    if N < 2
        continue;
    end
    
    % Validate polyline is [K×3]
    if size(polyline, 2) ~= 3
        warning('bct:field:toSegments:InvalidPolyline', ...
            'Streamline %d has %d columns (expected 3), skipping', ...
            i, size(polyline, 2));
        continue;
    end
    
    % Generate segments for this polyline
    numSegs = N - 1;
    for j = 1:numSegs
        segments(segIdx, 1:3) = polyline(j, :);      % Start point
        segments(segIdx, 4:6) = polyline(j+1, :);    % End point
        segIdx = segIdx + 1;
    end
end

% Trim unused rows (in case some streamlines were skipped)
segments = segments(1:segIdx-1, :);

if isempty(segments)
    warning('bct:field:toSegments:NoSegments', ...
        'No valid segments generated from input streamlines');
end

end
