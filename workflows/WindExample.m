load wind
zmax = max(z(:)); zmin = min(z(:));
streamslice(x,y,z,u,v,w,[],[],(zmax-zmin)/2);


% Subsample for clarity
xs = x(1:4:end,1:4:end,1:2:end);
ys = y(1:4:end,1:4:end,1:2:end);
zs = z(1:4:end,1:4:end,1:2:end);
us = u(1:4:end,1:4:end,1:2:end);
vs = v(1:4:end,1:4:end,1:2:end);
ws = w(1:4:end,1:4:end,1:2:end);

quiver3(xs, ys, zs, us, vs, ws, 'k');
axis tight;
view(3);
title('3D Vector Field (Quiver3)');

%%
% Parameters
N = 50;                  % number of "channels"
T = 500;                 % number of time points
fs = 1000;               % Hz
t = (0:T-1)/fs;          % time vector
f = 10;                  % Hz (oscillation freq)
speed = 2;               % samples per channel delay

% Simulate traveling wave
data = zeros(N, T);
for n = 1:N
    phase_delay = 2 * pi * f * (n-1) / (fs * speed);
    data(n, :) = sin(2 * pi * f * t - phase_delay);
end

% Plot
figure;
imagesc(t, 1:N, data);
xlabel('Time (s)'); ylabel('Channel');
title('Raw Time Series (No Spatial Info)');
colorbar;
figure;
offset = 2;  % vertical offset between time series
hold on;
for n = 1:N
    plot(t, data(n, :));  % vertically offset
end
xlabel('Time (s)');
ylabel('Channel (offset)');
title('Time Series (No Spatial Coordinates)');


% Define x positions evenly spaced
x = linspace(0, 10, N);   % 10 cm long line

% Simulate wave with space-dependent phase
data1D = zeros(N, T);
wavelength = 2;          % in spatial units
k = 2*pi / wavelength;   % spatial frequency
for n = 1:N
    data1D(n, :) = sin(2 * pi * f * t - k * x(n));
end

% Visualize time series as before
figure;
imagesc(t, x, data1D);
xlabel('Time (s)'); ylabel('x-position');
title('1D Traveling Wave');
colorbar;

figure;
hold on;
for n = 1:N
    plot(t, data1D(n, :) + x(n), 'b');  % offset by x-position
end
xlabel('Time (s)');
ylabel('x-position + Amplitude');
title('1D Wave Propagation (Curves)');
%% 
figure;
hold on;

% Loop through each spatial location
for i = 1:length(x)
    % Create vectors for 3D plotting
    xi = x(i) * ones(size(t));      % constant x for this line
    yi = t;                         % time axis
    zi = dataPhase(i, :);              % amplitude over time

    % Plot the time series as a 3D line
    plot3(xi, yi, zi, 'b');  % blue lines
end

xlabel('x-position (cm)');
ylabel('Time (s)');
zlabel('Amplitude');
title('1D Traveling Wave - 3D View');
view(135, 30);  % nice 3D angle
grid on;
%% 
contour(dataPhase,pi)  % transpose Z
ylabel('x-position');
xlabel('Time (s)');

%%

