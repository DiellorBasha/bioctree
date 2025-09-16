% A. Temporal Frequency Spectrum
% Use the FFT on one or multiple sensors to extract the frequency:
Fs = 1 / (t(2) - t(1));  % Sampling rate
sensorIdx = 50;
signal = squeeze(Z(yIdx, sensorIdx, :));
Y = abs(fft(signal));
f_axis = Fs*(0:(length(Y)/2))/length(Y);
figure(1)
plot(f_axis, Y(1:end/2+1));
title('Frequency Spectrum');
xlabel('Hz'); ylabel('Amplitude');

% B. Spatial Wavenumber Spectrum
% Choose a fixed time slice (e.g., ti=150), then do FFT across x:
ti = 250;
wave_x = squeeze(Z(yIdx,:,ti));
Yx = abs(fftshift(fft(wave_x)));
k = linspace(-pi, pi, length(wave_x));
plot(k, Yx);
title('Spatial Wavenumber Spectrum');
xlabel('Wavenumber (rad/m)');

% 3. Wave Speed Estimation
% A. Cross-Correlation Based
% Time delay between sensors can estimate speed:
% Cross-correlate sensor i and i+1
i = 40;
x1 = x(i); x2 = x(i+1);
sig1 = squeeze(Z(yIdx, i, :));
sig2 = squeeze(Z(yIdx, i+1, :));
[crossCorr, lags] = xcorr(sig2, sig1, 'coeff');
[~, maxIdx] = max(crossCorr);
lagSamples = lags(maxIdx);
lagTime = lagSamples / Fs;

dx = x2 - x1;
estimated_speed = dx / lagTime;

% 
% 4. Phase Gradient and Phase Velocity
% You can extract instantaneous phase and compute the phase gradient:

% Assumes Z(yIdx, :, :) is [1 x Nx x T] and x is [1 x Nx], t is [1 x T]
signalLine = squeeze(Z(yIdx, :, :));  % Result is [Nx x T]

