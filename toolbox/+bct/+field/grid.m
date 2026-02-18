function [parallels, meridians, u] = grid(M, pole1, pole2, varargin)
%GRID Generate parallels and meridians on manifold surface
%
% Syntax:
%   [parallels, meridians] = bct.field.grid(M, pole1, pole2)
%   [parallels, meridians, u] = bct.field.grid(M, pole1, pole2)
%   [parallels, meridians, u] = bct.field.grid(M, pole1, pole2, 'Name', Value)
%
% Inputs:
%   M     - bct.Manifold object
%   pole1 - Vertex index of first pole ("anterior")
%   pole2 - Vertex index of second pole ("posterior")
%
% Optional Parameters:
%   'NumParallels'    - Number of parallel contour levels (default: 20)
%   'NumMeridians'    - Number of meridian streamlines (default: 20)
%   'ParallelMethod'  - 'isoline' (default) or 'streamline'
%                       'isoline' extracts u=constant contours (more accurate)
%                       'streamline' integrates perpendicular to gradient
%   'MaxSteps'        - Maximum steps per streamline (default: 500)
%   'Normalize'       - Normalize coordinate field u (default: true)
%   'LoopThreshold'   - Distance for loop closure (default: 2.0)
%   'ParallelRange'   - [min, max] percentile range for parallels (default: [2, 98])
%
% Outputs:
%   parallels - Cell array {N×1} of parallel curves
%               If 'ParallelMethod' is 'isoline': Each cell contains [K×3]
%                 interpolated points where edges cross the contour level
%               If 'ParallelMethod' is 'streamline': Each cell contains [K×3]
%                 integrated streamline polyline positions
%   meridians - Cell array {M×1} of meridian streamlines (always integrated)
%               Each cell contains [K×3] polyline positions
%   u         - [nV×1] scalar coordinate field (signed distance: d1 - d2)
%
% Description:
%   Generates a coordinate grid on the manifold surface using heat distances
%   from two pole vertices. The grid consists of:
%   
%   1. **Coordinate field u**: Signed distance field u = d(pole1) - d(pole2)
%      where d(v) is the heat-based geodesic distance from pole v.
%      This acts like a "latitude" coordinate.
%   
%   2. **Meridians**: Streamlines that flow along ∇u (gradient direction)
%      These connect the two poles and are analogous to longitude lines.
%      Computed by integrating along the gradient field.
%   
%   3. **Parallels**: Iso-contour lines where u = constant
%      These circle around the poles and are analogous to latitude lines.
%      By default, extracted as level sets of u (more accurate than integration).
%      Can optionally be computed as streamlines perpendicular to ∇u.
%   
%   The gradient is computed using halfedge cross-normal accumulation,
%   the same robust method used in the heat distance solver.
%   
%   **Note on parallel methods**:
%   - 'isoline' (default): Extracts true level sets u=constant by finding
%     edge crossings and interpolating. More accurate representation of
%     parallels as latitude-like curves. Points may be disconnected.
%   - 'streamline': Integrates along n × ∇u (perpendicular to gradient).
%     Produces continuous curves but may drift from exact iso-contours
%     due to integration error.
%
% Examples:
%   % Generate grid with default parameters (parallels as iso-contours)
%   M = bct.data.load(Dataset="fsaverage6", Hemi="rh", Surface="pial");
%   [parallels, meridians, u] = bct.field.grid(M, 6653, 978);
%   
%   % Use streamline integration for parallels instead
%   [parallels, meridians] = bct.field.grid(M, 6653, 978, 'ParallelMethod', 'streamline');
%   
%   % More contour levels with custom range
%   [parallels, meridians] = bct.field.grid(M, 6653, 978, ...
%       'NumParallels', 30, 'NumMeridians', 30, ...
%       'ParallelRange', [5, 95]);
%   
%   % Visualize the grid
%   viewer = bct.ui.show(M);
%   viewer.setScalar(u);  % Show coordinate field
%   
%   % Convert to line segments and add to viewer
%   meridianSegs = bct.field.toSegments(meridians);
%   parallelSegs = bct.field.toSegments(parallels);
%   
%   viewer.addLine('Segments', meridianSegs, 'Color', 0xff0000, 'LineWidth', 2);
%   viewer.addLine('Segments', parallelSegs, 'Color', 0x0000ff, 'LineWidth', 2);
%   viewer.addPoint('Indices', [6653; 978], 'Color', 0x00ff00, 'Radius', 5);
%
% See also: bct.field.streamline, bct.field.toSegments,
%           bct.field.generate.faceGradient, bct.manifold.solve.heatDistance

% Input validation
arguments
    M (1,1) {mustBeA(M, 'bct.Manifold')}
    pole1 (1,1) double {mustBeInteger, mustBePositive}
    pole2 (1,1) double {mustBeInteger, mustBePositive}
end

arguments (Repeating)
    varargin
end

