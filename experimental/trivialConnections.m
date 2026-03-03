%% Trivial Connections (Sphere, coexact) — bct script
% Canonical singularities at anterior/posterior poles (sum = 2)

% ----------------------------
% Setup: grab bct objects
% ----------------------------
fs4path='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial'
[vertices, faces] = freesurfer_read_surf(fs4path);
M=bct.Manifold(vertices,faces);
Mf=M.flip;clear M; M=Mf;
    topo = M.topology;
    geom = M.geometry('includeDual', true);
    ops=M.operators;
    solvers = M.solvers;
    %eigen = M.eigenmodes(1000);
%%
% Canonical singularities (sphere: sum = 2)
singularityVertices = [6653; 978];
singularityVertices = [45 878];
singularityWeights = [1.0; -1.0];

result = bct.field.direction(M, 'singularities', singularityVertices, 'weights', singularityWeights);

result = bct.field.direction(M, 'singularities', poles)
% Globally consistent direction field - should be added as a core property
% of the manifold 

%% Connection 
%Connection: the rule that tells you how tangent spaces on neighboring triangles are related (the per-edge rotation data).
% Gauge: a choice of local coordinate frames (bases) on each triangle used to express vectors; changing gauge changes the numeric coordinates of the same geometric vector.

 % This is the globally consisent direction field as in
 % geometry-processin-js
% Transport: applying the connection along a path to compare or move vectors from one triangle to another.

% From geometry-processing-js, 

%% Create scalar and vector fields and express them in manifold coordinates
    % precompute transport angle for each face-edge corssing. 
%% Create analytic attractors 

%% Integrate semi-implicit Euler + damping
% 
% Per particle per step:
% 
% read (faceId, bary, vel2)
% read force2 = force2_face[faceId] (or compute from grad2 and perp)
% update vel2 (accel + damping + clamp)
% update bary using vel2 * dt mapped into barycentric deltas

% while bary has negative component:
    % determine crossed edge

% neighbor = neighborFace
% rotate velocity using transportAngle
% remap bary to neighbor face
% continue (cap hops)
% 
% write back updated state
%%
solver_global = bct.manifold.solve.heatDistance(M, 't_heat', 100.0);
d_global = solver_global.value(singularityVertices);
    %d_global=sum(d_global,2);
d_global = d_global(:,1)-d_global(:,2);
F = M.Faces;                 % nF x 3 (1-based indices)
d_face =  mean(d_global(F),2); % nF x 1, simple per-face average
    ell = double(geom.edge.lengths.value(:));   % |E| x 1
    Ltri = median(ell);                         % typical edge length
%%   
    mag = vecnorm(result.directionVectors, 2, 2);           % nF x 1 arrow lengths (current)
    mref = prctile(mag, 95);          % "large but typical" arrow length (avoid outlier max)
    targetFrac = 0.6;                 % largest typical arrow occupies 60% of triangle edge
    Lmax = targetFrac * Ltri;
    s = Lmax / max(mref, 1e-12);      % ONE global scaling factor
    scaledVectors = result.directionVectors * s;


    mag = vecnorm(result.orthogonalVectors, 2, 2);           % nF x 1 arrow lengths (current)
    mref = prctile(mag, 95);          % "large but typical" arrow length (avoid outlier max)
    targetFrac = 0.6;                 % largest typical arrow occupies 60% of triangle edge
    Lmax = targetFrac * Ltri;
    s = Lmax / max(mref, 1e-12);   
    scaledOrthogonal = result.orthogonalVectors * s;

%% Visualize

viewer = bct.ui.show(M);
pause(1/2)
viewer.background('Color', 'white')
pause
viewer.setScalar(d_global);
pause('off')
pause
viewer.addVector(-scaledVectors, ...,
    'Name', 'tangentVector', ...
    'Support', 'face', ...
    'Positions', geom.face.centroids.value, ...
    'Normals', geom.face.normals.value, ...
    'Style', 'arrow', ...
    'Stride', 2, ...           % Show every 50th vector
    'LengthScale', 2, ...
    'Color', 0x000000, ...
    'LineWidth', 2);
