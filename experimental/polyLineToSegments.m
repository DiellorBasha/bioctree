%% Helper function: Convert polyline to line segments
function segments = polylineToSegments(polyline)
    % Convert [N×3] polyline to [M×6] segments where M = N-1
    % Each row: [x1,y1,z1, x2,y2,z2]
    
    N = size(polyline, 1);
    if N < 2
        segments = [];
        return;
    end
    
    segments = zeros(N-1, 6);
    for i = 1:N-1
        segments(i, 1:3) = polyline(i, :);      % Start point
        segments(i, 4:6) = polyline(i+1, :);    % End point
    end
end

