W_geo_ds=downsample(W_geo,10);
W_geo_ds=downsample(W_geo_ds',10);
V_lh_ds=downsample(V_lh,10);
G = gsp_graph(W_geo_ds, V_lh_ds);        % create geodesic-aware graph
G = gsp_compute_fourier_basis(G);  % compute U and Lambda

t = 5;
exp_lambda = exp(-t * G.e);           % decay each eigenvalue
H_t = G.U * diag(exp_lambda) * G.U';  % full heat kernel matrix
diag_H = diag(H_t);
D_heat = sqrt( ...
    diag_H + diag_H' - 2 * H_t ...
);
