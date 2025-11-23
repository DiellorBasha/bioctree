function [Xhat_shift, axes] = jtv_fftshift_cycle(X, dt, dx, nfft)
% X: [N x T], dt, dx spacings; nfft = [Nfft_space, Nfft_time]
% Returns Xhat with DC centered in both dims and axes {k_rad_per_unit, f_Hz}

    if nargin < 4 || isempty(nfft), nfft = size(X); end
    N = size(X,1); T = size(X,2);
    Nf = nfft(1); Tf = nfft(2);

    % Unitary DFTs (so energy is preserved and matching is clean)
    FN = dftmtx(N)/sqrt(N);
    FT = dftmtx(T)/sqrt(T);

    % Zero-pad if requested (space first, then time), then transform
    Xp = X;
    if Nf ~= N
        Xp = padarray(Xp, [Nf-N, 0], 'post');
    end
    if Tf ~= T
        Xp = padarray(Xp, [0, Tf-T], 'post');
    end

    % 2-D unitary DFT
    Xhat = FN(1:Nf,1:N) * Xp * FT(1:T,1:Tf);

    % Two-sided axes and centered spectrum
    k_idx = (-floor(Nf/2):ceil(Nf/2)-1);
    f_idx = (-floor(Tf/2):ceil(Tf/2)-1);

    k_rad = (2*pi) * (k_idx / (Nf*dx));   % spatial angular frequency (rad/unit)
    f_hz  = f_idx / (Tf*dt);              % temporal frequency (Hz)

    Xhat_shift = fftshift(fftshift(Xhat,1),2);
    axes = struct('k_rad', k_rad, 'f_hz', f_hz);
end