pause
viewer.addVector(scaledOrthogonal, ...,
    'Name', 'orthogonalVector', ...
    'Support', 'face', ...
    'Positions', geom.face.centroids.value, ...
    'Normals', geom.face.normals.value, ...
    'Style', 'arrow', ...
    'Stride', 2, ...           % Show every 50th vector
    'LengthScale', 2, ...
    'Color', 0x000000, ...
    'LineWidth', 2);
%%
% Add direction field (use stride to reduce density)
viewer.addVector(-result.directionVectors, ...,
    'Name', 'directionVector', ...
    'Support', 'face', ...
    'Positions', geom.face.centroids.value, ...
    'Normals', geom.face.normals.value, ...
    'Style', 'arrow', ...
    'Stride', 2, ...           % Show every 50th vector
    'LengthScale', 2, ...
    'Color', 0x000000, ...
    'LineWidth', 2);

%blue 0x0000ff
%yellow f0ff24
%%
viewer.addVector(-result.orthogonalVectors, ...,
    'Name', 'orthogonalVector', ...
    'Support', 'face', ...
    'Positions', geom.face.centroids.value, ...
    'Normals', geom.face.normals.value, ...
    'Style', 'arrow', ...
    'Stride', 2, ...           % Show every 50th vector
    'LengthScale', 2, ...
    'Color', 0x000000, ...
    'LineWidth', 2);


%%
% Add singularities
viewer.addPoint('Indices', singularityVertices, ...
    'Color', 0x000000, ...
    'Radius', 2.0);
%%
solver_global = bct.manifold.solve.heatDistance(M, 't_heat', 100.0);
d_global = solver_global.value(6653);

% Even more global (experiment with values)
solver_veryGlobal = bct.manifold.solve.heatDistance(M, 't_heat', 100.0);
d_veryGlobal = solver_veryGlobal.value(45);




%%
solver_global = bct.manifold.solve.heatDistance(M, 't_heat', 1000.0);
d_global = solver_global.value(6653);

F = M.Faces;                 % nF x 3 (1-based indices)
d_face = zscore( mean(d_global(F),2)); % nF x 1, simple per-face average
ell = double(geom.edge.lengths.value(:));   % |E| x 1
Ltri = median(ell);                         % typical edge length
mag = vecnorm(X, 2, 2);           % nF x 1 arrow lengths (current)
mref = prctile(mag, 95);          % "large but typical" arrow length (avoid outlier max)

targetFrac = 0.6;                 % largest typical arrow occupies 60% of triangle edge
Lmax = targetFrac * Ltri;

s = Lmax / max(mref, 1e-12);      % ONE global scaling factor
scaledVectors = X * s;

%scaledVectors = result.directionVectors .* d_face;   % implicit expansion (R2016b+)
% or: scaledVectors = result.directionVectors .* repmat(d_face,1,3);

%%

viewer.addVector(scaledVectors, ...,
    'Name', 'orthogonalVector', ...
    'Support', 'face', ...
    'Positions', geom.face.centroids.value, ...
    'Normals', geom.face.normals.value, ...
    'Style', 'arrow', ...
    'Stride', 2, ...           % Show every 50th vector
    'LengthScale', 2, ...
    'Color', 0x000000, ...
    'LineWidth', 2);
%%
viewer.addScalar(zscore(d_global));

%% Compute Streamlines from Direction Field
% Compute smooth streamlines
streamlines = bct.field.streamline(M, directionVectors, 'NumSeeds', 30);

% Visualize with viewer
allSegments = [];
for s = 1:length(streamlines)
    polyline = streamlines{s};
    N = size(polyline, 1);
    if N < 2, continue; end
    
    segments = zeros(N-1, 6);
    for i = 1:N-1
        segments(i, 1:3) = polyline(i, :);
        segments(i, 4:6) = polyline(i+1, :);
    end
    allSegments = [allSegments; segments];
end

viewer = bct.ui.show(M);
viewer.addLine('Segments', allSegments, 'Color', 0xff0000, 'LineWidth', 2);
%% 

