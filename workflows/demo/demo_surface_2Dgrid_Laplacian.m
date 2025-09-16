% demo_gridLB_vs_graphLaplacian.m
% Demonstrate that the 2D grid graph Laplacian is the 5-pt FD Laplacian (i.e., a LB discretization on a flat surface).

clear; clc; close all;

% --- 0) GSPBox grid graph ---
Nx = 64; Ny = 64;  % square grid
addpath(genpath('gspbox'))  % <-- ensure GSPBox is on path
gsp_start;

G = gsp_2dgrid(Nx, Ny);
G = gsp_create_laplacian(G);  % ensures G.L is present
%% 
GMatlab = graph(G.A);
plot(GMatlab)
%% 

% Optional: visualize the graph
figure('Name','2D Grid Graph'); 
param.show_edges = 1;
param.vertex_size=5;
gsp_plot_graph(G, param); title('GSPBox 2D Grid (edges shown)');
%% 

% --- 1) Build a surface mesh from the grid graph (for trisurf visualization) ---
[TR, V, F, Nx_chk, Ny_chk, vert2grid_lin, grid2vert, xvals, yvals] = surfaceMeshFromGridGraph(G); %#ok<ASGLU>

% --- 2) Generate a ripple on a flat surface (your function) ---
Nx_sig = Nx; Ny_sig = Ny; T = 200; f = 3; lambda = 6; alpha = 0.08; origin = [0,0];
[Z, x2, y2, t] = generateRippleSurface(Nx_sig, Ny_sig, T, f, lambda, alpha, origin, 'Curved', false); %#ok<ASGLU>

% Pick a time snapshot
t_idx = round(T*0.35);
Zt = Z(:,:,t_idx);                 % Ny x Nx
z_vec_gridOrder = Zt(:);           % linearized in (row-major): matches sub2ind([Ny,Nx], j, i)

% --- 3) Put the scalar field on the graph vertices (match G’s vertex order) ---
% We built vert2grid_lin and grid2vert; G's vertex order is 1..G.N
% Build vector z aligned with vertex ids:
z_vec_graphOrder = zeros(G.N,1);
z_vec_graphOrder(:) = z_vec_gridOrder(vert2grid_lin);  % for each vertex v, pick its grid cell value

% --- 4) Apply the graph Laplacian (combinatorial): L * z ---
L = G.L;   % combinatorial Laplacian = D - W
Lz = L * z_vec_graphOrder;            % (#V x 1)

% --- 5) Apply the 5-point finite difference Laplacian on the grid ---
h = 1;                           % unit spacing to match unit-weight grid graph
Lap_fd = discreteLaplacian5pt(Zt, h);     % Ny x Nx
Lap_fd_vec_gridOrder = Lap_fd(:);

% For visual comparison, bring graph result back to Ny-by-Nx grid order
Lz_onGrid = zeros(Ny*Nx,1);
Lz_onGrid(vert2grid_lin) = Lz;
Lz_onGrid = reshape(Lz_onGrid, [Ny, Nx]);

% --- 6) Quantify agreement (ignore boundaries for fairness) ---
mask = true(Ny, Nx);
mask([1 end],:) = false;
mask(:,[1 end]) = false;

G_num = Lz_onGrid(mask);
FD_num = Lap_fd(mask);

rel_err = norm(G_num - FD_num) / max(1e-12, norm(FD_num));
corrval = corr(G_num(:), FD_num(:));

fprintf('Interior relative error (graph vs 5-pt FD): %.3e\n', rel_err);
fprintf('Interior correlation (graph vs 5-pt FD):   %.6f\n', corrval);

% --- 7) Plots ---
figure('Name','Laplacians comparison','Color','w');
tiledlayout(2,3, 'Padding','compact','TileSpacing','compact');

nexttile; imagesc(Zt); axis image off; colorbar; title(sprintf('Wave snapshot t=%d', t_idx));

nexttile; imagesc(Lz_onGrid); axis image off; colorbar; title('Graph Laplacian L z');
nexttile; imagesc(Lap_fd);    axis image off; colorbar; title('5-pt FD Laplacian');

nexttile([1 3]);
diff_im = Lz_onGrid - Lap_fd;
imagesc(diff_im); axis image off; colorbar;
title(sprintf('Difference (Graph - FD), rel.err=%.2e, corr=%.4f', rel_err, corrval));

% --- 8) (Optional) Surface view with triangles ---
figure('Name','Surface trisurf view','Color','w');
% lift Zt onto vertices (graph order -> V)
Vz = zeros(G.N,1);
Vz(:) = z_vec_gridOrder(vert2grid_lin);    % same values as Zt, now per vertex
Vsurf = V; Vsurf(:,3) = Vz;                % put Z as height

trisurf(TR.ConnectivityList, Vsurf(:,1), Vsurf(:,2), Vsurf(:,3), Vsurf(:,3), ...
        'EdgeColor', 'none'); axis equal; camlight; lighting gouraud; colorbar;
title('Wave snapshot on surface mesh (trisurf)');
xlabel('x'); ylabel('y'); zlabel('z');
view(45,30);
