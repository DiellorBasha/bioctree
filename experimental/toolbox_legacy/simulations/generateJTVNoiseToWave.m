% --- Inputs you already have:
% X : [256 x 796] line-time signal (rows = space, cols = time)
% x : [256 x 1] spatial coordinates (optional for plotting)
% t : [1 x 796]  time vector
%% 
% Generate a morphing signal and animate it
[X,x,t] = generateLineNoiseToWave(256, 400, 10, 16, 0.02, 0, ...
    'RampFrac',0.6, 'RampShape','cosine', 'NoiseAR',0.98, ...
    'SpatialSigma',2.5, 'Seed', 7, ...
    'XSpan', [-128 128], 'TSpan', [0 1], ...
    'RampType','two-sided', 'HoldFrac',0.250, ...
     'MaskType','Gaussian', 'MaskWidth', 100);
% Generate a morphing signal and animate it
[X1,x1,t1] = generateLineNoiseToWave(256, 400, 20, 4, 0.02, 64, ...
    'RampFrac',0.6, 'RampShape','cosine', 'NoiseAR',0.98, ...
    'SpatialSigma',2.5, 'Seed', 7, ...
    'XSpan', [-128 128], 'TSpan', [1 2], ...
    'RampType','two-sided', 'HoldFrac',0.05, ...
     'MaskType','Gaussian', 'MaskWidth', 8);
% choose an overlap (e.g., 0.15 s)
overlapSec = 0.01;
[Y, ty] = crossfadeXT(X, t, X1, t1, overlapSec);

X=Y; t=ty;

N = size(X,1);
T = size(X,2);
%% 

% ===== 1) Build the spatial graph in GSPBox =====
% Choose boundary condition:
use_cycle = false;     % false = path/line graph; true = cycle/ring (periodic)

if use_cycle
    G = gsp_ring(N);                   % periodic ends (matches spatial FFT)
else
    G = gsp_path(N);                   % open ends (DCT-like spatial harmonics)
end
G = gsp_compute_fourier_basis(G);      % adds G.U (NxN), G.e (eigs)

% ===== 2) Define the Joint (time-vertex) transform operators =====

G = gsp_jtv_graph(G,T,diff(t(1:2)));
param.show_edges=1
gsp_plot_jtv_signal(G,X, param);
Xhat = gsp_jft(G,X);
% Graph Fourier Transform (vertex):   Xg = U' * X
% Temporal DFT (along columns):       Xgw = fft(Xg, [], 2)
% Joint Fourier = vertex GFT then time DFT:
% jft  = @(X) fft(G.U' * X, [], 2);
% ijft = @(Xhat) G.U * ifft(Xhat, [], 2);   % inverse (G.U is unitary)

% % ===== 3) Compute JFT and reconstruct =====
% Xhat = jft(X);
% Xrec = ijft(Xhat);

% recon_err = max(abs(X(:) - Xrec(:)));
% fprintf('JFT/iJFT reconstruction max-abs error: %.3g\n', recon_err);
% 
% ===== 4) Visualize joint spectrum (power) =====
figure('Color','w','Name','Joint time-vertex spectrum');
imagesc(0:T-1, 0:N-1, abs(Xhat).^2); axis xy;
xlabel('temporal frequency index (DFT k)'); ylabel('graph frequency index (eigenmode m)');
title('Joint power |X̂(m,k)|^2'); colorbar;

% Optional: overlay graph eigenvalues as "spatial frequency" ticks
% yt = round(linspace(1,N,8)); yticklabels(arrayfun(@(m) sprintf('%.3f', G.e(m)), yt, 'uni',0));

% ===== 5) (Optional) Compare to 2-D FFT when using a cycle (periodic BCs) =====
if use_cycle
    % 2-D unitary DFT for fair comparison (fft2 is non-unitary scaling)
    FN = dftmtx(N)/sqrt(N);
    FT = dftmtx(T)/sqrt(T);
    Xhat_dft = FN * X * FT;   % unitary 2-D DFT

    % GFT basis on a cycle equals DFT up to column ordering/phase.
    % Align by correlating columns if you want strict equality; here we just show norms:
    fprintf('||JFT||_F = %.3g,  ||unitary 2D DFT||_F = %.3g\n', norm(Xhat,'fro'), norm(Xhat_dft,'fro'));

    % Quick sanity: there exists a permutation/phase such that Xhat ≈ Xhat_dft.
    % (If you need exact alignment, I can add a small matcher.)
end

