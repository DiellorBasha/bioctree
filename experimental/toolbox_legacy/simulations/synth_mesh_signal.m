function [xrec, a, f] = synth_mesh_signal(U, lam, d, spec)
% U   : n x k eigenvectors of Ls (columns orthonormal)
% lam : k x 1 eigenvalues (>=0)
% d   : n x 1 mass diagonals (diag(M))
% spec: struct describing desired spectrum (see helpers below)
%
% xrec: n x 1 synthesized vertex signal
% a   : k x 1 coefficients used
% f   : k x 1 spatial frequencies (cycles/mm)

    % frequencies for convenience
    f = sqrt(lam) / (2*pi);

    % design target power per mode
    P = design_power(f, spec);      % nonnegative power per frequency

    % coefficients: random +/- phase (real field) with desired power
    sgn = sign(randn(size(P)));     % random signs
    a   = sgn .* sqrt(P(:));

    % reconstruct: xw = U*a, then x = M^(+1/2)*xw
    S = spdiags(sqrt(d), 0, numel(d), numel(d));  % M^(+1/2)
    xrec = S * (U * a);

    % normalize (optional): unit RMS in M-inner product
    Ex = (xrec' * (spdiags(d,0,length(d),length(d)) * xrec));
    if Ex > 0
        xrec = xrec / sqrt(Ex);
    end
end

function P = design_power(f, spec)
% Returns power per mode for several shapes.
% All outputs are scaled to have sum(P)=1 (so you control total energy upstream).
    switch lower(spec.type)
        case 'narrowband'   % Gaussian around f0
            if isfield(spec,'bw_abs')
                bw = spec.bw_abs;                 % absolute bandwidth (cycles/mm)
            elseif isfield(spec,'bw_frac')
                bw = spec.bw_frac * spec.f0;      % fractional bandwidth
            elseif isfield(spec,'bw')
                bw = spec.bw;                     % BACK-COMPAT: treat as absolute
            else
                error('Provide bw_abs (absolute) or bw_frac (fraction of f0) or bw (absolute).');
            end
            P = exp(-0.5*((f - spec.f0)/max(bw,eps)).^2);

        case 'twoband'      % sum of two Gaussians
            f1 = spec.f1; bw1 = spec.bw1; f2 = spec.f2; bw2 = spec.bw2;
            P = exp(-0.5*((f - f1)/max(bw1,eps)).^2) + ...
                exp(-0.5*((f - f2)/max(bw2,eps)).^2);

        case 'flat'         % white in Laplacian frequency
            P = ones(size(f));

        case 'powerlaw'     % 1/f^alpha (alpha>0)
            alpha = spec.alpha;
            P = (f + eps).^(-alpha);

        case 'bandpass'     % rectangular band [fmin,fmax]
            P = double(f >= spec.fmin & f <= spec.fmax);

        otherwise
            error('Unknown spec.type');
    end
    s = sum(P);
    if s>0, P = P/s; end
end
