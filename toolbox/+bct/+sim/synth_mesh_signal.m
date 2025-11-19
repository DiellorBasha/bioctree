function [B_out, a, f] = synth_mesh_signal(B, spec, varargin)
%SYNTH_MESH_SIGNAL Synthesize graph signal from spectral power specification
%
%   B_out = bct.sim.synth_mesh_signal(B, spec) synthesizes a random graph signal
%       with spectral content matching the specification and returns a bct object
%       with the signal added as a bct.signal.Signal object.
%
%   [B_out, a, f] = bct.sim.synth_mesh_signal(B, spec) also returns:
%       a - k×1 spectral coefficients used
%       f - k×1 spatial frequencies (cycles/mm)
%
%   Parameters:
%       'k'         - (Optional) Number of eigenvalues/eigenvectors to use.
%                     If not specified and B.Manifold has cached eigenvectors, uses all cached modes.
%                     If not specified and no cache exists, computes k=200 modes.
%                     If specified, uses exactly k modes (computing if necessary).
%       'normalize' - Normalize output to unit RMS (default: true)
%       'verbose'   - Print computation progress (default: true)
%       'label'     - Label for the Signal object (default: auto-generated from spec)
%       'return_raw'- If true, returns raw data [N×1] instead of bct object (legacy mode)
%
%   Spec Structure (can be a single struct or array of structs):
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
%       B_out - bct object with Signal(s) added (if return_raw=false)
%       xrec  - N×1 single precision synthesized vertex signal (if return_raw=true)
%       a     - k×1 spectral coefficients
%       f     - k×1 spatial frequencies
%
%   Example:
%       % Single signal
%       B = bct.bct.fromMesh(V, F);
%       B.Manifold.meshFourier(600);  % Precompute eigenbasis
%       
%       spec.type = 'narrowband';
%       spec.f0 = 0.1;
%       spec.bw_abs = 0.02;
%       B = bct.sim.synth_mesh_signal(B, spec, 'label', 'alpha_band');
%       
%       % Multiple signals with same cached basis
%       specs = struct('type', {}, 'f0', {}, 'bw_abs', {});
%       for i = 1:5
%           specs(i).type = 'narrowband';
%           specs(i).f0 = 0.05 * i;
%           specs(i).bw_abs = 0.01;
%       end
%       B = bct.sim.synth_mesh_signal(B, specs);
%       
%       % 1/f noise
%       spec.type = 'powerlaw';
%       spec.alpha = 1;
%       B = bct.sim.synth_mesh_signal(B, spec, 'k', 300, 'label', 'pink_noise');
%       
%       % Legacy mode (returns raw data)
%       x = bct.sim.synth_mesh_signal(B, spec, 'return_raw', true);
%
%   The function uses the graph Laplacian eigenbasis to construct signals
%   with desired spectral properties.
%
%   See also: bct.sim.gaussian, bct.sim.patch_signal, bct.signal.Signal

    % Get dimensions from Manifold
    N = size(B.Manifold.V, 1);
    
    % Parse inputs
    p = inputParser;
    p.addParameter('k', [], @(x)isempty(x)||(isscalar(x)&&x>0));  % Empty = use cached or default 200
    p.addParameter('normalize', true, @islogical);
    p.addParameter('verbose', true, @islogical);
    p.addParameter('label', '', @(x)ischar(x)||isstring(x));
    p.addParameter('return_raw', false, @islogical);
    p.parse(varargin{:});
    
    k_requested = p.Results.k;
    do_normalize = p.Results.normalize;
    verbose = p.Results.verbose;
    user_label = string(p.Results.label);
    return_raw = p.Results.return_raw;
    
    % Handle array of specs (generate multiple signals)
    if numel(spec) > 1
        if verbose
            fprintf('[bct.sim.synth_mesh_signal] Generating %d signals from spec array\n', numel(spec));
        end
        
        % Copy input bct object
        B_out = B;
        
        % Generate each signal
        for i = 1:numel(spec)
            if isempty(user_label)
                label_i = generate_label(spec(i), i);
            else
                label_i = sprintf('%s_%d', user_label, i);
            end
            
            % Generate single signal (recursive call with return_raw=true)
            [xrec_i, a_i, f_i] = bct.sim.synth_mesh_signal(B, spec(i), ...
                'k', k_requested, ...
                'normalize', do_normalize, ...
                'verbose', false, ...
                'return_raw', true);
            
            % Create Signal object and add to bct
            sig = bct.signal.Signal(B_out.Manifold, xrec_i, label_i);
            B_out.addSignal(sig);
            
            % Store outputs for last signal (for backward compatibility)
            if i == numel(spec)
                a = a_i;
                f = f_i;
            end
        end
        
        if verbose
            fprintf('[bct.sim.synth_mesh_signal] ✓ Added %d signals to bct object\n', numel(spec));
        end
        
        return;
    end
    
    % Get eigenvectors and eigenvalues using cached Manifold methods
    if B.Manifold.Type == "mesh"
        % For mesh: check if eigenvectors already exist
        available_modes = B.Manifold.NumModes;
        
        % Determine how many modes to use
        if isempty(k_requested)
            % No k specified: use cached modes if available, else default 200
            if available_modes > 0
                k = available_modes;
                if verbose
                    fprintf('[bct.sim.synth_mesh_signal] Using all cached eigenvectors (k=%d modes)\n', k);
                end
            else
                k = min(200, N-1);
                if verbose
                    fprintf('[bct.sim.synth_mesh_signal] No cached modes found, computing default k=%d modes\n', k);
                end
            end
        else
            % k was explicitly specified
            k = min(round(k_requested), N-1);
            k = max(k, 1);
        end
        
        % Now get or compute the eigenvectors
        if available_modes > 0 && available_modes >= k
            % Use existing cached eigenvectors
            if verbose && ~isempty(k_requested)
                fprintf('[bct.sim.synth_mesh_signal] Using cached eigenvectors (k=%d/%d modes)\n', ...
                    k, available_modes);
            end
            U = B.Manifold.Eigenvectors(:, 1:k);
            lam = B.Manifold.Eigenvalues(1:k);
        else
            % Need to compute or recompute eigenvectors
            if verbose
                fprintf('[bct.sim.synth_mesh_signal] Computing eigenvectors using meshFourier (k=%d)...\n', k);
            end
            [U, lam] = B.Manifold.meshFourier(k);
            k = size(U, 2);  % Update k to actual computed modes (may be less due to DC filtering)
            if verbose
                fprintf('[bct.sim.synth_mesh_signal] ✓ Eigendecomposition complete (k=%d modes stored in B.Manifold)\n', k);
            end
        end
        M = B.Manifold.MassMatrix;
        d = full(diag(M));  % Mass diagonals
        lam = lam(:);       % Ensure column vector
    else
        % For graph: use eigenpairs with combinatorial Laplacian
        if isempty(k_requested)
            k = min(200, N-1);
        else
            k = min(round(k_requested), N-1);
            k = max(k, 1);
        end
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
    
    % Return based on mode
    if return_raw
        % Legacy mode: return raw data
        B_out = xrec;
    else
        % New mode: create Signal object and add to bct
        B_out = B;  % Copy input bct object
        
        % Generate label if not provided
        if isempty(user_label)
            label = generate_label(spec, 1);
        else
            label = user_label;
        end
        
        % Create Signal object
        sig = bct.signal.Signal(B_out.Manifold, xrec, label);
        
        % Add to bct object
        B_out.addSignal(sig);
        
        if verbose
            fprintf('[bct.sim.synth_mesh_signal] ✓ Added signal "%s" to bct object\n', label);
        end
    end
end

%% Helper functions

function label = generate_label(spec, idx)
    % Generate automatic label based on spec
    switch lower(spec.type)
        case 'narrowband'
            if isfield(spec, 'f0')
                label = sprintf('narrowband_f%.3g', spec.f0);
            else
                label = sprintf('narrowband_%d', idx);
            end
        case 'twoband'
            if isfield(spec, 'f1') && isfield(spec, 'f2')
                label = sprintf('twoband_f%.3g_f%.3g', spec.f1, spec.f2);
            else
                label = sprintf('twoband_%d', idx);
            end
        case 'flat'
            label = sprintf('flat_%d', idx);
        case 'powerlaw'
            if isfield(spec, 'alpha')
                label = sprintf('powerlaw_a%.2g', spec.alpha);
            else
                label = sprintf('powerlaw_%d', idx);
            end
        case 'bandpass'
            if isfield(spec, 'fmin') && isfield(spec, 'fmax')
                label = sprintf('bandpass_%.3g_%.3g', spec.fmin, spec.fmax);
            else
                label = sprintf('bandpass_%d', idx);
            end
        otherwise
            label = sprintf('signal_%d', idx);
    end
end

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
