% Inputs you already have
% % Operators (gptoolbox)
% K = -cotmatrix(V, F);                                   % PSD stiffness
% M = massmatrix(V, F, 'barycentric');                    % diagonal, >0
% K = (K+K.')/2;                                          % enforce symmetry
% d = full(diag(M)); 
% M = spdiags(d,0,length(d),length(d));
% 
% % --- Choose units: make sure V is in mm if you want cycles/mm ---
% % If V is in meters, do:  V = 1000*V;  and then rebuild K,M above.
% 
% % Normalized Laplacian (more numerically tame since M is diagonal)
% Sinv = spdiags(1./sqrt(d), 0, length(d), length(d));
% Ls = (Sinv*K*Sinv); 
% Ls = (Ls + Ls.')/2;
% 
% % --- Eigen solve near zero: use a tiny positive shift to aid convergence ---
% k = 600;                                 % number of modes you want
% opts.tol = 1e-10; 
% opts.maxit = 5000; 
% opts.isreal = true;                       % harmless hint
% sigma = 1e-6;                             % small, improves conditioning
% 
% [U, D] = eigs(Ls, k, sigma, opts);        % shift-invert around ~0+
% lam = real(diag(D));
% 
% % Clean numerical fuzz
% tol = 1e-10 * max(1, max(abs(lam)));      % tolerant but safe
% lam(lam < 0 & lam > -tol) = 0;
% 
% % Drop DC and any negatives beyond tolerance
% mask = lam > tol;
% lam  = lam(mask);
% U    = U(:,mask);
% U, lam, Sinv (not needed for synthesis), and M (via d = diag(M))
%d = full(diag(M));
% What range do we actually have?
f = sqrt(lam)/(2*pi);
fprintf('Computed f-range: [%.4f, %.4f] cycles/mm\n', min(f), max(f));

% How many modes lie near the target band?
f0 = 0.12; bw = 0.03;
nhit = nnz(abs(f - f0) <= 3*bw);
fprintf('# modes within ±3σ of f0: %d\n', nhit);
%% 

% Frequency range actually covered by your current eigenpairs
f_all = sqrt(lam)/(2*pi);
fmin = min(f_all(f_all>0));
fmax = max(f_all);

% Keep a little margin away from edges so the Gaussian isn't clipped
lo = 1.15;          % 15% above fmin
hi = 0.85;          % 15% below fmax
f_lo = lo*fmin;
f_hi = hi*fmax;

%% Example 1 - 5 bands with different bandwidth
% Choose 5 log-spaced centers from long -> short wavelengths
nBands = 5;
f0s = logspace(log10(f_lo), log10(f_hi), nBands);  % centers (cyc/mm)
bw_frac = 0.20;     % bandwidth as a fraction of center (i.e., sigma = 0.2*f0)
rng(7);             % reproducibility for random coefficient signs

X = cell(nBands,1); Pdes = cell(nBands,1); FreqBands = cell(nBands,1);
for i = 1:nBands
    f0 = f0s(i); 
    bw = bw_frac * f0;
    spec = struct('type','narrowband','f0',f0,'bw_frac',bw_frac);
    [x_i, a_i, f] = synth_mesh_signal(U, lam, d, spec);
    X{i}    = x_i;
    Pdes{i} = a_i.^2;   % designed power per eigenmode
    FreqBands{i}    = f;        % eigenmode frequencies
end
%% 
% --- Plot spectra overlay (simple frequency vs power)
figure(1); clf; hold on
for i = 1:nBands
    [fs, idx] = sort(FreqBands{i});
    plot(fs, Pdes{i}(idx), '.-');    % plain overlay; no special colors needed
end
grid on
xlabel('spatial frequency (cycles/mm)');
ylabel('power');
title('Five narrowband designed spectra (long \rightarrow short wavelengths)');
legend(arrayfun(@(c) sprintf('f0=%.4f', c), f0s, 'uni', 0), 'Location','best');
%% 
% --- Show reconstructed fields on the mesh (one figure per band)
for i = 1:nBands
    xrec = X{i};
    RGB = x2rgb(xrec);                 % your helper to colorize vertex data
    B.mesh.VertexColors = RGB; 
    surfaceMeshShow(B.mesh);
    axis image off
    title(sprintf('Narrowband ~ f0=%.4f cyc/mm (bw=%.4f)', f0s(i), bw_frac*f0s(i)));
end
%% Create a multi-band from the 5 narroband signal
% Sum in space
x_sum = zeros(size(X{1}));
for i=1:5, x_sum = x_sum + X{i}; end

% Normalize total M-energy (optional)
Mdiag = spdiags(d,0,numel(d),numel(d));
E = x_sum'*(Mdiag*x_sum);
if E>0, x_sum = x_sum/sqrt(E); end

% Visualize
RGB = x2rgb(x_sum); B.mesh.VertexColors = RGB; surfaceMeshShow(B.mesh); axis image off
title('Sum of 5 narrowband signals');

% Check spectrum of the sum
Sinv = spdiags(1./sqrt(d),0,numel(d),numel(d));
a_sum = U'*(Sinv*x_sum);
P_sum = a_sum.^2;
[freq, idx] = sort(f_all);
figure; plot(freq, P_sum(idx), '.-'); grid on
xlabel('cycles/mm'); ylabel('power'); title('Spectrum of summed signal');


%% Absolute bandwidth
bw_abs = 0.1 * (f_hi - f_lo);
rng(7);  % reproducible signs
X = cell(nBands,1); Pdes = cell(nBands,1); FreqBands = cell(nBands,1);
for i = 1:nBands
    f0 = f0s(i);
    spec = struct('type','narrowband','f0',f0,'bw_abs',bw_abs);
    [x_i, a_i, f] = synth_mesh_signal(U, lam, d, spec);
    X{i}    = x_i;
    Pdes{i} = a_i.^2;    % designed per-mode power
    FreqBands{i}    = f;
end

% Plot the designed spectra (same absolute bandwidth => similar width)
figure(1); clf; hold on
for i = 1:nBands
    [fs, idx] = sort(FreqBands{i});
    plot(fs, Pdes{i}(idx), '.-');
end
grid on
xlabel('spatial frequency (cycles/mm)'); ylabel('power');
title(sprintf('Five narrowband spectra (constant \\Deltaf = %.4g cyc/mm)', bw_abs));
legend(arrayfun(@(c) sprintf('f0=%.4f',c), f0s,'uni',0),'Location','best');
% --- Show reconstructed fields on the mesh (one figure per band)
for i = 1:nBands
    xrec = X{i};
    RGB = x2rgb(xrec);                 % your helper to colorize vertex data
    B.mesh.VertexColors = RGB; 
    surfaceMeshShow(B.mesh);
    axis image off
    title(sprintf('Narrowband ~ f0=%.4f cyc/mm (bw=%.4f)', f0s(i), bw_frac*f0s(i)));
end
%% 

% 1) Narrowband at 0.12 cyc/mm, bandwidth 0.03
spec1 = struct('type','narrowband','f0',0.12,'bw',0.03);
[x1, a1, f] = synth_mesh_signal(U, lam, d, spec1);
RGB = x2rgb(x2); B.mesh.VertexColors = RGB; surfaceMeshShow(B.mesh); title('Narrowband 0.12 cyc/mm');
P1 = a1.^2;
% Plot frequency vs power (sorted by frequency)
[fs, idx] = sort(f);
figure; plot(fs, P1(idx), '.-'); grid on
xlabel('spatial frequency (cycles/mm)');
ylabel('power');
title('Designed spectrum: narrowband @ 0.12 cyc/mm');

% 2) Two peaks at 0.08 and 0.22 cyc/mm
spec2 = struct('type','twoband','f1',0.08,'bw1',0.02,'f2',0.22,'bw2',0.03);
[x2, a2] = synth_mesh_signal(U, lam, d, spec2);
% Visualize (your helper)
RGB = x2rgb(x2); B.mesh.VertexColors = RGB; surfaceMeshShow(B.mesh); title('Narrowband 0.12 cyc/mm');

