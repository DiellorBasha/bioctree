function demo_jtv_line_equals_wavedec2
% Show that a separable joint time–vertex wavelet (line graph, decimated)
% equals a 2-D separable DWT on X(x,t).

clc; close all;
dwtmode('per','nodisp');       % periodic BCs => clean algebra (matches separable theory)

% --- data: traveling wave on a line ---
[Nx,T] = deal(128, 256);
[X, x, t] = generateRippleLine(Nx, T, 3, 16, 0.02, 0); %#ok<ASGLU>

wname = 'db2';                 % any orthonormal wavelet: 'haar','db2','sym4',...

% ===================== Route A: 2-D DWT directly ==========================
% dwt2 does: rows (x) then columns (t), separably & with decimation
[cA, cH, cV, cD] = dwt2(X, wname);
% Interpretation given our axes (rows=x, cols=t):
%   cA = Lx Lt  (LL)
%   cH = Lx Ht  (LH : high along time)
%   cV = Hx Lt  (HL : high along space)
%   cD = Hx Ht  (HH : high along both)

% ===================== Route B: "JTV (decimated)" =========================
% Step 1: DWT along the vertex (x) dimension at each t
[Lx, Hx] = dwt_along_dim(X, 1, wname);     % Lx,Hx: sizes (Nx/2) x T

% Step 2: DWT along the time (t) dimension on each spatial sub-signal
[LL, LH] = dwt_along_dim(Lx, 2, wname);    % (Lx -> low/high in time)
[HL, HH] = dwt_along_dim(Hx, 2, wname);    % (Hx -> low/high in time)

% ===================== Compare subbands ================================
% Match names: Route A (cA,cH,cV,cD) vs Route B (LL,LH,HL,HH)
subA = {cA, cH, cV, cD};
subB = {LL, LH, HL, HH};
names = {'LL','LH','HL','HH'};

absdiff = zeros(1,4); relerr = zeros(1,4);
for k=1:4
    A = subA{k}; B = subB{k};
    absdiff(k) = max(abs(A(:)-B(:)));
    relerr(k)  = norm(A(:)-B(:)) / max(1e-12, norm(B(:)));
end

fprintf('Max abs diff per subband [LL LH HL HH]:  '); fprintf('%g ', absdiff); fprintf('\n');
fprintf('Rel. err per subband       [LL LH HL HH]:  '); fprintf('%.2e ', relerr); fprintf('\n');

% ===================== Visual sanity checks ============================
figure('Color','w','Name','Subbands: 2D-DWT (Route A)');
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
for k=1:4
    nexttile; imagesc(subA{k}); axis image tight; colorbar;
    title(['Route A ', names{k}]);
    xlabel('t (decimated)'); ylabel('x (decimated)');
end

figure('Color','w','Name','Subbands: JTV (Route B)');
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
for k=1:4
    nexttile; imagesc(subB{k}); axis image tight; colorbar;
    title(['Route B ', names{k}]);
    xlabel('t (decimated)'); ylabel('x (decimated)');
end

% ===================== Reconstruction parity (optional) ================
% From Route A:
X_rec_A = idwt2(cA, cH, cV, cD, wname, size(X));
% From Route B:
Lx_rec  = idwt_along_dim(LL, LH, 2, wname);   % invert time on low-space branch
Hx_rec  = idwt_along_dim(HL, HH, 2, wname);   % invert time on high-space branch
X_rec_B = idwt_along_dim(Lx_rec, Hx_rec, 1, wname);  % invert space

fprintf('Reconstruction error (A): %g\n', max(abs(X(:)-X_rec_A(:))));
fprintf('Reconstruction error (B): %g\n', max(abs(X(:)-X_rec_B(:))));
fprintf('A vs B recon max abs diff: %g\n', max(abs(X_rec_A(:)-X_rec_B(:))));
end

% ===== helpers: 1D DWT along a matrix dimension (decimated) =====
function [L,H] = dwt_along_dim(M, dim, wname)
    % dim = 1 => process down columns (along x); dim = 2 => along rows (time)
    if dim==1
        [Nx, T] = size(M);
        Nx2 = Nx/2; assert(mod(Nx,2)==0, 'Nx must be even for one-level decimation.');
        L = zeros(Nx2, T, 'like', M);
        H = zeros(Nx2, T, 'like', M);
        for t = 1:T
            [l,h] = dwt(M(:,t), wname);
            L(:,t) = l(:);
            H(:,t) = h(:);
        end
    elseif dim==2
        [Nx, T] = size(M);
        T2 = T/2; assert(mod(T,2)==0, 'T must be even for one-level decimation.');
        L = zeros(Nx, T2, 'like', M);
        H = zeros(Nx, T2, 'like', M);
        for j = 1:Nx
            [l,h] = dwt(M(j,:), wname);
            L(j,:) = l(:).';
            H(j,:) = h(:).';
        end
    else
        error('dim must be 1 or 2.');
    end
end

function M = idwt_along_dim(L, H, dim, wname)
    if dim==1
        [Nx2, T] = size(L);
        M = zeros(2*Nx2, T, 'like', L);
        for t = 1:T
            M(:,t) = idwt(L(:,t), H(:,t), wname);
        end
    elseif dim==2
        [Nx, T2] = size(L);
        M = zeros(Nx, 2*T2, 'like', L);
        for j = 1:Nx
            M(j,:) = idwt(L(j,:), H(j,:), wname);
        end
    else
        error('dim must be 1 or 2.');
    end
end
