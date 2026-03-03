%% Reconstruct (low-pass) vertex coordinates from the first k eigenmodes
% You have:
%   eigen.eigenvectors.value  : Phi  (n x k)
%   ops.mass.value            : massmatrix    (n x n) mass matrix
%   geom.vertex.value         : V    (n x 3) original vertex coords (assumed)
%   geom.face.value           : F    (m x 3) faces (assumed)

Phi = eigen.eigenvectors.value;          % n x k, k=500
massmatrix   = ops.mass.value;                    % n x n (likely sparse in practice)

% ---- Grab original geometry (adjust field names if needed) ----
% In bct, your vertex/face structs likely have a .value field like eigenvectors/mass
V = M.Vertices;                   % n x 3
F = M.Faces;                     % m x 3

% Sanity checks
assert(size(Phi,1) == size(V,1), 'Phi and V must have same #vertices.');
assert(size(V,2) == 3, 'V must be n x 3.');
assert(size(Phi,2) == 500, 'Expecting 500 eigenmodes here (or change k).');

% ---- OPTIONAL: verify massmatrix-orthonormality of eigenvectors ----
% Ideally: Phi' * massmatrix * Phi ≈ I
G = Phi' * (massmatrix * Phi);                    % k x k
fprintf('||Phi^T massmatrix Phi - I||_F = %.3e\n', norm(G - eye(size(G)), 'fro'));

% If your eigenvectors are not massmatrix-orthonormal, you can "whiten" them:
% (This is conservative; often unnecessary if your eigensolver already does it.)
if norm(G - eye(size(G)), 'fro') > 1e-3
    % Make an massmatrix-orthonormal basis spanning the same subspace
    % via Cholesky / eig on G
    [Ug,Sg] = eig((G+G')/2);
    Phi = Phi * (Ug * diag(1./sqrt(diag(Sg))) * Ug');  % Phi <- Phi * G^{-1/2}
end

% ---- Spectral projection of coordinates (mass-inner-product) ----
% Coefficients: C = Phi^T massmatrix V
C = Phi' * (massmatrix * V);                      % (k x 3)

% ---- Reconstruct low-pass geometry ----
Vhat = Phi * C;                          % (n x 3)

% ---- Quantify reconstruction error ----
% massmatrix-weighted RMS error per coordinate and overall:
E    = V - Vhat;                         % n x 3
errM = sqrt(sum(sum(E .* (massmatrix * E))) / sum(diag(massmatrix)));  % scalar, RMS in same units as V
fprintf('massmatrix-weighted RMS vertex error: %.6f (units of V)\n', errM);

% Also report relative error energy
num = trace(E' * (massmatrix * E));
den = trace(V' * (massmatrix * V));
fprintf('Relative massmatrix-energy error: %.4f %%\n', 100 * num / den);

% ---- Visualize original vs reconstructed ----
figure('Color','w'); 
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');

nexttile;
trisurf(F, V(:,1), V(:,2), V(:,3), 'EdgeColor','none');
axis equal off; camlight; lighting gouraud;
title('Original mesh');

nexttile;
trisurf(F, Vhat(:,1), Vhat(:,2), Vhat(:,3), 'EdgeColor','none');
axis equal off; camlight; lighting gouraud;
title('Reconstructed (500-mode low-pass)');

% ---- Visualize displacement magnitude (where detail was removed) ----
d = sqrt(sum((V - Vhat).^2, 2));
figure('Color','w');
trisurf(F, V(:,1), V(:,2), V(:,3), d, 'EdgeColor','none');
axis equal off; camlight; lighting gouraud; colorbar;
title('|V - Vhat| displacement magnitude');

%% Notes:
% 1) This does NOT change topology (faces F are unchanged). It's a geometric smoothing.
% 2) Increasing k preserves finer geometry. Decreasing k yields stronger smoothing.
% 3) If ops.mass.value is dense, consider storing it sparse; otherwise memory will be brutal.