% Parse optional parameters
p = inputParser();
p.addParameter('NumParallels', 20, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('NumMeridians', 20, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('ParallelMethod', 'isoline', @(x) ismember(x, {'isoline', 'streamline'}));
p.addParameter('MaxSteps', 500, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('Normalize', true, @islogical);
p.addParameter('LoopThreshold', 2.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('ParallelRange', [2, 98], @(x) isnumeric(x) && numel(x) == 2);
p.parse(varargin{:});

opts = p.Results;

% Validate pole indices
nV = M.numVertices();
if pole1 < 1 || pole1 > nV
    error('bct:field:grid:InvalidPole', ...
        'pole1 must be in range [1, %d], got %d', nV, pole1);
end
if pole2 < 1 || pole2 > nV
    error('bct:field:grid:InvalidPole', ...
        'pole2 must be in range [1, %d], got %d', nV, pole2);
end
if pole1 == pole2
    error('bct:field:grid:IdenticalPoles', ...
        'pole1 and pole2 must be different vertices');
end

%% Compute heat distances from both poles
solvers = M.solvers();

if ~isfield(solvers, 'heatDistance')
    error('bct:field:grid:NoHeatSolver', ...
        'Manifold must have heatDistance solver. Call M.solvers() first.');
end

dA = solvers.heatDistance.value(pole1);  % Distance from pole1
dP = solvers.heatDistance.value(pole2);  % Distance from pole2

%% Construct signed coordinate field
u = (dA - dP);  % Signed distance: positive near pole1, negative near pole2

if opts.Normalize
    u = (u - mean(u)) / std(u);  % Normalize to zero mean, unit std
end

%% Compute gradient using halfedge cross-normal accumulation
gradU = bct.field.generate.faceGradient(M, u);

%% Generate direction fields

% Meridians: gradient direction (flows from pole to pole)
X_mer = gradU;
X_mer = X_mer ./ max(vecnorm(X_mer, 2, 2), 1e-12);

% Parallels: perpendicular to gradient (circles around poles)
geom = M.geometry();
Nf = geom.face.normals.value;  % [nF×3] face normals

X_par = cross(Nf, X_mer, 2);   % Cross product: n × ∇u
X_par = X_par ./ max(vecnorm(X_par, 2, 2), 1e-12);

%% Integrate streamlines

% Meridian streamlines (along gradient)
meridians = bct.field.streamline(M, X_mer, ...
    'NumSeeds', opts.NumMeridians, ...
    'MaxSteps', opts.MaxSteps, ...
    'LoopThreshold', opts.LoopThreshold);

% Parallel generation (method-dependent)
if strcmp(opts.ParallelMethod, 'isoline')
    % Extract iso-contours at specific levels of u
    parallels = extractIsolines_(M, u, opts.NumParallels, opts.ParallelRange);
    parallelMethod = 'iso-contour extraction';
else
    % Integrate streamlines perpendicular to gradient
    parallels = bct.field.streamline(M, X_par, ...
        'NumSeeds', opts.NumParallels, ...
        'MaxSteps', opts.MaxSteps, ...
        'LoopThreshold', opts.LoopThreshold);
    parallelMethod = 'streamline integration';
end

% Report
fprintf('Grid generation complete:\n');
fprintf('  Poles: [%d, %d]\n', pole1, pole2);
fprintf('  Coordinate range: [%.3f, %.3f]\n', min(u), max(u));
fprintf('  Meridians: %d streamlines\n', length(meridians));
fprintf('  Parallels: %d contours (%s)\n', length(parallels), parallelMethod);

end


%% Helper Functions

function isolines = extractIsolines_(M, u, numLevels, percentileRange)
%EXTRACTISOLINES_ Extract iso-contour lines from scalar field
%
% This extracts approximate iso-contours by:
% 1. Defining contour levels in the scalar field u
% 2. For each level, finding vertices near that value
% 3. Connecting those vertices via mesh edges to form polylines

% Get manifold data
V = M.Vertices;
F = M.Faces;
nV = size(V, 1);
nF = size(F, 1);

% Define contour levels
lo = prctile(u, percentileRange(1));
hi = prctile(u, percentileRange(2));
levels = linspace(lo, hi, numLevels);

% Get topology for edge connectivity
topo = M.topology();
edges = topo.edgeList.value;  % [nE×2] edge list

isolines = cell(numLevels, 1);

% Extract each iso-contour
for i = 1:numLevels
    level = levels(i);
    
    % Find edges that cross this level
    % An edge crosses the level if u(v1) and u(v2) straddle the level
    u1 = u(edges(:,1));
    u2 = u(edges(:,2));
    
    % Edges where level is between u1 and u2
    crosses = ((u1 <= level) & (u2 >= level)) | ((u1 >= level) & (u2 <= level));
    crossingEdges = edges(crosses, :);
    
    if isempty(crossingEdges)
        isolines{i} = zeros(0, 3);  % Empty contour
        continue;
    end
    
    % Interpolate crossing points
    u1_cross = u(crossingEdges(:,1));
    u2_cross = u(crossingEdges(:,2));
    
    % Linear interpolation parameter: t such that u = u1 + t*(u2-u1) = level
    t = (level - u1_cross) ./ (u2_cross - u1_cross);
    t = max(0, min(1, t));  % Clamp to [0,1]
    
    % Interpolate 3D positions
    v1_pos = V(crossingEdges(:,1), :);
    v2_pos = V(crossingEdges(:,2), :);
    contourPoints = v1_pos + t .* (v2_pos - v1_pos);
    
    % Store as polyline (could be multiple disconnected components)
    % For now, just store all points - proper contour tracing would connect them
    isolines{i} = contourPoints;
end

end