dataHilb = hilbert(data1D')';   % Transpose to get T x N, then back to N x T
dataPhase = angle(dataHilb);   % N x T matrix of phase
    dx = x(2) - x(1);
    dt = t(2) - t(1);

% Preallocate
px = zeros(N, T-1);    % ∂ϕ/∂x
pt = zeros(N-1, T);    % ∂ϕ/∂t

% ∂ϕ/∂x: compute across space (for each time point)
for ti = 1:T
    px(:, ti) = gradient(dataPhase(:, ti), dx);
end

% ∂ϕ/∂t: compute across time (for each spatial point)
for xi = 1:N
    pt(xi, :) = gradient(dataPhase(xi, :), dt);
end


% Must match dimensions
px = px(1:N-1, 1:T-1);
pt = pt(1:N-1, 1:T-1);

v_phi = -px ./ pt;   % size (N-1, T-1)

contour(v_phi,3,'ShowText','on')
imagesc(t(1:end-1), x(1:end-1), v_phi);
xlabel('Time (s)');
ylabel('Position x (cm)');
colorbar;
title('Phase Velocity over Space and Time');
meanSpeed = mean(v_phi(:), 'omitnan');  % Should be ≈ 20



%% 
% Parameters
Nx = 20; Ny = 20; T = 500;
fs = 1000; t = (0:T-1)/fs;
f = 10; lambda = 2;
[x2, y2] = meshgrid(linspace(0,10,Nx), linspace(0,10,Ny));

% 3D array to store amplitude at each (x, y, t)
data3D = zeros(Nx, Ny, T);
dataHilb = zeros(Nx, Ny, T);
dataPhase = zeros(Nx, Ny, T);

% Propagation vector
kvec = [1; 1] / sqrt(2);
k = 2 * pi / lambda;

% Fill 3D volume
for xi = 1:Nx
    for yi = 1:Ny
        pos = [x2(xi, yi); y2(xi, yi)];
        phase = k * dot(kvec, pos);
        signal= sin(2*pi*f*t - phase);
        sigHilb=hilbert(signal);
        sigPhase=angle(sigHilb);
        dataHilb(xi, yi, :)=sigHilb;
        dataPhase(xi, yi, :)=sigPhase;
        data3D(xi, yi, :) = sin(2*pi*f*t - phase);
    end
end

%% 
% Compute spatial gradients
% Assume: x2, y2 from meshgrid; dataPhase is Ny x Nx x Nt

% Define time vector
Nt = size(dataPhase, 3);
t = (0:Nt-1)/1000;  % example: 1000 Hz sampling rate

% Grid spacing
dx = x2(1,2) - x2(1,1);
dy = y2(2,1) - y2(1,1);

% Initialize velocity fields
[Nx, Ny, Nt] = size(dataPhase);
vx = zeros(Nx, Ny, Nt);
vy = zeros(Nx, Ny, Nt);
vt = ones(Nx, Ny, Nt);  % placeholder

for ti = 1:Nt-1
    [px, py] = gradient(dataPhase(:,:,ti), dx, dy);
    pt = dataPhase(:,:,ti+1) - dataPhase(:,:,ti);
    vx(:,:,ti) = -px ./ pt;
    vy(:,:,ti) = -py ./ pt;
end

% Copy last frame to fill array
vx(:,:,Nt) = vx(:,:,Nt-1);
vy(:,:,Nt) = vy(:,:,Nt-1);

% Build meshgrid as MATLAB expects
[xg, yg, zg] = meshgrid(x2(1,:), y2(:,1), t);  % Ny × Nx × Nt

% Construct MEG-compatible structure
meg = struct();
meg.u = permute(vx, [2 1 3]);  % permute to Ny × Nx × Nt
meg.v = permute(vy, [2 1 3]);
meg.w = zeros(size(meg.u));   % optional vt if meaningful
meg.x = xg;
meg.y = yg;
meg.z = zg;

%%
spd = abs(data3D);   % instantaneous wave amplitude
[fo, vo] = isosurface(x2, y2, t, spd, threshold);
p1 = patch('Faces', fo, 'Vertices', vo, 'FaceColor', 'red', 'EdgeColor', 'none');

for k=1:size(data3D,1)
dataHilb = hilbert(data3D(,  3);        % complex signal over time
phase = angle(dataHilb);                  % phase(x, y, t)
end
%%

spd = sqrt(windd.u.*windd.u + windd.v.*windd.v + windd.w.*windd.w);                          
[fo,vo] = isosurface(windd.x,windd.y,windd.z,spd,40);                      
[fe,ve,ce] = isocaps(windd.x,windd.y,windd.z,spd,40);   
p1 = patch('Faces', fo, 'Vertices', vo);                 
p1.FaceColor = 'red'
p1.EdgeColor = 'none'
p2 = patch('Faces', fe, 'Vertices', ve, ...              
   'FaceVertexCData', ce)
p2.FaceColor = 'interp'
p2.EdgeColor = 'none' 
[fc, vc] = isosurface(windd.x,windd.y,windd.z, spd, 30);                 
[fc, vc] = reducepatch(fc, vc, 0.2);       

%%
h1 = coneplot(windd.x,windd.y,windd.z,windd.u,windd.v,windd.w,vc(:,1),vc(:,2),vc(:,3),3);    
h1.FaceColor = 'cyan';
h1.EdgeColor = 'none';

[sx, sy, sz] = meshgrid(80, 20:10:50, 0:5:15);           
h2 = streamline(windd.x,windd.y,windd.z,windd.u,windd.v,windd.w,sx,sy,sz);                   
set(h2, 'Color', [.4 1 .4])

axis tight equal
view(37,32)
box on
light

%%
%% Compute speed (magnitude of phase velocity vector)
spd = sqrt(meg.u.^2 + meg.v.^2 + meg.w.^2);
% Visualize isosurface at threshold = 2 (change as needed)
threshold = 2;

[fo, vo] = isosurface(meg.x, meg.y, meg.z, spd, threshold);
[fe, ve, ce] = isocaps(meg.x, meg.y, meg.z, spd, threshold);
%% Plot isosurface
figure;
p1 = patch('Faces', fo, 'Vertices', vo);
p1.FaceColor = 'red';
p1.EdgeColor = 'none';
%% Plot isocaps
p2 = patch('Faces', fe, 'Vertices', ve, ...
           'FaceVertexCData', ce);
p2.FaceColor = 'interp';
p2.EdgeColor = 'none';
%% Reduce complexity of geometry for coneplot
[fc, vc] = isosurface(meg.x, meg.y, meg.z, spd, threshold - 1);
[fc, vc] = reducepatch(fc, vc, 0.2);  % keep 20% of original complexity
%% Add coneplot showing phase velocity vectors
h1 = coneplot(meg.x, meg.y, meg.z, ...
              meg.u, meg.v, meg.w, ...
              vc(:,1), vc(:,2), vc(:,3), ...
              3);  % scale factor
h1.FaceColor = 'cyan';
h1.EdgeColor = 'none';


%% Add streamlines (OPTIONAL: resample seed points within valid domain)
% You may need to adjust meshgrid range to match your meg.x, meg.y, meg.z
xRange = linspace(min(meg.x(:)), max(meg.x(:)), 5);
yRange = linspace(min(meg.y(:)), max(meg.y(:)), 5);
zRange = linspace(min(meg.z(:)), max(meg.z(:)), 5);
[sx, sy, sz] = meshgrid(xRange, yRange, zRange);

h2 = streamline(meg.x, meg.y, meg.z, ...
                meg.u, meg.v, meg.w, ...
                sx, sy, sz);
set(h2, 'Color', [.4 1 .4]);

%% Final plot formatting
axis tight;
axis equal;
view(37, 32);
box on;
camlight; lighting gouraud;
title('MEG-Derived Spatiotemporal Phase Velocity Field');

%% Simulate Ripple Across 1D Sensor Line


% Parameters
N = 100;                  % number of sensors along line
T = 1000;                 % time points
fs = 1000;                % Hz
t = (0:T-1)/fs;           % time vector
x = linspace(-10, 10, N); % sensor positions along x

% Wave parameters
f = 5;                    % Hz
lambda = 2;               % wavelength in spatial units
k = 2 * pi / lambda;
x0 = 0;                   % ripple center x
y0 = 5;                   % ripple center y (above line)
r = sqrt((x - x0).^2 + y0^2);  % distance from ripple center to each sensor

% Preallocate time series
dataRipple = zeros(N, T);
for i = 1:N
    delay = k * r(i);  % phase delay due to distance
    dataRipple(i, :) = sin(2 * pi * f * t - delay);  % signal at sensor i
end

% Plot
figure;
imagesc(t, x, dataRipple);
xlabel('Time (s)');
ylabel('Sensor position (x)');
title('Ripple Recorded on 1D Sensor Line');
colorbar;

[x2, y2] = meshgrid(linspace(-10,10,100), linspace(-10,10,100));
r2 = sqrt((x2 - x0).^2 + (y2 - y0).^2);
data2D = sin(2*pi*f*t' - k*r2(:)); % reshape for each time


%% Generate Ripple on a Surface Mesh
% Grid and time
Nx = 100; Ny = 100; T = 300;
x = linspace(-10, 10, Nx);
y = linspace(-10, 10, Ny);
t = linspace(0, 1, T);  % 1 second

[x2, y2] = meshgrid(x, y);  % meshgrid gives [Ny x Nx]

% Wave parameters
f = 5;                     % Hz
lambda = 2;                % spatial wavelength
k = 2 * pi / lambda;
A = 1;
alpha = 0.1;               % spatial decay
x0 = 0; y0 = 0;            % ripple origin

% Distance grid
r = sqrt((x2 - x0).^2 + (y2 - y0).^2);  % [Ny x Nx]

% Allocate 3D volume: c(x, y, t)
c = zeros(Ny, Nx, T);
for ti = 1:T
    c(:,:,ti) = A * sin(2*pi*f*t(ti) - k*r) .* exp(-alpha * r);
end

Z=c;


%% 

v = VideoWriter('ripple_animation.mp4', 'MPEG-4');
v.FrameRate = 24;  % Adjust frame rate as needed
open(v);


figure;
h = surf(x2, y2, Z(:,:,1), 'EdgeColor', 'none');
zlim([-1 1]);
axis equal tight;
xlabel('x'); ylabel('y'); zlabel('Amplitude');
view(30, 45);
camlight; lighting gouraud;
for ti = 1:size(Z,3)
    h.ZData = Z(:,:,ti);                          % Update surface heights
    title('Wave Propagation on Flat Surface');
    subtitle(sprintf('t = %.2f s', t(ti)))
    drawnow;
   

    % Capture the frame and write to video
    frame = getframe(gcf);
    writeVideo(v, frame);
end


close(v);
disp('Video saved as ripple_animation.mp4');
%% 
Ny = size(Z, 1);
Nx = size(Z, 2);
T  = size(Z, 3);

numSensors = 10;

% Index of center row (horizontal line across the surface)
yIdx = round(Ny / 2);

% Sample 10 evenly spaced x positions (columns)
xIndices = round(linspace(1, Nx, numSensors));

% Preallocate matrix to hold 10 time series
sensorData = zeros(numSensors, T);

% Extract time series from Z(y, x, t)
for i = 1:numSensors
    xi = xIndices(i);
    sensorData(i, :) = squeeze(Z(yIdx, xi, :));
end


sensorLine=squeeze(Z(yIdx, :, :));
figure(2)
subplot(211)
imagesc(sensorLine)
subplot(212)
for k = 1:size(sensorLine,1)
hold on 
plot (tsteps, sensorLine(k,:)+k, 'k')
end
% Get the actual x positions of sensors (for vertical stacking)
xSensorPos = x(xIndices);  % 1 x numSensors
tsteps=1:T;

%% 

figure(2)

axis([tsteps(1), tsteps(end), min(xSensorPos)-0.5, max(xSensorPos)+0.5]);
xlabel('Time (s)');
ylabel('x-position on surface');
title('Animated Sensor Recordings');
% Create a line object for each sensor
hLines = gobjects(numSensors, 1);

for i = 1:numSensors
    % Plot sensor i's time series, offset vertically by its x-position
    hLines(i) = plot(tsteps, sensorData(i, :) + xSensorPos(i), 'k');
end



for i = 1:numSensors
    hLines(i) = animatedline('Color', 'k');
end
for ti = 1:T
    for i = 1:numSensors
        addpoints(hLines(i), tsteps(ti), sensorData(i, ti) + xSensorPos(i));  % offset using true position
    end
    drawnow;
end