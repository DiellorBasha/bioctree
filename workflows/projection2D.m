%% Projecting from 3D sensors to a 2D cap

% Input parameters
fs = 2400;            % Original sampling rate (Hz)
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
%% 

goodChans = chanfile.Channel(2).Loc;

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


[X2D, Y2D] = bst_project_2d(pos3D(:,1), pos3D(:,2), pos3D(:,3), '2dcap');
sLoc2D = [X2D; Y2D];  % A [2 x N] matrix for plotting or interpolation
% Visualize
figure;
scatter(X2D, Y2D, 50, 'filled');
axis equal; title('2D Cap Projection of Sensors');

%%

Vertices = pos3D(chans,:);
Faces = channel_tesselate(Vertices, 0);
% Step 1: Extract edges from triangles
edges = [Faces(:, [1 2]);
         Faces(:, [2 3]);
         Faces(:, [3 1])];

% Step 2: Make sure edges are unique and undirected
edges = sort(edges, 2);  % sort each row
edges = unique(edges, 'rows');

% Step 3: Create sparse adjacency matrix
N = size(Vertices, 1);
i = edges(:,1);
j = edges(:,2);
A = sparse([i; j], [j; i], 1, N, N);  % symmetric adjacency

% Visualize mesh
patch('Vertices', Vertices, 'Faces', Faces, ...
      'EdgeColor', 'k', 'FaceColor', 'c');
axis equal; rotate3d on;


G = graph(A);                 % Create undirected graph from adjacency matrix
D = distances(G);             % Compute all-pairs shortest paths


% 3. Apply MDS to reduce to 2D
[Y, ~] = cmdscale(D);

% Y is [N x 2]  => your 2D projection
scatter(Y(:,1), Y(:,2)); axis equal; title('Geodesic Flattening');

%% To ensure true geodesic flattening

% Compute edge list
edges = [Faces(:,[1 2]); Faces(:,[2 3]); Faces(:,[3 1])];
edges = sort(edges, 2);
edges = unique(edges, 'rows');
i = edges(:,1); j = edges(:,2);

% Compute Euclidean distances between connected vertices
weights = vecnorm(Vertices(i,:) - Vertices(j,:), 2, 2);  % true edge lengths

% Build graph
G = graph(i, j, weights, size(Vertices, 1));

% Compute geodesic distances
D = distances(G);  % D(i,j) approximates geodesic distance on the mesh

% Apply MDS
[Y, ~] = cmdscale(D);
scatter(Y(:,1), Y(:,2)); axis equal; title('Geodesic Flattening');

%%

% 2D geodesic-preserving coordinates
Xpos = Y(:,1);
Ypos = Y(:,2);

% Create a regular grid
xq = linspace(min(Xpos), max(Xpos), 64);
yq = linspace(min(Ypos), max(Ypos), 64);
[Xgrid, Ygrid] = meshgrid(xq, yq);

nTime = size(F, 2);
Vol = zeros(length(yq), length(xq), nTime);  % [Y x X x Time]

for t = 1:nTime
    Vol(:,:,t) = griddata(Xpos, Ypos, F(:,t), Xgrid, Ygrid, 'cubic');
end


[X, Y, Z] = meshgrid(xq, yq, 1:nTime);  % Z = time
%% 

% Plot several time slices
slice_idx = round(linspace(1, nTime, 10));  % choose slices
figure;
hs = slice(X, Y, Z, Vol, [], [], slice_idx);  % slices along Z axis (time)
shading interp; colormap(jet); colorbar;
xlabel('Geodesic X'); ylabel('Geodesic Y'); zlabel('Time');
title('Spatiotemporal Activity (Geodesic Flattening)');
alpha color
alpha scaled


%%

contourslice(X, Y, Z, Vol,[],[],slice_idx)


%% 

line_y = round(size(Vol,1)/2);  % Middle row
hov_data = squeeze(Vol(line_y, :, :));  % [X x T]


