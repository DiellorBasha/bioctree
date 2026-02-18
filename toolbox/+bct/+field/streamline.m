function streamlines = streamline(M, directionField, varargin)
%STREAMLINE Compute streamlines from a tangent direction field on manifold
%
% Syntax:
%   streamlines = bct.field.streamline(M, directionField)
%   streamlines = bct.field.streamline(M, directionField, 'NumSeeds', 30)
%   streamlines = bct.field.streamline(M, directionField, 'SeedFaces', [1,100,200])
%
% Inputs:
%   M              - bct.Manifold object
%   directionField - Field struct (face support, vector3 or tangent2) or
%                    [nFaces×3] numeric array of 3D direction vectors
%
% Optional Parameters:
%   'NumSeeds'      - Number of random seed faces (default: 20)
%   'SeedFaces'     - Specific face indices to seed from (overrides NumSeeds)
%   'MaxSteps'      - Maximum integration steps per streamline (default: 500)
%   'LoopThreshold' - Distance threshold to consider loop closed (default: 2.0)
%   'MinStepLength' - Minimum step length before terminating (default: 0.01)
%   'StepSizeScale' - Step size scaling factor (default: 0.5)
%   'BothDirections'- Integrate forward and backward (default: false)
%   'OnlyClosedLoops' - Only return closed loops (default: false)
%
% Outputs:
%   streamlines - Cell array {N×1} where each cell contains [K×3] polyline
%                 positions in 3D space
%
% Description:
%   Integrates streamlines using smooth vertex-based interpolation and Euler
%   integration with surface projection. The face-based direction field is
%   first averaged to vertices, then streamlines are integrated by:
%     1. Looking up direction at nearest vertex
%     2. Taking Euler step along direction
%     3. Projecting back to surface (nearest face tangent plane)
%   
%   Integration terminates when:
%     - Loop closure detected (distance to seed < LoopThreshold)
%     - Maximum steps reached
%     - Stuck at singularity (steps too small)
%
%   This approach produces smooth streamlines compared to face-to-face
%   navigation which would produce jagged polylines.
%
%   Direction field should be face-based 3D vectors in world coordinates,
%   tangent to the surface. If provided as Field struct with tangent2 type,
%   it will be automatically converted to vector3 using the frame basis.
%   If provided as numeric array, it must be [nFaces×3].
%
% Examples:
%   % From direction field computation
%   M = bct.data.load(Dataset="fsaverage6", Hemi="rh", Surface="pial");
%   phi = M.connection('trivial', 'singularities', [6653; 978], 'weights', [1; 1]);
%   trans = bct.manifold.connection.transport(M, phi, 'sign', 'minus');
%   result = bct.manifold.query.dual(M, trans.combinedTransport.value, ...
%                                     'seedFace', 1, 'seedValue', 0);
%   
%   geom = M.geometry();
%   dirVec = cos(result.alpha_face) .* geom.face.tangent1.value + ...
%            sin(result.alpha_face) .* geom.face.tangent2.value;
%   
%   % Compute streamlines
%   streamlines = bct.field.streamline(M, dirVec, 'NumSeeds', 30);
%
%   % Visualize
%   allSegments = [];
%   for s = 1:length(streamlines)
%       polyline = streamlines{s};
%       N = size(polyline, 1);
%       if N < 2, continue; end
%       segments = zeros(N-1, 6);
%       for i = 1:N-1
%           segments(i, 1:3) = polyline(i, :);
%           segments(i, 4:6) = polyline(i+1, :);
%       end
%       allSegments = [allSegments; segments];
%   end
%   
%   viewer = bct.ui.show(M);
%   viewer.addLine('Segments', allSegments, 'Color', 0xff0000, 'LineWidth', 2);
%
%   % Only closed loops
%   loops = bct.field.streamline(M, dirVec, 'OnlyClosedLoops', true);
%
% See also: bct.manifold.connection.transport, bct.manifold.query.dual

% Input validation
arguments
    M (1,1) {mustBeA(M, 'bct.Manifold')}
    directionField  % Field struct or numeric array
end

arguments (Repeating)
    varargin
end

