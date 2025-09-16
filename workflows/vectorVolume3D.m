getSourceMap
% Get channel centroids
%% Sensor level
% Get channel centroids

% Loop through channels
nChan = length(chanfile.Channel);
pos3D = zeros(nChan, 3);
for i = 1:nChan
    loc = chanfile.Channel(i).Loc;
    if ~isempty(loc)
        % Average over all coils
        pos3D(i,:) = mean(loc, 2)';
    end
end

V=pos3D(chans,:);
%%
% Get alpha signal and downsample
fs_ds = 300;
ds_factor = fs / fs_ds;

% Check that factor is an integer
if mod(ds_factor, 1) ~= 0
    error('Sampling rate ratio must be an integer.');
end

% Downsample each channel
F_ds = downsample(F', ds_factor)';  % Transpose twice to apply along time

alpha_range = [8, 12];       % Alpha band in Hz
nChannels = size(F_ds,1);
% Create Morlet wavelet filter bank
fb = cwtfilterbank('SignalLength', size(F_ds,2), ...
                   'SamplingFrequency', fs_ds, ...
                   'FrequencyLimits', alpha_range, ...
                   'VoicesPerOctave', 12);

% Allocate result
F_alpha = zeros(nChannels, size(F_ds,2));

for ch = 1:nChannels
    [cfs, freqs] = cwt(F_ds(ch,:), 'FilterBank', fb);  % freqs already in [8 12]
    filteredSig = icwt(cfs);
    amplitude = abs(cfs);  % [nFreqs × nTime]
    power = abs(cfs).^2;
    phase = angle(cfs);  % [nFreqs × nTime], values in [-π, π]
    phase_unwrapped = unwrap(angle(cfs), [], 2);  % unwrap along time


  % Step 3: Threshold wavelet coefficients by power
    power_coeffs = abs(cfs).^2;                          % [freqs x time]
    threshold = 0.3 * max(power_coeffs(:));              % e.g., 30% of max
    mask = any(power_coeffs > threshold);    
 
 % Step 5: Get average amplitude and phase over frequency
complex_mean = mean(cfs, 1);                      % Vector average

F_alpha_mask(ch,:) = filteredSig.* mask; 
F_alpha(ch,:) =  filteredSig;
F_alpha_amp(ch,:)   = abs(complex_mean);          % Envelope
F_alpha_phase(ch,:) = angle(complex_mean);        % Phase
F_alpha_unwrapped(ch,:)=unwrap(angle(complex_mean), [], 2);  % unwrap along time
    
end

%% Flow
% Spatial gradient of the MEG singal 
t = 600;  % Midpoint or event onset
f = F_alpha(:, t);
k = 5;  % Number of neighbors for gradient estimation
N = size(V, 1);
gradients = zeros(N, 3);
 % Build k-d tree for neighbor search
    Mdl = KDTreeSearcher(V);

    for i = 1:N
        % Get k-nearest neighbors (including self)
        [idx, D] = knnsearch(Mdl, V(i,:), 'K', k+1);  % +1 to include self
        idx = idx(2:end);  % remove self

        % Build matrix of position differences
        X = V(idx, :) - V(i, :);      % (k x 3)
        y = f(idx) - f(i);            % (k x 1)

        % Solve least squares: minimize ||X * grad - y||
        grad = X \ y;
        gradients(i, :) = grad';
    end

% Visualize with quiver3
figure;
quiver3(V(:,1), V(:,2), V(:,3), gradients(:,1), gradients(:,2), gradients(:,3), 2);
axis equal; title('Estimated Gradient Vectors at t=600');
xlabel('X'); ylabel('Y'); zlabel('Z');

%%

% Define grid
[xq, yq, zq] = meshgrid(linspace(min(V(:,1)), max(V(:,1)), 30), ...
                        linspace(min(V(:,2)), max(V(:,2)), 30), ...
                        linspace(min(V(:,3)), max(V(:,3)), 30));

% Interpolate vector components
Fx = scatteredInterpolant(V(:,1), V(:,2), V(:,3), gradients(:,1), 'linear', 'none');
Fy = scatteredInterpolant(V(:,1), V(:,2), V(:,3), gradients(:,2), 'linear', 'none');
Fz = scatteredInterpolant(V(:,1), V(:,2), V(:,3), gradients(:,3), 'linear', 'none');

% Evaluate on grid
U = Fx(xq, yq, zq);
Vv = Fy(xq, yq, zq);
W = Fz(xq, yq, zq);

% Seed points for streamlines
[sx, sy, sz] = ndgrid(linspace(min(V(:,1)), max(V(:,1)), 5), ...
                      linspace(min(V(:,2)), max(V(:,2)), 5), ...
                      linspace(min(V(:,3)), max(V(:,3)), 5));

% Plot
figure;
streamline(xq, yq, zq, U, Vv, W, sx, sy, sz);
hold on;
scatter3(V(:,1), V(:,2), V(:,3), 10, f, 'filled');  % Overlay sensor activity
colorbar; title('Streamlines of Gradient Field at t = 600');
xlabel('X'); ylabel('Y'); zlabel('Z'); axis equal;
%% Streaklines “From this source sensor and time, where does this activity go? What is the trail it leaves in space over time?”

seedIdx = 120;     % Sensor index
t0 = 10;          % Time point of origin
seed_ts = F_alpha(seedIdx, :);


%% Phase Velocity Field

H = hilbert(F_alpha')';  % Hilbert transform: sensors x time
phi = angle(H);           % Instantaneous phase: 265 x 1200
dphi_dt = diff(phi, 1, 2);  % size: 265 x 1199

% Compute spatial gradient at each time point

k = 5;  % nearest neighbors
numSensors = size(V,1);
T = size(dphi_dt,2);
grad_phi = zeros(numSensors, 3, T);  % 265 x 3 x 1199

for t = 1:T
    grad_phi(:,:,t) = estimate_gradients(V, phi(:,t), k);  % spatial gradient at time t
end

% Compute phase velocity field
v_phi = zeros(numSensors, 3, T);  % 265 x 3 x 1199

for t = 1:T
    grad_t = squeeze(grad_phi(:,:,t));     % 265 x 3
    dphi_dt_t = dphi_dt(:, t);             % 265 x 1
    grad_mag_sq = sum(grad_t.^2, 2);       % 265 x 1
    
    % Avoid division by zero
    grad_mag_sq(grad_mag_sq < 1e-6) = NaN;
    
    for i = 1:numSensors
        v_phi(i,:,t) = - (dphi_dt_t(i) / grad_mag_sq(i)) * grad_t(i,:);
    end
end


t_view = 600;
v_snapshot = squeeze(v_phi(:,:,t_view));

figure;
quiver3(V(:,1), V(:,2), V(:,3), ...
        v_snapshot(:,1), v_snapshot(:,2), v_snapshot(:,3), 3);
title(sprintf('Phase Velocity Field at t = %d', t_view));
xlabel('X'); ylabel('Y'); zlabel('Z'); axis equal;

%% Use pahse velocity fiedl to compute streamlines of wave propagation 

% Choose time point
t_view = 600;
v_snapshot = squeeze(v_phi(:,:,t_view));

% Create 3D grid for interpolation
[xq, yq, zq] = meshgrid(...
    linspace(min(V(:,1)), max(V(:,1)), 30), ...
    linspace(min(V(:,2)), max(V(:,2)), 30), ...
    linspace(min(V(:,3)), max(V(:,3)), 30));

% Interpolate each component
Fx = scatteredInterpolant(V(:,1), V(:,2), V(:,3), v_snapshot(:,1), 'linear', 'none');
Fy = scatteredInterpolant(V(:,1), V(:,2), V(:,3), v_snapshot(:,2), 'linear', 'none');
Fz = scatteredInterpolant(V(:,1), V(:,2), V(:,3), v_snapshot(:,3), 'linear', 'none');

% Evaluate on grid
U = Fx(xq, yq, zq);
Vv = Fy(xq, yq, zq);
W = Fz(xq, yq, zq);

% Streamline seed points (e.g., some sensors or a subgrid)
[sx, sy, sz] = ndgrid(...
    linspace(min(V(:,1)), max(V(:,1)), 5), ...
    linspace(min(V(:,2)), max(V(:,2)), 5), ...
    linspace(min(V(:,3)), max(V(:,3)), 5));

% Plot streamlines
figure;
streamline(xq, yq, zq, U, Vv, W, sx, sy, sz);
hold on;
scatter3(V(:,1), V(:,2), V(:,3), 20, 'filled');  % Sensor positions
title(sprintf('Streamlines of Phase Velocity at t = %d', t_view));
xlabel('X'); ylabel('Y'); zlabel('Z'); axis equal;

phase_t = phi(:, t_view);
threshold = pi / 16;  % Tolerance around 0 phase

% Find wavefront (isophase ≈ 0)
is_wavefront = abs(phase_t) < threshold;

% Plot on top of streamlines
scatter3(V(is_wavefront,1), V(is_wavefront,2), V(is_wavefront,3), ...
         80, 'r', 'filled');
legend('Streamlines', 'Sensors', 'Wavefront (\phi ≈ 0)');

%%

% Precompute tangent bases
k = 5;
tangentBasis = estimate_tangent_planes(V, k);  % size: N x 3 x 2

% Assume gradients already computed → grad_phi: N x 3 x T
grad_proj = zeros(size(grad_phi));  % N x 3 x T

for t = 1:T
    for i = 1:size(V,1)
        grad_vec = squeeze(grad_phi(i,:,t));      % 1 x 3
        T1 = squeeze(tangentBasis(i,:,1));        % 1 x 3
        T2 = squeeze(tangentBasis(i,:,2));        % 1 x 3
        % Project onto tangent plane
        grad_proj(i,:,t) = dot(grad_vec, T1)*T1 + dot(grad_vec, T2)*T2;
    end
end

v_phi_tan = zeros(size(v_phi));  % Tangent-only velocity

for t = 1:T
    grad_t = squeeze(grad_proj(:,:,t));    % Tangent-projected gradient
    dphi_dt_t = dphi_dt(:,t);
    grad_mag_sq = sum(grad_t.^2, 2);
    grad_mag_sq(grad_mag_sq < 1e-6) = NaN;

    for i = 1:size(V,1)
        v_phi_tan(i,:,t) = - (dphi_dt_t(i) / grad_mag_sq(i)) * grad_t(i,:);
    end
end


t_view = 600;
quiver3(V(:,1), V(:,2), V(:,3), ...
        v_phi_tan(:,1,t_view), v_phi_tan(:,2,t_view), v_phi_tan(:,3,t_view), 3);
axis equal;
title('Tangential Phase Velocity Vectors');


%% Use pahse velocity fiedl to compute streamlines of wave propagation 

t_view = 20;
v_snapshot = squeeze(v_phi_tan(:,:,t_view));  % 265 x 3

% Define 3D grid
[xq, yq, zq] = meshgrid(...
    linspace(min(V(:,1)), max(V(:,1)), 40), ...
    linspace(min(V(:,2)), max(V(:,2)), 40), ...
    linspace(min(V(:,3)), max(V(:,3)), 40));

% Interpolants for each vector component
Fx = scatteredInterpolant(V(:,1), V(:,2), V(:,3), v_snapshot(:,1), 'linear', 'none');
Fy = scatteredInterpolant(V(:,1), V(:,2), V(:,3), v_snapshot(:,2), 'linear', 'none');
Fz = scatteredInterpolant(V(:,1), V(:,2), V(:,3), v_snapshot(:,3), 'linear', 'none');

% Evaluate on grid
U = Fx(xq, yq, zq);
Vv = Fy(xq, yq, zq);
W = Fz(xq, yq, zq);

% Choose seed points from within the convex hull of V
seedIdx = randsample(size(V,1), 20);  % or manually choose ROI
sx = V(seedIdx, 1); sy = V(seedIdx, 2); sz = V(seedIdx, 3);



figure;
streamline(xq, yq, zq, U, Vv, W, sx, sy, sz);
hold on;
scatter3(V(:,1), V(:,2), V(:,3), 20, 'k', 'filled');
title(sprintf('Surface-Constrained Streamlines at t = %d', t_view));
xlabel('X'); ylabel('Y'); zlabel('Z'); axis equal;


phase_t = phi(:, t_view);
wavefront_idx = abs(phase_t) < pi/16;  % Near-zero phase
scatter3(V(wavefront_idx,1), V(wavefront_idx,2), V(wavefront_idx,3), ...
         80, 'r', 'filled');  % Overlay in red
legend('Streamlines', 'Sensors', 'Wavefront (\phi ≈ 0)');
