
N = length(chans);
sensor_positions = zeros(3, N);

for i = 1:N
    kk=chans(i);
    sensor_positions(:, i) = mean(data.chanfile.Channel(kk).Loc, 2);
end

D = squareform(pdist(sensor_positions'));  % NxN distance matrix
k = 6;
A = zeros(N);
for i = 1:N
    [~, idx] = sort(D(i,:));
    A(i, idx(2:k+1)) = 1;  % skip self
end
A = max(A, A');  % make symmetric
sigma = 0.03;
W = exp(-D.^2 / (2*sigma^2));
W(1:size(W,1)+1:end) = 0;  % set diagonal to 0
G = gsp_graph(W, sensor_positions');

gsp_plot_graph(G);  % optional
%% 

Wnorm = W / max(W(:));  % Now all weights ∈ [0, 1]
figure;
imagesc(D_lh);        % W is your weighted adjacency matrix
colormap('hot');   % or 'jet', 'parula', etc.
colorbar;
title('Weighted Sensor Connectivity Matrix');
xlabel('Sensor Index');
ylabel('Sensor Index');
axis square;

%% Compute Geodesic Distance Matrix
data=getData();
V=data.anat.Vertices;
F=data.anat.Faces;
VertConn=data.anat.VertConn;
% 
% Dg = zeros(N, N);  % geodesic distance matrix
% 
% for i = 1:N
%     Dg(:, i) = perform_fast_marching_mesh(V', F', i);
% end

% ==== Djiskstra =====
% Build edge weights from Euclidean distances between neighbors
% STEP 0: Ensure your variables are ready
% V         - Nx3 matrix of vertex coordinates
% VertConn  - NxN sparse binary adjacency matrix
% N         - Number of vertices

% Step 0: Inputs
% V         - N×3 matrix of vertex positions
% VertConn  - N×N sparse binary adjacency matrix
N = size(VertConn, 1);

% Step 1: Compute Euclidean distances for edges
[i, j] = find(VertConn);

if size(V, 2) ~= 3
    V = V';  % Make sure V is N×3
end

edge_lengths = sqrt(sum((V(i,:) - V(j,:)).^2, 2));

% Step 2: Build weighted graph
W = sparse(i, j, edge_lengths, N, N);  % W(i,j) = Euclidean edge length
Gmat = graph(W);  % MATLAB graph object with edge weights
bins = conncomp(Gmat);  % returns component label per vertex
lh_idx = find(bins == 1);
rh_idx = find(bins == 2);
G_lh = subgraph(Gmat, lh_idx);
G_rh = subgraph(Gmat, rh_idx);
D_lh = distances(G_lh);
D_rh = distances(G_rh);
V_lh=  V(lh_idx,:);
V_rh=  V(rh_idx,:);

% Step 3: Compute full geodesic distance matrix
%Dg_all = distances(Gmat);  % NxN matrix: Dg_all(i,j) = geodesic distance from i to j

% STEP 4: Convert to geodesic-aware weights using Gaussian kernel
sigma = 3;  % mm — adjust based on scale of your mesh
W_geo = exp(-D_lh.^2 / (2 * sigma^2));  % soft weights based on surface proximity
W_geo(D_lh == 0) = 0;  % remove self-weight (optional)

G = gsp_graph(W_geo, V_lh);  % V_lh is N×3 vertex coordinates for left hemisphere
gsp_plot_graph(G);  % optional


%% 
labels = {atlasDk.Scouts.Label};

lh_region_idx = find(endsWith(labels, 'L'));  % only right hemisphere
sorted_vertex_list = [];       % reordered vertex indices
region_boundaries = zeros(1, length(lh_region_idx)+1);  % for later plotting
region_names = cell(1, length(lh_region_idx));

for k = 1:length(lh_region_idx)
    v_idx = atlasDk.Scouts(lh_region_idx(k)).Vertices;
    region_names{k} = atlasDk.Scouts(lh_region_idx(k)).Label;
    region_boundaries(k+1) = region_boundaries(k) + length(v_idx);
    sorted_vertex_list = [sorted_vertex_list; v_idx(:)];
end

Dlh_sorted = D_rh(sorted_vertex_list, sorted_vertex_list);
plotGeodesicDistanceMatrix(Dlh_sorted, region_names, region_boundaries, 'Left Hemisphere');