% Compute instantaneous phase
analytic_signal = hilbert(signalLine.').';  % Transpose to [T x Nx], then back
phases = angle(analytic_signal);            % Now [Nx x T]

% Define time and space
dx = mean(diff(x));   % Assume uniform spacing
dt = mean(diff(t));   % Assume uniform sampling rate

% Compute gradients
dphi_dx = diff(phases, 1, 1) / dx;   % ∂ϕ/∂x → [Nx-1 x T]
dphi_dt = diff(phases, 1, 2) / dt;   % ∂ϕ/∂t → [Nx x T-1]

% Trim to common size
dphi_dx = dphi_dx(:, 1:end-1);       % [Nx-1 x T-1]
dphi_dt = dphi_dt(1:end-1, :);       % [Nx-1 x T-1]

% Compute phase velocity
v_phase = -dphi_dx ./ dphi_dt;       % [Nx-1 x T-1];

%  3. Phase Velocity 
% 
% What it is: Speed at which a point of constant phase (like a wave crest) travels.
% 
% What it tells you:
% 
% Describes how fast and in which direction a wave propagates.
% 
% Can vary over space and time in nonlinear or dispersive media (like the brain).

% Assume you have: phases (100 x 300), x (1 x 100), t (1 x 300)
% Create a meshgrid
[T,X] = meshgrid(t ,x);

% Transpose phase to match the meshgrid: now it's [T x X]
phasesT = phases';

% Plot contour
figure;
contourf(X, T, phases, 20); colorbar;
hold on;

% Overlay the contour where phase = 0
contour(X, T, phases, [0 0], 'k', 'LineWidth', 2);  % phase = 0 line
xlabel('Position (x)');
ylabel('Time (s)');
title('Wave Phase and Zero Phase Contour');


%% 2 dimensional array

% --- Parameters
yIdxStart = 50;
yIdxEnd = 60;
t_index = 150;  % Time slice to analyze

% --- Coordinates
x = linspace(-10, 10, size(Z,2));  % Nx
y = linspace(-10, 10, size(Z,1));  % Ny
xSlice = x;                        % All x
ySlice = y(yIdxStart:yIdxEnd);     % Selected y

% --- Slice data
Zslice = Z(yIdxStart:yIdxEnd, :, :);  % [Δy x Nx x T]
[Ny, Nx, T] = size(Zslice);

% --- Compute phase
phaseSlice = zeros(Ny, Nx, T);
for yi = 1:Ny
    for xi = 1:Nx
        analytic_signal = hilbert(squeeze(Zslice(yi, xi, :)));
        phaseSlice(yi, xi, :) = angle(analytic_signal);
    end
end

% --- Phase gradients at time t_index
phi = phaseSlice(:,:,t_index);
[dphix, dphiy] = gradient(phi, x(2)-x(1), y(2)-y(1));  % Spatial resolution included

% --- Gradient magnitude and angle
gradMag = sqrt(dphix.^2 + dphiy.^2);
gradAngle = atan2(dphiy, dphix);  % radians

% --- Curl and Divergence
[curlVal, divVal] = curl(xSlice, ySlice, dphix, dphiy);  % requires x, y grid

% --- Meshgrid for plotting
[xFull, yFull] = meshgrid(xSlice, ySlice);

%% === Visualizations ===

% 1. Quiver plot
figure;
quiver(xFull, yFull, dphix, dphiy);
axis equal tight;
title('Phase Gradient Field'); xlabel('x'); ylabel('y');

% 2. Streamlines
figure;
streamslice(xFull, yFull, dphix, dphiy);
axis equal tight;
title('Streamlines of Phase Gradient');

% 3. Magnitude of Phase Gradient
figure;
imagesc(xSlice, ySlice, gradMag);
axis xy; colorbar;
title('Magnitude of Phase Gradient'); xlabel('x'); ylabel('y');

% 4. Curl
figure;
imagesc(xSlice, ySlice, curlVal);
axis xy; colorbar;
title('Curl of Phase Gradient'); xlabel('x'); ylabel('y');

% 5. Divergence
figure;
imagesc(xSlice, ySlice, divVal);
axis xy; colorbar;
title('Divergence of Phase Gradient'); xlabel('x'); ylabel('y');

%%
% Create seed points along a horizontal line in the middle
startx = linspace(min(xFull(:)), max(xFull(:)), 20);
starty = mean(yFull(:)) * ones(size(startx));

figure;
streamline(xFull, yFull, dphix, dphiy, startx, starty);
axis equal tight;
title('Streamline: Wavefront Propagation');
%% % Extend to 3D by adding zero Z-components
% Add a Z layer (optional; cones point in 3D space)
Z = zeros(size(xFull));
U = dphix; V = dphiy; W = zeros(size(U));  % 2D field in XY plane

figure;
coneplot(xFull, yFull, Z, U, V, W, xFull, yFull, Z);
view(30, 45);
title('Coneplot: Phase Direction (2D)');
%% =========== Curved surface 
%Parameters
Nx = 100; Ny = 100; T = 300;
f = 5; lambda = 2; alpha = 0.1;
origin = [0, 0];
curvatureStrength = 0.08;
% Generate mesh grid
x = linspace(-10, 10, Nx);
y = linspace(-10, 10, Ny);
[x2, y2] = meshgrid(x, y);
z2 = curvatureStrength * (x2.^2 + y2.^2);  % Paraboloid
[Z, x2, y2, t] = generateRippleSurface(Nx, Ny, T, f, lambda, alpha, origin,  'Curved', true, 'CurvatureType', 'paraboloid', 'CurvatureStrength', 0.08);

% Compute phase at each (x, y)
phase = zeros(Ny, Nx);
for yi = 1:Ny
    for xi = 1:Nx
        analytic_signal = hilbert(squeeze(Z(yi, xi, :)));
        phase(yi, xi) = angle(analytic_signal(t_index));
    end
end

% Compute spatial gradients in X and Y
[dphi_dx, dphi_dy] = gradient(phase, x(2)-x(1), y(2)-y(1));  % spatial gradients
magnitude = sqrt(dphi_dx.^2 + dphi_dy.^2);

%% Normalize vectors for quiver plot
dphi_dx_unit = dphi_dx ./ magnitude;
dphi_dy_unit = dphi_dy ./ magnitude;

%% Embed everything in 3D
z_surface = curvatureStrength * (x2.^2 + y2.^2);
dz_dx = 2 * curvatureStrength * x2;
dz_dy = 2 * curvatureStrength * y2;

%% Project gradient vectors onto 3D tangent plane
% Tangent vectors at each point
Tx = [ones(size(x2)), zeros(size(y2)), dz_dx];
Ty = [zeros(size(x2)), ones(size(y2)), dz_dy];

% Construct wave direction vector in XY
Vxy = cat(3, dphi_dx, dphi_dy);

% Project into 3D (naive projection)
Ux = dphi_dx;
Uy = dphi_dy;
Uz = dz_dx .* dphi_dx + dz_dy .* dphi_dy;

z_surface = -curvatureStrength * (x2.^2 + y2.^2);  % Same as inside the function


%% Visualization

t_index = 150;
Z_t = Z(:,:,t_index);  % [Ny x Nx]
figure;
surf(x2, y2, z_surface, Z_t, 'EdgeColor', 'none'); hold on;
colormap turbo; shading interp;
title('Wave Field and Phase Gradient Vectors on Paraboloid');
xlabel('X'); ylabel('Y'); zlabel('Z');
view(30, 30); axis equal; camlight; lighting gouraud;

% Subsample for clarity
step = 5;
quiver3(x2(1:step:end,1:step:end), ...
        y2(1:step:end,1:step:end), ...
        z_surface(1:step:end,1:step:end), ...
        Ux(1:step:end,1:step:end), ...
        Uy(1:step:end,1:step:end), ...
        Uz(1:step:end,1:step:end), ...
        0.5, 'k');
%% 
T = size(Z, 3);
phase = angle(hilbert(reshape(Z, [], T).').');  % [Ny*Nx x T]
phase = reshape(phase, size(Z));  % Back to [Ny x Nx x T]

t_index = 150;
[gradX, gradY] = gradient(phase(:,:,t_index), x2(1,:), y2(:,1));  % ∂ϕ/∂x, ∂ϕ/∂y
gradZ = zeros(size(gradX));  % Assume flat in z for now, or derive from surface normal

figure;
quiver3(x2, y2, z_surface, gradX, gradY, gradZ, 2);
xlabel('X'); ylabel('Y'); zlabel('Z');
title('3D Phase Gradient Vectors');
axis tight; view(30,40); camlight; lighting gouraud;

%% % Convert to grid
zSurface=z_surface;
[x3, y3, z3] = meshgrid(x2(1,:), y2(:,1), linspace(min(zSurface(:)), max(zSurface(:)), 10));
[u3, v3, w3] = deal(repmat(gradX, [1 1 10]), repmat(gradY, [1 1 10]), repmat(gradZ, [1 1 10]));

% Streamline starting points (sensor locations or grid subset)
startx = x3(:,:,1); starty = y3(:,:,1); startz = z3(:,:,1);

% Compute and plot streamlines
streams = stream3(x3, y3, z3, u3, v3, w3, startx, starty, startz);
streamtube(streams, u3, v3, w3);
xlabel('X'); ylabel('Y'); zlabel('Z');
title('Streamtube of Phase Gradient Field');
%% F===============

% Assume you have already loaded/got this from generateRippleSurface:
[Z, x2, y2, t] = generateRippleSurface(100, 100, 300, 5, 2, 0.1, [0, 0], ...
    'Curved', true, 'CurvatureType', 'paraboloid', 'CurvatureStrength', 0.08);
zSurf = 0.08 * (x2.^2 + y2.^2);  % Paraboloid elevation

% Time point of interest
t_index = 150;

% Compute phase
phase = angle(hilbert(reshape(Z, [], size(Z,3)).').');  % [Ny*Nx x T]
phase = reshape(phase, size(Z));  % [Ny x Nx x T]

% Phase gradient
[gradX, gradY] = gradient(phase(:,:,t_index), x2(1,:), y2(:,1));
gradZ = zeros(size(gradX));  % Assume flat in z-direction (you could compute normal component)

% Speed magnitude (norm of phase gradient)
spd = sqrt(gradX.^2 + gradY.^2 + gradZ.^2);

% Create volumetric grid for vector visualization
[x, y, z] = meshgrid(x2(1,:), y2(:,1), linspace(min(zSurf(:)), max(zSurf(:)), 10));
u = repmat(gradX, [1, 1, size(z,3)]);
v = repmat(gradY, [1, 1, size(z,3)]);
w = repmat(gradZ, [1, 1, size(z,3)]);
% Assume spd is [Ny x Nx] (e.g., 100 x 100)
Nz = 10;  % Number of z-slices to extrude through
spd3D = repmat(spd, [1 1 Nz]);

% Create matching 3D meshgrid
[x3, y3, z3] = meshgrid(x2(1,:), y2(:,1), linspace(0, 1, Nz));  % z from 0 to 1

%% 🎯 Isosurface of constant speed
figure(1)
cla
[fc, vc] = isosurface(x3, y3, z3, spd3D, 30);  % isovalue = 30, adjust as needed
[fc, vc] = reducepatch(fc, vc, 0.2);  % Simplify mesh

%% 🟦 Coneplot at isosurface vertices
h1 = coneplot(x, y, z, u, v, w, vc(:,1), vc(:,2), vc(:,3), 3);
h1.FaceColor = 'cyan';
h1.EdgeColor = 'none';

%% 🟢 Streamlines from fixed seed points
[sx, sy, sz] = meshgrid(0, -5:1:5, 0:2:10);  % Define seed points
h2 = streamline(x, y, z, u, v, w, sx, sy, sz);
set(h2, 'Color', [0.4 1 0.4]);

%% 🌐 Plot surface and enhance visuals

hold on;
surf(x2, y2, zSurf, Z(:,:,t_index), 'FaceAlpha', 0.6, 'EdgeColor', 'none');
colormap(turbo); colorbar;
title('Wave Propagation on Curved Surface with Phase Gradient Visualization');
xlabel('X'); ylabel('Y'); zlabel('Z');
axis tight equal;
view(37, 32); box on; grid on;
light; lighting gouraud;

