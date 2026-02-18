function segments = isolines(M, scalarField, varargin)
%ISOLINES Extract iso-contour line segments from scalar field on manifold
%
% Syntax:
%   segments = bct.field.isolines(M, scalarField)
%   segments = bct.field.isolines(M, scalarField, 'NumLevels', 20)
%   segments = bct.field.isolines(M, scalarField, 'Levels', [0, 0.5, 1.0])
%   segments = bct.field.isolines(M, scalarField, 'Range', [min, max])
%
% Inputs:
%   M           - bct.Manifold object
%   scalarField - [nV×1] scalar field on vertices
%
% Optional Parameters:
%   'NumLevels' - Number of evenly-spaced contour levels (default: 20)
%   'Levels'    - Explicit array of contour values (overrides NumLevels)
%   'Range'     - [min, max] range for automatic levels (default: data range)
%   'Method'    - 'region' (default) or 'exact'
%                 'region': Fast region-based detection (geometry-processing.js style)
%                 'exact': Precise interpolation for each level
%
% Outputs:
%   segments - [N×6] array of line segments [x1,y1,z1,x2,y2,z2]
%              Each row is a segment suitable for viewer.addLine()
%
% Description:
%   Extracts iso-contours where the scalar field equals specific levels.
%   Uses efficient face-based region detection:
%   
%   1. Divide scalar range into regions separated by contour levels
%   2. For each face, check its 3 edges
%   3. If edge vertices are in different regions, edge crosses a contour
%   4. Interpolate crossing point along the edge
%   5. Each face contributes 0 or 2 crossing points (one segment)
%   
%   This is the same algorithm used in geometry-processing.js for efficient
%   isoline rendering. Much faster than contouring algorithms that trace
%   connected components.
%
% Examples:
%   % Extract 20 evenly-spaced contours
%   M = bct.data.load(Dataset="fsaverage6", Hemi="rh", Surface="pial");
%   solver = M.solvers();
%   d = solver.heatDistance.value(6653);
%   
%   isolines = bct.field.isolines(M, d);
%   
%   viewer = bct.ui.show(M);
%   viewer.setScalar(d);
%   viewer.addLine('Segments', isolines, 'Color', 0x000000, 'LineWidth', 1);
%
%   % Extract specific levels (e.g., equator at u=0)
%   dA = solver.heatDistance.value(6653);
%   dP = solver.heatDistance.value(978);
%   u = dA - dP;
%   
%   equator = bct.field.isolines(M, u, 'Levels', 0);
%   viewer.addLine('Segments', equator, 'Color', 0xff0000, 'LineWidth', 2);
%
%   % Custom range and number of levels
%   isolines = bct.field.isolines(M, d, ...
%       'NumLevels', 30, ...
%       'Range', [10, 50]);
%
% See also: bct.field.grid, bct.field.toSegments, bct.ui.manifold.Viewer.addLine

% Input validation
arguments
    M (1,1) {mustBeA(M, 'bct.Manifold')}
    scalarField (:,1) double
end

arguments (Repeating)
    varargin
end

