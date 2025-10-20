function S = fft_vertextime(G0, X, Fs, varargin)
% FFT_VERTEXTIME  Joint time–vertex spectrum using GSPBox (GFT→FFT).
% Builds a proper GSPBox graph from build_icosphere output, then runs gsp_jft.
%
% Usage:
%   S = fft_vertextime(G0, X, Fs, 'NFFT',[], 'Detrend',true, ...
%                      'Window',[], 'NormalizeWindow',true, ...
%                      'MapToDegree',true, 'LmaxTarget',40);
%
% Inputs:
%   G0 : struct from build_icosphere(...)
%   X  : [N×T] signal
%   Fs : sampling rate (Hz)
%
% Options:
%   'NFFT'            : temporal FFT length (default: T)
%   'Detrend'         : subtract time-mean per vertex before JFT (default: true)
%   'Window'          : time window [1×T] (default: [])
%   'NormalizeWindow' : unit-RMS window (default: true)
%   'MapToDegree'     : bin |Xhat|^2 by estimated degree ℓ from λ (default: true)
%   'LmaxTarget'      : max degree used in mapping/binning (default: 40)

    % ---------- options ----------
    p = inputParser;
    addParameter(p,'NFFT',[]);
    addParameter(p,'Detrend',true);
    addParameter(p,'Window',[]);
    addParameter(p,'NormalizeWindow',true);
    addParameter(p,'MapToDegree',true);
    addParameter(p,'LmaxTarget',40);
    parse(p,varargin{:});
    NFFT         = p.Results.NFFT;
    doDetrend    = p.Results.Detrend;
    win          = p.Results.Window;
    normW        = p.Results.NormalizeWindow;
    mapToDegree  = p.Results.MapToDegree;
    LmaxTarget   = p.Results.LmaxTarget;

    % ---------- sizes ----------
    [N,T] = size(X);
    if isempty(NFFT), NFFT = T; end

    % ---------- radius ----------
    if isfield(G0,'R') && ~isempty(G0.R)
        R = G0.R;
    elseif isfield(G0,'V') && ~isempty(G0.V)
        R = mean( sqrt(sum(G0.V.^2,2)) );
    else
        R = 1;
    end

    % ---------- make a GSPBox graph from your mesh ----------
    G = gsp_from_icosphere(G0);          % uses gsp_graph(W, coords)

    % If you want GSPBox to use your exact cotangent L, keep it in G.L
    % Otherwise, it will use G.W to compute the (combinatorial/normalized) L
    if ~isfield(G,'L') || isempty(G.L)
        % Default Laplacian (combinatorial)
        G = gsp_compute_laplacian(G);
    end

    % Graph Fourier basis (uses G.L if present, otherwise from G.W)
    G = gsp_compute_fourier_basis(G);    % adds G.U (N×N), G.e (N×1)
    U   = G.U; lam = G.e(:);
    Nused = size(U,2);
    assert(Nused==N, 'Graph basis size mismatch with X.');

    % ---------- define JTV structure ----------
    G = gsp_jtv_graph(G, T, 1/Fs);
    G.jtv.NFFT = NFFT;

    % ---------- preprocess X ----------
    Xp = X;
    if doDetrend
        Xp = detrend(Xp.').';            % per-vertex mean removal
    end
    if ~isempty(win)
        win = win(:).';
        assert(numel(win)==T, 'Window length must equal #time samples.');
        if normW, win = win / sqrt(mean(win.^2)+eps); end
        Xp = Xp .* win;
    end

    % ---------- JFT via GSPBox ----------
    Xhat = gsp_jft(G, Xp);               % [N×NFFT], i.e., modes × freq
    f = (0:NFFT-1) * (Fs/NFFT);
    Plam_f = abs(Xhat).^2;

    % Mode-time (for parity with fft_icospheretime)
    A = U' * Xp;                         % [N×T]
    A_fft = fft(A, NFFT, 2);             % two-sided

    % ---------- optional: map λ → degree ℓ and bin ----------
    deg=[]; Pell_f=[]; ell_est=[]; k_est=[]; mapper=struct('alpha',NaN,'b',NaN);
    if p.Results.MapToDegree
        LLB  = (0:LmaxTarget)'.*((0:LmaxTarget)'+1);
        Mfit = min(numel(lam), numel(LLB));
        Afit = [LLB(1:Mfit), ones(Mfit,1)];
        yfit = lam(1:Mfit);
        ab   = Afit \ yfit;
        alpha = max(ab(1), eps); b = ab(2);
        mapper.alpha = alpha; mapper.b = b;

        ell_est  = (-1 + sqrt(1 + 4*max((lam - b)/max(alpha,eps), 0))) / 2;
        Lhat     = LmaxTarget;
        ell_bins = round(min(max(ell_est,0), Lhat));

        Pell_f = zeros(Lhat+1, NFFT);
        for k = 1:Nused
            ell = ell_bins(k);
            Pell_f(ell+1,:) = Pell_f(ell+1,:) + Plam_f(k,:);
        end
        deg = (0:Lhat).';
        k_est = (2*pi/R) * sqrt(max(ell_est.*(ell_est+1), 0));
    end

    % ---------- package ----------
    S = struct();
    S.U = U;
    S.lam = lam;
    S.A = A;
    S.A_fft = A_fft;
    S.f = f;
    S.Plam_f = Plam_f;       % λ × f power
    S.Pell_f = Pell_f;       % degree × f (for plot_spacetime_spectrum)
    S.deg = deg;
    S.ell_est = ell_est;
    S.k_est = k_est;
    S.params = struct('NFFT',NFFT,'Fs',Fs,'Detrend',p.Results.Detrend, ...
                      'Window',p.Results.Window,'NormalizeWindow',p.Results.NormalizeWindow, ...
                      'MapToDegree',mapToDegree,'LmaxTarget',LmaxTarget, ...
                      'R',R,'Weights','(implicit via GSPBox)', 'mapper',mapper);
end
