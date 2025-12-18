fs6 = bct_fsaverage('lh', 'saved');
Manifold = fs6.Manifold;

F = double(Manifold.Faces);
V = Manifold.Vertices;

TR = triangulation(F, V);

Nv = size(V,1);
Nf = size(F,1);

% Face centroids
COM = (V(F(:,1),:) + V(F(:,2),:) + V(F(:,3),:)) / 3;

%% ------------------------------------------------------------------------
% Scalar field w (0-form)
% ------------------------------------------------------------------------
params.source = 1000;
params.sigma  = 4;
params.metric = "geometry";

w = bct.brush.apply('patch_gaussian', Manifold, params);
w = full(w(:));   % enforce column


%% ------------------------------------------------------------------------
% DEC construction
% ------------------------------------------------------------------------
DEC = DiscreteExteriorCalculus(F, V);
disp('initiated DEC')

%% ------------------------------------------------------------------------
% Gradient
% ------------------------------------------------------------------------
gradW = DEC.gradient(w);        % [Nf x 3]

gradW_unit = gradW ./ vecnorm(gradW,2,2);
gradW_unit(~isfinite(gradW_unit)) = 0;

%% ------------------------------------------------------------------------
% Tangent frame decomposition
% ------------------------------------------------------------------------
Nf_vec = cross( ...
    V(F(:,2),:) - V(F(:,1),:), ...
    V(F(:,3),:) - V(F(:,1),:) );
Nf_vec = Nf_vec ./ vecnorm(Nf_vec,2,2);

e1 = V(F(:,2),:) - V(F(:,1),:);
e1 = e1 - sum(e1 .* Nf_vec,2) .* Nf_vec;
e1 = e1 ./ vecnorm(e1,2,2);

e2 = cross(Nf_vec, e1, 2);

gx = sum(gradW .* e1, 2);
gy = sum(gradW .* e2, 2);

amplitude = hypot(gx, gy);
phase     = atan2(gy, gx);

%% ------------------------------------------------------------------------
% Divergence
% ------------------------------------------------------------------------
U = -gradW_unit;
divU = DEC.divergence(U);
divU = divU(:);
%%
Uvtx = zeros(Nv,3);
count = zeros(Nv,1);

for k = 1:3
    Uvtx(F(:,k),:) = Uvtx(F(:,k),:) + U;
    count(F(:,k))  = count(F(:,k))  + 1;
end

Uvtx = Uvtx ./ count;
Uvtx(~isfinite(Uvtx)) = 0;

% Normalize for clean streamlines (direction only)
Uvtx = Uvtx ./ vecnorm(Uvtx,2,2);
Uvtx(~isfinite(Uvtx)) = 0;
%%
seedVertex = params.source;
p = V(seedVertex,:);   % starting point in 3D
%%
dt     = 0.5;
nSteps = 200;

seedVertex = params.source;
p = V(seedVertex,:);

curve = zeros(nSteps,3);

for k = 1:nSteps
    curve(k,:) = p;

    % Nearest vertex for direction lookup
    [~, vid] = min(vecnorm(V - p,2,2));
    v = Uvtx(vid,:);

    % Euler step
    p_new = p + dt * v;

    % --- Nearest-face projection ---
    [~, fID] = min(vecnorm(COM - p_new, 2, 2));
    v0 = V(F(fID,1),:);
    n  = faceNormals(fID,:);

    % Project to face plane
    p = p_new - dot(p_new - v0, n) * n;
end

curve = curve(any(curve,2),:);

%%
seedVertex = params.source;

% Radius in vertices (roughly corresponds to sigma)
seedRadius = 2 * params.sigma;

% Compute geodesic-like neighborhood (cheap approximation)
d = vecnorm(V - V(seedVertex,:),2,2);
seedVerts = find(d < seedRadius);

% Subsample to avoid clutter
nSeeds = 30;
seedVerts = seedVerts(randperm(numel(seedVerts), ...
                min(nSeeds, numel(seedVerts))));

dt     = 0.5;
nSteps = 150;

curves = cell(numel(seedVerts),1);

for s = 1:numel(seedVerts)

    p = V(seedVerts(s),:);
    curve = zeros(nSteps,3);

    for k = 1:nSteps
        curve(k,:) = p;

        % Nearest vertex for vector lookup
        [~, vid] = min(vecnorm(V - p,2,2));
        v = Uvtx(vid,:);

        % Euler step
        p_new = p + dt * v;

        % Nearest-face projection
        [~, fID] = min(vecnorm(COM - p_new,2,2));
        v0 = V(F(fID,1),:);
        n  = faceNormals(fID,:);

        p = p_new - dot(p_new - v0, n) * n;
    end

    curves{s} = curve(any(curve,2),:);
end