figure;
imagesc(1:size(hov_data,1), 1:size(hov_data,2), hov_data');  % time = Y axis
xlabel('X grid position');
ylabel('Time');
title('Hovmöller Diagram (horizontal cross-section)');
colormap(jet); colorbar;

%% 

% Sample a diagonal path
n = min(size(Vol,1), size(Vol,2));
hov_diag = zeros(n, size(Vol,3));
for t = 1:size(Vol,3)
    sliced = Vol(:,:,t);
    hov_diag(:,t) = diag(sliced);
end

imagesc(hov_diag'); xlabel('Diagonal space'); ylabel('Time'); title('Diagonal Hovmöller');

%% Use this section as continuation after you've created hov_data

% hov_data: [X x T] extracted from Vol
% Transpose for plotting: time = Y-axis, space = X-axis
H = hov_data';  % [Time x Space]

% Define x and t axes for labeling
Tvec = linspace(0, nTime-1, size(H,1));      % Time vector (adjust units)
Xvec = linspace(min(xq), max(xq), size(H,2));  % Geodesic X positions

% Compute zonal (space-avg) and temporal (time-avg) means
zonal_avg = mean(H, 2);   % [Time x 1]
temp_avg  = mean(H, 1);   % [1 x Space]


figure
% Base Hovmöller heatmap
imagesc(Xvec, Tvec, H);  % Time = vertical axis
colormap(jet); colorbar;
xlabel('X grid position');
ylabel('Time');
title('Hovmöller with 3 Contour Levels');
set(gca, 'YDir', 'normal');  % Time increasing downward

hold on;

% Overlay contour lines with 3 levels
nLevels = 3;
minH = min(H(:));
maxH = max(H(:));
levels = linspace(minH, maxH, nLevels + 2);  % +2 to skip extreme ends
levels = levels(2:end-1);  % Use middle 3 levels

[~, hContour] = contour(Xvec, Tvec, H, levels, 'LineColor', 'k', 'LineWidth', 1);
clabel(_, hContour, 'FontSize', 8);

% --- (b) Zonal Average (right side) ---
subplot(3,2,2);
plot(zonal_avg, Tvec, 'k', 'LineWidth', 1.5);
set(gca, 'YDir', 'normal');
xlabel('Avg. Power');
ylabel('Time');
title('Zonal Average');

% --- (c) Temporal Average (bottom) ---
subplot(3,2,[5 6]);
plot(Xvec, temp_avg, 'k', 'LineWidth', 1.5);
xlabel('Geodesic Distance');
ylabel('Avg. Power');
title('Temporal Average');

sgtitle('Enhanced Hovmöller Diagram');
%% 
ChannelNames={};
for k = 1:length(chans)
ChannelNames{k}=chanfile.Channel(k).Name;
end
% The y-location of your slice
y_val = yq(line_y);  % Get Y position of the slice

tolerance = (max(yq) - min(yq)) / 64;  % 1 grid cell tall
near_slice = abs(Ypos - y_val) < tolerance;

chan_labels = {}; tick_pos = [];
for i = find(near_slice)'
    [~, xi] = min(abs(xq - Xpos(i)));  % Closest X grid position
    chan_labels{end+1} = ChannelNames{i};  % Your list of channel names
    tick_pos(end+1) = xi;
end

%% 

line_y = round(size(Vol,1)/2);  % Middle row

line_y = 55
hov_data = squeeze(Vol(line_y, :, :));  % [X x T]

H = hov_data';  % Time = Y, X = horizontal
figure(2);
imagesc(1:size(H,2), 1:size(H,1), H);
xlabel('Geodesic X (near slice)');
ylabel('Time'); title('Hovmöller with Channel Labels');
set(gca, 'YDir', 'normal');

tick_sort=unique(sort(tick_pos));
% Add channel labels as ticks
xticks(tick_sort);
xticklabels(chan_labels);
xtickangle(45);  % Optional tilt
set(gca, 'YDir', 'reverse')

%%


Vol = zeros(length(yq), length(xq), nTime);  % [Y x X x Time]
VolMask = zeros(length(yq), length(xq), nTime);  % [Y x X x Time]
VolAmp = zeros(length(yq), length(xq), nTime);  % [Y x X x Time]
VolPhaseU = zeros(length(yq), length(xq), nTime);  % [Y x X x Time]

for t = 1:nTime
   Vol(:,:,t) = griddata(Xpos, Ypos, F_alpha(:,t), Xgrid, Ygrid, 'cubic');
    VolMask(:,:,t) = griddata(Xpos, Ypos, F_alpha_mask(:,t), Xgrid, Ygrid, 'cubic');
     VolAmp(:,:,t) = griddata(Xpos, Ypos, F_alpha_amp(:,t), Xgrid, Ygrid, 'cubic');
      VolPhaseU(:,:,t) = griddata(Xpos, Ypos, F_alpha_unwrapped(:,t), Xgrid, Ygrid, 'cubic');
       VolPhase(:,:,t) = griddata(Xpos, Ypos, F_alpha_phase(:,t), Xgrid, Ygrid, 'cubic');
end


[X, Y, Z] = meshgrid(xq, yq, 1:nTime);  % Z = time

%%

line_y = round(size(VolPhase,1)/2);  % Middle row

line_y = 55
hov_data = squeeze(VolPhase(line_y, :, :));  % [X x T]

H = hov_data';  % Time = Y, X = horizontal
figure;
imagesc(1:size(H,2), 1:size(H,1), H);
xlabel('Geodesic X (near slice)');
ylabel('Time'); title('Hovmöller with Channel Labels');
set(gca, 'YDir', 'normal');

tick_sort=unique(sort(tick_pos));
% Add channel labels as ticks
xticks(tick_sort);
xticklabels(chan_labels);
xtickangle(45);  % Optional tilt
set(gca, 'YDir', 'reverse');

%% Spatial Phase Gradient
wavefronts = false(nY, nX, nTime);  % binary mask
[nY, nX, nTime] = size(VolPhase);
phase_grad_x = zeros(nY, nX, nTime);
phase_grad_y = zeros(nY, nX, nTime);

dx = mean(diff(xq));
dy = mean(diff(yq));

for t = 1:nTime
    % Get phase map
    phi_t = VolPhaseU(:,:,t);

    % Compute gradient
    [dphi_dy, dphi_dx] = gradient(phi_t, dy, dx);
    grad_mag = sqrt(dphi_dx.^2 + dphi_dy.^2);

    VolPhaseGrad(:,:,t) = grad_mag;
    % Threshold: mark points with nearly zero gradient
    threshold = 0.05 * max(grad_mag(:));  % or use fixed value like 0.1
    wavefronts(:,:,t) = grad_mag < threshold;
end

figure(1)
isosurface(X,Y,Z,VolPhaseGrad,1.0590)
%% 

line_y = round(size(Vol,1)/2);  % Middle row
line_y=7
hov_data = squeeze(Vol(:,line_y, :));  % [X x T]
hov_data = squeeze(Vol(line_y, :, :));  % [X x T]

H = hov_data';  % [time x space]

% Extract wavefront mask slice
hov_mask = squeeze(wavefronts(:,line_y, :))';  % [time x space]
hov_mask = squeeze(wavefronts(line_y,:, :))';  % [time x space]

figure(2);
subplot(121)
imagesc(1:size(H,2), 1:size(H,1), H);  % X = space, Y = time
set(gca, 'YDir', 'normal');  % time increases downward (standard Hovmöller)
colormap(jet); colorbar;
xlabel('Geodesic X (near slice)');
ylabel('Time');
title('Hovmöller with Wavefront Contours');
% Set channel labels if applicable
tick_sort = unique(sort(tick_pos));
xticks(tick_sort);
xticklabels(chan_labels);
xtickangle(45);

subplot (122)
% Overlay wavefront contours
contour(1:size(H,2), 1:size(H,1), hov_mask, [1 1], ...
        'k', 'LineWidth', 1.5);  % contour where mask = 1
colorbar

%%


scatter3(anat.Vertices(:,1),anat.Vertices(:,2),anat.Vertices(:,3), 2, cdataSource)

colorbar