% Parse optional parameters
p = inputParser();
p.addParameter('NumLevels', 20, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('Levels', [], @(x) isnumeric(x) && isvector(x));
p.addParameter('Range', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
p.addParameter('Method', 'region', @(x) ismember(x, {'region', 'exact'}));
p.parse(varargin{:});

opts = p.Results;

% Validate scalar field
nV = M.numVertices();
if length(scalarField) ~= nV
    error('bct:field:isolines:SizeMismatch', ...
        'Scalar field must have length %d (number of vertices), got %d', ...
        nV, length(scalarField));
end

% Determine contour levels
if ~isempty(opts.Levels)
    % Explicit levels provided
    levels = opts.Levels(:)';  % Row vector
else
    % Generate evenly-spaced levels
    if ~isempty(opts.Range)
        minVal = opts.Range(1);
        maxVal = opts.Range(2);
    else
        minVal = min(scalarField);
        maxVal = max(scalarField);
    end
    
    if minVal >= maxVal
        warning('bct:field:isolines:InvalidRange', ...
            'Scalar field has no variation (min=%.6f, max=%.6f)', minVal, maxVal);
        segments = zeros(0, 6);
        return;
    end
    
    levels = linspace(minVal, maxVal, opts.NumLevels + 2);
    levels = levels(2:end-1);  % Exclude endpoints
end

% Get mesh data
V = M.Vertices;
F = M.Faces;
nF = size(F, 1);

% Choose method
if strcmp(opts.Method, 'region')
    segments = extractRegionMethod_(V, F, scalarField, levels);
else
    segments = extractExactMethod_(V, F, scalarField, levels);
end

fprintf('Extracted %d isoline segments from %d levels\n', ...
    size(segments, 1), length(levels));

end


%% Helper Functions

function segments = extractRegionMethod_(V, F, scalarField, levels)
%EXTRACTREGIONMETHOD_ Fast region-based contour extraction
%
% Uses geometry-processing.js algorithm:
% - Divide scalar range into regions
% - Find edges crossing region boundaries
% - Each face contributes 0 or 2 crossing points

% Compute spacing between levels
if length(levels) > 1
    spacing = levels(2) - levels(1);
else
    spacing = 1.0;  % Single level, arbitrary spacing
end

minLevel = min(levels);
nF = size(F, 1);

% Preallocate (estimate: ~2 segments per face on average)
maxSegments = nF * 2;
segmentBuffer = zeros(maxSegments, 6);
segCount = 0;

% For each face
for f = 1:nF
    faceVerts = F(f, :);
    crossings = zeros(0, 3);  % Crossing points for this face
    
    % Check each edge of the face (3 edges)
    for e = 1:3
        v1 = faceVerts(e);
        v2 = faceVerts(mod(e, 3) + 1);
        
        val1 = scalarField(v1);
        val2 = scalarField(v2);
        
        % Which region does each vertex belong to?
        region1 = floor((val1 - minLevel) / spacing);
        region2 = floor((val2 - minLevel) / spacing);
        
        % Edge crosses contour if vertices are in different regions
        if region1 ~= region2
            % Edge may cross multiple levels - record all crossings
            minReg = min(region1, region2);
            maxReg = max(region1, region2);
            
            % For each crossed boundary
            for reg = (minReg + 1):maxReg
                targetLevel = reg * spacing + minLevel;
                
                % Linear interpolation parameter
                t = (targetLevel - val1) / (val2 - val1);
                t = max(0, min(1, t));  % Clamp to [0,1]
                
                % Interpolate 3D position
                crossPoint = V(v1, :) + t * (V(v2, :) - V(v1, :));
                crossings(end+1, :) = crossPoint;
            end
        end
    end
    
    % Process crossings - should be even number (pairs)
    nCross = size(crossings, 1);
    if nCross >= 2 && mod(nCross, 2) == 0
        % Pair up crossings - sort by first coordinate to maintain consistency
        if nCross > 2
            % Multiple crossings - pair them up
            % Sort by distance along first edge direction
            [~, sortIdx] = sort(crossings(:, 1));
            crossings = crossings(sortIdx, :);
        end
        
        % Create segments from pairs
        for pairIdx = 1:2:nCross
            segCount = segCount + 1;
            if segCount > maxSegments
                % Expand buffer if needed
                segmentBuffer = [segmentBuffer; zeros(nF * 2, 6)];
                maxSegments = size(segmentBuffer, 1);
            end
            segmentBuffer(segCount, :) = [crossings(pairIdx, :), crossings(pairIdx+1, :)];
        end
    end
end

% Trim to actual size
segments = segmentBuffer(1:segCount, :);

end


function segments = extractExactMethod_(V, F, scalarField, levels)
%EXTRACTEXACTMETHOD_ Precise per-level contour extraction
%
% Processes each level independently for exact interpolation

nF = size(F, 1);
numLevels = length(levels);

% Preallocate
maxSegments = nF * numLevels;
segmentBuffer = zeros(maxSegments, 6);
segCount = 0;

% For each contour level
for levelIdx = 1:numLevels
    level = levels(levelIdx);
    
    % For each face
    for f = 1:nF
        faceVerts = F(f, :);
        crossings = zeros(0, 3);
        
        % Check each edge
        for e = 1:3
            v1 = faceVerts(e);
            v2 = faceVerts(mod(e, 3) + 1);
            
            val1 = scalarField(v1);
            val2 = scalarField(v2);
            
            % Check if edge crosses this level
            if (val1 <= level && val2 >= level) || (val1 >= level && val2 <= level)
                % Interpolate crossing point
                if abs(val2 - val1) < 1e-12
                    t = 0.5;  % Avoid division by zero
                else
                    t = (level - val1) / (val2 - val1);
                    t = max(0, min(1, t));
                end
                
                crossPoint = V(v1, :) + t * (V(v2, :) - V(v1, :));
                crossings(end+1, :) = crossPoint;
            end
        end
        
        % Add segment if exactly 2 crossings
        if size(crossings, 1) == 2
            segCount = segCount + 1;
            if segCount > maxSegments
                segmentBuffer = [segmentBuffer; zeros(nF * numLevels, 6)];
                maxSegments = size(segmentBuffer, 1);
            end
            segmentBuffer(segCount, :) = [crossings(1, :), crossings(2, :)];
        end
    end
end

% Trim to actual size
segments = segmentBuffer(1:segCount, :);

end