% Parse optional parameters
p = inputParser();
p.addParameter('NumSeeds', 20, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('SeedFaces', [], @(x) isnumeric(x) && isvector(x));
p.addParameter('MaxSteps', 500, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('LoopThreshold', 2.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('MinStepLength', 0.01, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('StepSizeScale', 0.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('BothDirections', false, @islogical);
p.addParameter('OnlyClosedLoops', false, @islogical);
p.parse(varargin{:});

opts = p.Results;

% Extract direction vectors
if isstruct(directionField)
    % Field struct
    bct.field.validate(directionField);
    
    if ~strcmp(directionField.support, 'face')
        error('bct:field:streamline:InvalidSupport', ...
            'Direction field must have face support, got: %s', directionField.support);
    end
    
    if ~ismember(directionField.valueType, {'vector3', 'tangent2'})
        error('bct:field:streamline:InvalidValueType', ...
            'Direction field must be vector3 or tangent2, got: %s', directionField.valueType);
    end
    
    % Extract values
    if strcmp(directionField.valueType, 'tangent2')
        % Convert tangent2 to vector3 using frame
        if ~isfield(directionField, 'frame') || isempty(directionField.frame)
            error('bct:field:streamline:MissingFrame', ...
                'tangent2 fields require frame field');
        end
        % Convert: v3D = v[0]*t1 + v[1]*t2
        dirValues = directionField.value(:,1) .* directionField.frame(:,1,:) + ...
                    directionField.value(:,2) .* directionField.frame(:,2,:);
        dirValues = squeeze(dirValues);  % [nFaces×3]
    else
        dirValues = directionField.value;
    end
else
    % Numeric array
    dirValues = directionField;
end

% Validate dimensions
nFaces = size(M.Faces, 1);
if size(dirValues, 1) ~= nFaces
    error('bct:field:streamline:SizeMismatch', ...
        'Direction field size (%d) does not match number of faces (%d)', ...
        size(dirValues, 1), nFaces);
end

if size(dirValues, 2) ~= 3
    error('bct:field:streamline:InvalidDimension', ...
        'Direction vectors must be [N×3] array, got [%d×%d]', ...
        size(dirValues, 1), size(dirValues, 2));
end

% Get topology and geometry
geom = M.geometry();
faceCentroids = geom.face.centroids.value;
faceNormals = geom.face.normals.value;

% Convert face-based direction field to vertex-based (for smooth interpolation)
nVertices = size(M.Vertices, 1);
directionVtx = zeros(nVertices, 3);
count = zeros(nVertices, 1);

for k = 1:3
    for f = 1:nFaces
        v = M.Faces(f, k);
        directionVtx(v, :) = directionVtx(v, :) + dirValues(f, :);
        count(v) = count(v) + 1;
    end
end

directionVtx = directionVtx ./ count;
directionVtx = directionVtx ./ vecnorm(directionVtx, 2, 2);  % Normalize
directionVtx(~isfinite(directionVtx)) = 0;

% Determine seed positions (convert face indices to positions)
if ~isempty(opts.SeedFaces)
    seedFaces = opts.SeedFaces(:);
    if max(seedFaces) > nFaces || min(seedFaces) < 1
        error('bct:field:streamline:InvalidSeedFaces', ...
            'Seed face indices out of range [1, %d]', nFaces);
    end
    seedPositions = faceCentroids(seedFaces, :);
else
    % Random face centroids as seeds
    seedFaces = randperm(nFaces, min(opts.NumSeeds, nFaces));
    seedPositions = faceCentroids(seedFaces(:), :);
end

nSeeds = size(seedPositions, 1);
streamlines = cell(nSeeds, 1);

% Integrate each streamline
for s = 1:nSeeds
    streamlines{s} = integrateSingleStreamline_(seedPositions(s, :), ...
        directionVtx, M.Vertices, faceCentroids, faceNormals, M, opts);
end

% Filter for closed loops if requested
if opts.OnlyClosedLoops
    closedMask = false(nSeeds, 1);
    for s = 1:nSeeds
        line = streamlines{s};
        if size(line, 1) > 10  % Must have enough points
            distToStart = norm(line(end,:) - line(1,:));
            closedMask(s) = distToStart < opts.LoopThreshold;
        end
    end
    streamlines = streamlines(closedMask);
end

end


%% Helper Functions

function positions = integrateSingleStreamline_(seedPos, directionVtx, ...
    vertices, faceCentroids, faceNormals, M, opts)
%INTEGRATESINGLESTREAMLINE_ Integrate one streamline using vertex interpolation
%
% Uses smooth vertex-based interpolation and Euler integration with
% surface projection for smooth streamlines.

% Storage
positions = zeros(opts.MaxSteps, 3);
positions(1, :) = seedPos;

currentPos = seedPos;
stuckCount = 0;
actualSteps = 1;

for step = 2:opts.MaxSteps
    % Get direction at nearest vertex (smooth interpolation)
    [~, vid] = min(vecnorm(vertices - currentPos, 2, 2));
    direction = directionVtx(vid, :);
    
    % Check for zero direction (singularity)
    dirNorm = norm(direction);
    if dirNorm < 1e-10
        break;  % At singularity
    end
    direction = direction / dirNorm;  % Normalize
    
    % Euler step
    p_new = currentPos + opts.StepSizeScale * direction;
    
    % Project back to surface (nearest face tangent plane)
    [~, fID] = min(vecnorm(faceCentroids - p_new, 2, 2));
    v0 = vertices(M.Faces(fID, 1), :);
    n = faceNormals(fID, :);
    
    % Project to face tangent plane
    currentPos = p_new - dot(p_new - v0, n) * n;
    
    positions(step, :) = currentPos;
    actualSteps = step;
    
    % Check for loop closure
    if step > 10
        distToSeed = norm(currentPos - seedPos);
        if distToSeed < opts.LoopThreshold
            % Closed loop - add seed position to close it
            positions(step + 1, :) = seedPos;
            actualSteps = step + 1;
            break;
        end
    end
    
    % Check if step is too small (stuck at singularity)
    if step > 2
        stepLength = norm(positions(step, :) - positions(step-1, :));
        if stepLength < opts.MinStepLength
            stuckCount = stuckCount + 1;
            if stuckCount > 10
                break;  % Stuck
            end
        else
            stuckCount = 0;
        end
    end
end

% Trim unused rows
positions = positions(1:actualSteps, :);

end
