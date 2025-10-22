% Inputs from your struct A:
V = A.Vertices;           % (N x 3)
F = A.Faces;              % (F x 3) triangle indices (1-based)

N = size(V,1);

% -- Helper: edge vectors per face
v1 = V(F(:,2),:) - V(F(:,3),:);
v2 = V(F(:,3),:) - V(F(:,1),:);
v3 = V(F(:,1),:) - V(F(:,2),:);

% -- Squared edge lengths opposite vertices 1,2,3
l1 = sum(v1.^2,2); l2 = sum(v2.^2,2); l3 = sum(v3.^2,2);

% -- Triangle areas (double area via cross product)
nrm = cross(v2, -v3, 2);         % corresponds to edges around F(:,1)
Atri = 0.5 * sqrt(sum(nrm.^2,2)); % (F x 1)

% -- Cotangents of angles at vertices 1,2,3 in each face
%    Using formula: cot(alpha) = (b^2 + c^2 - a^2) / (4*Area), with a opposite alpha.
cot1 = (l2 + l3 - l1) ./ (4*Atri + eps);
cot2 = (l3 + l1 - l2) ./ (4*Atri + eps);
cot3 = (l1 + l2 - l3) ./ (4*Atri + eps);

% -- Assemble symmetric cotangent weights W_ij = (cot alpha + cot beta)/2 for each edge
I = [F(:,2); F(:,3); F(:,3)];    J = [F(:,3); F(:,1); F(:,2)];
Wvals = [cot1;   cot2;   cot3];  % cot opposite each edge
W = sparse(I, J, Wvals, N, N);
W = 0.5*(W + W.');               % sum contributions of adjacent faces and symmetrize
W(W<0) = 0;                      % (optional) clamp tiny negatives due to numeric noise

% -- Degree
d = full(sum(W,2));
D = spdiags(d,0,N,N);

% -- Per-vertex dual (mixed Voronoi) areas for area-normalized LB
%    Simple, robust approximation: accumulate one-third of incident triangle areas.
Avert = accumarray(F(:), repmat(Atri/3,3,1), [N,1]);   % (N x 1)
Ainv = spdiags(1./max(Avert,eps), 0, N, N);

% -- Laplace–Beltrami options:
L_comb = D - W;                       % combinatorial (no area normalization)
L_un   = Ainv * (D - W);              % invariant to mesh refinement (recommended)
% Or symmetric normalized variant:
Asqrtinv = spdiags(1./sqrt(max(Avert,eps)), 0, N, N);
L_sym = Asqrtinv * (D - W) * Asqrtinv;
Go=G;
% -- Build GSP graph with geometry-aware weights
G = gsp_graph(W);
G.coords = V;
G.L = L_un;             % overwrite with area-normalized LB
G = gsp_estimate_lmax(G);
%% 
Hn = G.L * V;                        % (N x 3) mean-curvature normal (up to constant)
Hmag = 0.5 * sqrt(sum(Hn.^2,2));     % |H| magnitude proxy

figure; gsp_plot_signal(G, Hmag); title('|Mean curvature| (from L * coords)');
colormap("hot")
% Compare direction with provided normals (rough check of sign consistency)
cosang = sum(Hn .* A.VertNormals, 2) ./ (sqrt(sum(Hn.^2,2))+eps);
fprintf('Median cos(angle(Hn, normal)) = %.3f\n', median(cosang));
%% 
C_ref = double(A.Curvature(:));       % N×1 (Brainstorm)
C_est = Hmag;                         % our estimate

% Mask NaNs/Inf and extreme outliers (optional)
m = isfinite(C_ref) & isfinite(C_est);
C_ref = C_ref(m); C_est = C_est(m);

% Compare in a scale-free way
C_ref_z = (C_ref - median(C_ref)) / iqr(C_ref);
C_est_z = (C_est - median(C_est)) / iqr(C_est);
% Pearson & Spearman correlation
R_pear = corr(C_ref_z, C_est_z, 'type','Pearson');
R_spear = corr(C_ref_z, C_est_z, 'type','Spearman');

% Simple linear fit (scale/offset)
P = polyfit(C_ref_z, C_est_z, 1);     % C_est_z ≈ P(1)*C_ref_z + P(2)
C_pred = polyval(P, C_ref_z);
rmse = sqrt(mean((C_est_z - C_pred).^2));

fprintf('Pearson r = %.3f, Spearman rho = %.3f, slope = %.3f, RMSE = %.3f\n', ...
        R_pear, R_spear, P(1), rmse);
% Scatter with identity & fit
figure('Name','Curvature comparison');
scatter(C_ref_z, C_est_z, 6, '.', 'MarkerEdgeAlpha',0.3); hold on; grid on
xl = xlim; plot(xl, xl, 'k--');                % identity
plot(xl, P(1)*xl + P(2), 'r-');                % regression
xlabel('A.Curvature (z/IQR)'); ylabel('LB estimate |H| (z/IQR)');
title(sprintf('r=%.3f, \\rho=%.3f, slope=%.2f', R_pear, R_spear, P(1)));

% Residuals
figure('Name','Residuals'); histogram(C_est_z - C_ref_z, 60); grid on
xlabel('Residual (est - ref)'); ylabel('count'); title('Residual histogram');

% Surface maps (needs GSP graph or patch)
G = gsp_graph(W); G.coords = V;           % for convenient plotting
gsp_plot_signal(G, nan_fill(~m, C_ref_z)); title('Reference curvature (z/IQR)');
figure; gsp_plot_signal(G, nan_fill(~m, C_est_z)); title('Estimated curvature (z/IQR)');
figure; gsp_plot_signal(G, nan_fill(~m, C_est_z - C_ref_z)); title('Difference map (est - ref)');

function y = nan_fill(mask_bad, x)
    yfull = nan(numel(mask_bad),1); yfull(~mask_bad) = x; y = yfull;
end
%% 
scales = logspace(-2, 0, 5);
Wk = gsp_design_mexican_hat(G, scales);
F  = gsp_filter_analysis(G, Wk, V);              % (N*#scales)×3
F  = gsp_vec2mat(F, numel(scales));              % N×#scales×3
curv_ms = sqrt(sum(F.^2, 3));                    % N×#scales

% Correlate across scales; pick the scale that best matches A.Curvature
r_per_scale = zeros(numel(scales),1);
for s = 1:numel(scales)
    cs = curv_ms(:,s); cs = cs(m);
    cs_z = (cs - median(cs))/iqr(cs);
    r_per_scale(s) = corr(C_ref_z, cs_z, 'type','Spearman');
end
[best_r, best_k] = max(r_per_scale);
fprintf('Best wavelet scale idx = %d (r=%.3f)\n', best_k, best_r);

figure; plot(scales, r_per_scale, 'o-'); set(gca,'XScale','log'); grid on
xlabel('Wavelet scale'); ylabel('Spearman r');
title('Curvature agreement vs wavelet scale');




