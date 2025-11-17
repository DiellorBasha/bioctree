function [xrec, a, f] = synth_mesh_signal(B, spec, varargin)
%SYNTH_MESH_SIGNAL Synthesize graph signal from spectral power specification
%
%   xrec = bct.sim.synth_mesh_signal(B, spec) synthesizes a random graph signal
%       with spectral content matching the specification.
%
%   [xrec, a, f] = bct.sim.synth_mesh_signal(B, spec) also returns:
%       a - k×1 spectral coefficients used
%       f - k×1 spatial frequencies (cycles/mm)
%
%   Parameters:
%       'k'         - Number of eigenvalues/eigenvectors to use (default: 200)
%                     If B.Manifold already has eigenvectors computed, will reuse them
%       'normalize' - Normalize output to unit RMS (default: true)
%       'verbose'   - Print computation progress (default: true)
%
%   Spec Structure:
%       spec.type - 'narrowband', 'twoband', 'flat', 'powerlaw', 'bandpass'
%
%       For 'narrowband':
%           spec.f0       - Center frequency (cycles/mm)
%           spec.bw_abs   - Absolute bandwidth (cycles/mm) OR
%           spec.bw_frac  - Fractional bandwidth (fraction of f0)
%
%       For 'twoband':
%           spec.f1, spec.bw1 - First band center and bandwidth
%           spec.f2, spec.bw2 - Second band center and bandwidth
%
%       For 'powerlaw':
%           spec.alpha - Power law exponent (e.g., 1 for 1/f noise)
%
%       For 'bandpass':
%           spec.fmin, spec.fmax - Frequency band limits
%
%   Returns:
%       xrec - N×1 single precision synthesized vertex signal
%       a    - k×1 spectral coefficients
%       f    - k×1 spatial frequencies
%
%   Example:
%       B = bct.io.graph.Import.fromFreeSurfer('lh.pial');
%       
%       % Narrowband signal around 0.1 cycles/mm
%       spec.type = 'narrowband';
%       spec.f0 = 0.1;
%       spec.bw_abs = 0.02;
%       x = bct.sim.synth_mesh_signal(B, spec);
%       
%       % 1/f noise
%       spec.type = 'powerlaw';
%       spec.alpha = 1;
%       x = bct.sim.synth_mesh_signal(B, spec);
%
%   The function uses the graph Laplacian eigenbasis to construct signals
%   with desired spectral properties.
%
%   See also: bct.sim.gaussian, bct.sim.patch_signal

    % Get dimensions from Manifold
    N = size(B.Manifold.V, 1);
    
    % Parse inputs
    p = inputParser;
    p.addParameter('k', 200, @(x)isscalar(x)&&x>0);  % Default 200 modes
    p.addParameter('normalize', true, @islogical);
    p.addParameter('verbose', true, @islogical);
    p.parse(varargin{:});
    
    k = min(round(p.Results.k), N-1);  % Ensure k < N for eigendecomposition
    k = max(k, 1);  % Ensure at least 1 mode
    do_normalize = p.Results.normalize;
    verbose = p.Results.verbose;
    
    % Get eigenvectors and eigenvalues using cached Manifold methods
    if B.Manifold.Type == "mesh"
        % For mesh: check if eigenvectors already exist
        % Note: meshFourier(k) may return fewer than k modes due to DC/negative filtering
        available_modes = B.Manifold.NumModes;
        
        if available_modes > 0 && available_modes >= k - 1
            % Use existing cached eigenvectors (allow k-1 tolerance for DC filtering)
            k_actual = min(k, available_modes);
            if verbose
                fprintf('[bct.sim.synth_mesh_signal] Using cached eigenvectors (k=%d/%d modes)\n', ...
                    k_actual, available_modes);
            end
            U = B.Manifold.Eigenvectors(:, 1:k_actual);
            lam = B.Manifold.Eigenvalues(1:k_actual);
            M = B.Manifold.MassMatrix;
            k = k_actual;  % Update k to actual number used
        else
            % Need to compute or recompute eigenvectors
            if verbose
                fprintf('[bct.sim.synth_mesh_signal] Computing eigenvectors using meshFourier (k=%d)...\n', k);
            end
            [U, lam, ~, M] = B.Manifold.meshFourier(k);
            k = size(U, 2);  % Update k to actual computed modes
            if verbose
                fprintf('[bct.sim.synth_mesh_signal] ✓ Eigendecomposition complete (k=%d modes stored in B.Manifold)\n', k);
            end
        end
        d = full(diag(M));  % Mass diagonals
        lam = lam(:);       % Ensure column vector
    else
        % For graph: use eigenpairs with combinatorial Laplacian
        if verbose
            fprintf('[bct.sim.synth_mesh_signal] Computing graph eigenpairs (k=%d)...\n', k);
        end
        [U, lam] = B.Manifold.eigenpairs(k, 'combinatorial');
        d = ones(N, 1);     % Unit mass for graphs
        if verbose
            fprintf('[bct.sim.synth_mesh_signal] ✓ Graph eigendecomposition complete\n');
        end
    end
    
    % Ensure eigenvalues are non-negative (numerical issues)
    lam = max(0, real(lam));
    
    % Frequencies for convenience
    f = sqrt(lam) / (2*pi);
    
    % Design target power per mode
    P = design_power(f, spec);      % nonnegative power per frequency
    
    % Coefficients: random +/- phase (real field) with desired power
    sgn = sign(randn(size(P)));     % random signs
    a   = sgn .* sqrt(P(:));
    
    % Reconstruct: xw = U*a, then x = M^(+1/2)*xw
    S = spdiags(sqrt(d), 0, numel(d), numel(d));  % M^(+1/2)
    xrec = S * (U * a);
    
    % Normalize (optional): unit RMS in M-inner product
    if do_normalize
        Ex = (xrec' * (spdiags(d, 0, length(d), length(d)) * xrec));
        if Ex > 0
            xrec = xrec / sqrt(Ex);
        end
    end
    
    % Convert to single precision
    xrec = single(xrec);
end

%% Helper function

function P = design_power(f, spec)
    % Returns power per mode for several shapes.
    % All outputs are scaled to have sum(P)=1 (control total energy upstream).
    
    switch lower(spec.type)
        case 'narrowband'   % Gaussian around f0
            if isfield(spec, 'bw_abs')
                bw = spec.bw_abs;                 % absolute bandwidth (cycles/mm)
            elseif isfield(spec, 'bw_frac')
                bw = spec.bw_frac * spec.f0;      % fractional bandwidth
            elseif isfield(spec, 'bw')
                bw = spec.bw;                     % BACK-COMPAT: treat as absolute
            else
                error('bct:sim:synth_mesh_signal:noBandwidth', ...
                    'Provide bw_abs (absolute) or bw_frac (fraction of f0)');
            end
            P = exp(-0.5 * ((f - spec.f0) / max(bw, eps)).^2);
            
        case 'twoband'      % sum of two Gaussians
            f1 = spec.f1; bw1 = spec.bw1;
            f2 = spec.f2; bw2 = spec.bw2;
            P = exp(-0.5 * ((f - f1) / max(bw1, eps)).^2) + ...
                exp(-0.5 * ((f - f2) / max(bw2, eps)).^2);
            
        case 'flat'         % white in Laplacian frequency
            P = ones(size(f));
            
        case 'powerlaw'     % 1/f^alpha (alpha>0)
            alpha = spec.alpha;
            P = (f + eps).^(-alpha);
            
        case 'bandpass'     % rectangular band [fmin,fmax]
            P = double(f >= spec.fmin & f <= spec.fmax);
            
        otherwise
            error('bct:sim:synth_mesh_signal:unknownSpecType', ...
                'Unknown spec.type: %s', spec.type);
    end
    
    s = sum(P);
    if s > 0
        P = P / s;
    end
end