% 3) Flat spectrum
spec3 = struct('type','flat');
[x3, a3] = synth_mesh_signal(U, lam, d, spec3);
RGB = x2rgb(x3); B.mesh.VertexColors = RGB; surfaceMeshShow(B.mesh); title('Narrowband 0.12 cyc/mm');

% 4) 1/f^alpha with alpha=1.5
spec4 = struct('type','powerlaw','alpha',1.5);
[x4, a4] = synth_mesh_signal(U, lam, d, spec4);

% Visualize (your helper)
RGB = x2rgb(x1); B.mesh.VertexColors = RGB; surfaceMeshShow(B.mesh); title('Narrowband 0.12 cyc/mm');

% Compute back the spectrum from the synthesized x to verify
%Sinv = spdiags(1./sqrt(d), 0, numel(d), numel(d));
% Designed power (no re-projection needed)
P1 = a1.^2;

% Plot frequency vs power (sorted by frequency)
[fs, idx] = sort(f);
figure; plot(fs, P1(idx), '.-'); grid on
xlabel('spatial frequency (cycles/mm)');
ylabel('power');
title('Designed spectrum: narrowband @ 0.12 cyc/mm');


%% 
%% ============= Gradient operator ===============
% Inputs
% --- 1) Gradient operator (piecewise-linear basis)
V = B.mesh.Vertices; 
F = B.mesh.Faces;
 B.mesh.computeNormals;
Vd = double(V);
Fd = double(F);      % <- key line
G  = grad(Vd, Fd);   % (3m) x n
i=1
xrec = X{i};RGB = x2rgb(xrec); B.mesh.VertexColors = RGB; surfaceMeshShow(B.mesh);