viewer.addLine('Segments', allSegments, 'Color', 0xff0000, 'LineWidth', 2);
%%
viewer.addPoint('Indices', singularityVertices, 'Color', 0x0000ff, 'Radius', 5);
%%
solver_global = bct.manifold.solve.heatDistance(M, 't_heat', 100.0);
d_global = solver_global.value(6653);

% Even more global (experiment with values)
solver_veryGlobal = bct.manifold.solve.heatDistance(M, 't_heat', 100.0);
d_veryGlobal = solver_veryGlobal.value(45);

%%
viewer.addScalar(d_global);



%%
dA = solvers.heatDistance.value(6653);
dP = solvers.heatDistance.value(978);
u  = dA - dP;              % AP scalar, zero-crossing is a natural equator


% Extract 20 evenly-spaced contours
isolines = bct.field.isolines(M, dP );

% Visualize
viewer = bct.ui.show(M);
viewer.setScalar(dP);
viewer.addLine('Segments', isolines, 'Color', 0x000000,'LineWidth', 5);

% Extract specific level (e.g., equator)
dA = solver.heatDistance.value(6653);
dP = solver.heatDistance.value(978);
u = dA - dP;
equator = bct.field.isolines(M, u, 'Levels', 0);
viewer.addLine('Segments', equator, 'Color', 0xff0000, 'LineWidth', 5);
%%

% Generate parallels and meridians between two poles
[parallels, meridians, u] = bct.field.grid(M, 6653, 978);

%%


% Default solver (local diffusion)
solver_local = M.solvers();  % Uses t_heat = mean_edge_length²
d_local = solver_local.heatDistance.value(45);

% Create solver with larger t_heat for global diffusion
% Try multiplying the default by 10x, 100x, or more
solver_global = bct.manifold.solve.heatDistance(M, 't_heat', 10.0);
d_global = solver_global.value(6653);

% Even more global (experiment with values)
solver_veryGlobal = bct.manifold.solve.heatDistance(M, 't_heat', 100.0);
d_veryGlobal = solver_veryGlobal.value(45);

viewer=bct.ui.show(M)
viewer.background('Color', 'White');
viewer.setScalar(d_global)
    d_global = solver_global.value(45);
    viewer.setScalar(d_global)

solver_rr = bct.manifold.solve.heatDistance(M, 't_heat', 0.1);
 d_verylocal = solver_rr.value(45);
    viewer.setScalar(d_verylocal)
% Extract 20 evenly-spaced contours
isolines = bct.field.isolines(M, d_verylocal );
viewer.addLine('Segments', isolines, 'Color', 0x000000,'LineWidth', 3);
clim=[min(us{1}), max(us{end})]

%%

% 3. Add particle flow visualization
viewer.addParticleFlow(-directionVectors);

%% Compute streamlines - NOW JUST ONE LINE!
streamlines = bct.field.streamline(M, directionVectors, 'NumSeeds', 30);

% Or with options:
streamlines = bct.field.streamline(M, directionVectors, ...
    'NumSeeds', 50, ...
    'MaxSteps', 1000, ...
    'LoopThreshold', 2.0, ...
    'OnlyClosedLoops', false);

% Only get closed loops:
loops = bct.field.streamline(M, directionVectors, ...
    'NumSeeds', 50, ...
    'OnlyClosedLoops', true);

%%
% Basic usage

result = bct.field.direction(M, 'singularities', [6653, 978], 'weights', [1, 1]);
% Access connection details if needed
conn = result.connection;  % Full connection structure included
combinedTransport = conn.combinedTransport.value;

% Or compute connection separately (cached)
conn = M.connection('trivial', 'singularities', [6653, 978], 'weights', [1, 1]);
% conn now has: .trivialConnection, .combinedTransport, .geometricTransport, .connectionTransport

% Use pre-computed connection
result = bct.field.direction(M, conn);

% Custom seed face/angle
result = bct.field.direction(M, 'singularities', [100, 500], ...
    'seedFace', 10, 'seedValue', pi/4);