%% This script interpolates scattered data from vertex-time series into a 3D volume

% Interpolate onto surface vertices
F_t = F_alpha(:, t);  % data at one timepoint
F_interp = scatteredInterpolant(V, F_t, 'natural', 'none');
Faces = channel_tesselate(V, 0);

% Inputs
T = size(F_alpha, 2);   % Number of time steps
dz = 1;                 % Vertical spacing per time step (can be time in ms)
N = size(V, 1);

for t = 1:T
stack(t).V  = V+F_alpha(:,t); 
stack(t).C = F_alpha(:,t);
end

% Assume N = number of vertices, T = time steps
N = size(V, 1);
T = numel(stack);

% Create 3D array of vertex positions over time
V_stack = zeros(N, 3, T);
for t = 1:T
    V_stack(:,:,t) = stack(t).V;
end


t_original = 1:T;
t_interp = linspace(1, T, 100);  % Or any set of new time points
% Initialize
V_interp_stack = zeros(N, 3, numel(t_interp));
% Interpolate each coordinate (X, Y, Z) across time
for dim = 1:3
    V_interp_stack(:,dim,:) = interp1(t_original, squeeze(V_stack(:,dim,:))', t_interp, 'linear')';
end


%% Parametrization
[x, y, z] = deal(V(:,1), V(:,2), V(:,3));
[theta, phi, ~] = cart2sph(x, y, z);  % theta ~ azimuth, phi ~ elevation

u = rescale(theta, 0, 1);
v = rescale(phi, 0, 1);
[uq, vq] = meshgrid(linspace(0,1,100), linspace(0,1,100));
F_interp = scatteredInterpolant(u, v, F_alpha(:, t), 'natural', 'none');
image_2d = F_interp(uq, vq);