g_stacked = G * xrec;                      % (3m) x 1
grad_face = reshape(g_stacked, [], 3);  % m x 3, units: x per mm
% Optional: enforce tangency numerically (projection)
Nf = B.mesh.FaceNormals;           % m x 3 unit normals (gptoolbox)
grad_face = grad_face - sum(grad_face.*Nf,2).*Nf;  % remove tiny normal comp

% Magnitude (slope) on faces
mag_face = sqrt(sum(grad_face.^2,2));   % m x 1
mag_grad = vecnorm(grad_vert,2,2);
% Visualize magnitude as face colors
CF = x2rgb(mag_face);                   % your colorizer can accept per-face too
figure; tsurf(Fd,Vd,'FaceVertexCData',CF,'FaceColor','interp');
axis image off; title('|∇x| (per-face)');
%% 
V = double(B.mesh.Vertices);
F = double(B.mesh.Faces);
Nv=B.mesh.VertexNormals;
% You already have these:
% grad_face: m×3 (projected tangent per face)
% grad_vert: n×3 (area-averaged, projected tangent per vertex)
% Nv       : n×3 (vertex normals, unit)
% x        : n×1 (scalar)
% mag_grad = vecnorm(grad_vert,2,2);

write_surface_vtk('hemi_grad.vtk', V, F, ...
    'point_vectors', grad_vert, ...   % ParaView Surface LIC uses this by default
    'point_scalars', mag_grad, ...    % for coloring
    'point_normals', Nv, ...
    'cell_vectors',  grad_face);      % optional: LIC can also use cell vectors

%% 
C  = barycenter(Vd,Fd);
scale = 5;                              % visual scale factor (mm)
figure; hold on
tsurf(Fd,Vd,'FaceAlpha',0.15); axis image off

quiver3(C(:,1),C(:,2),C(:,3), ...
        grad_face(:,1),grad_face(:,2),grad_face(:,3), scale, 'k');

%% 
V = double(Vd); F = double(Fd);
C = barycenter(V,F);                 % m×3 face centroids

% Ensure face gradient is perfectly tangent + get magnitude
Nf = B.mesh.FaceNormals;          % or B.mesh.FaceNormals (unit)
Nf = Nf ./ max(1e-12, vecnorm(Nf,2,2));
Gf = grad_face - sum(grad_face.*Nf,2).*Nf;   % project to tangent
mag = vecnorm(Gf,2,2);                        % m×1

%% 

r_mm = 4.0;                       % try 3–6 mm
    % Greedy blue-noise on centroids (Euclidean distance in mm)
    mm = size(C,1);
    idx = false(m,1);
    taken = false(m,1);
    % Start from a random order, prefer larger triangles if you want (optional)
    order = randperm(m);
    r2 = r_mm^2;
    for k = order
        if taken(k), continue; end
        idx(k) = true;
        % reject neighbors within r_mm
        D2 = sum((C - C(k,:)).^2, 2);
        taken = taken | (D2 < r2);
    end
    idx = find(idx);
pick = idx;   % indices of faces to plot
Cq = C(pick,:); Gq = Gf(pick,:); magq = mag(pick);
%% 
% Normalize directions; set a physical length (mm) for all arrows
UU = Gq ./ max(magq,1e-12);
L = 5.0;                                % arrow length in mm (constant)
figure; hold on
tsurf(F,V,'FaceAlpha',0.12,'EdgeAlpha',0.03); axis image off
quiver3(Cq(:,1),Cq(:,2),Cq(:,3), UU(:,1),UU(:,2),UU(:,3), L, 'k');
camlight; lighting gouraud; title('Tangent quiver (evenly spaced)');

%% 
% Map magnitude to colors
cm  = parula(256);
magq_n = (magq - min(magq))/max(eps, max(magq)-min(magq));
idx = 1 + floor(magq_n*(size(cm,1)-1)); RGB = cm(idx,:);

% Short segments instead of arrows (less occlusion, super clear)
U = Gq ./ max(magq,1e-12);
L = 5.0;   % segment length in mm
P0 = Cq;   P1 = Cq + L*U;

figure; hold on
tsurf(F,V,'FaceAlpha',0.12,'EdgeAlpha',0.03); axis image off vis3d
for i = 1:size(P0,1)
    line([P0(i,1) P1(i,1)], [P0(i,2) P1(i,2)], [P0(i,3) P1(i,3)], ...
         'Color', RGB(i,:), 'LineWidth', 1.5);
end
camlight headlight; lighting gouraud
title('|∇x|-colored tangent segments');
colormap(parula); colorbar; caxis([min(magq) max(magq)]);

%% 

% Prepare grad_face (already tangent). Optionally normalize first:
demo_streamlines_on_mesh(Vd,Fd,grad_face, 300, 2.0, 150);
