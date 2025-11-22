function [B_out, xrec, a] = heat(B, tau, varargin)
%HEAT Synthesize mesh signal using heat diffusion kernel filter
%
%   B_out = bct.sim.heat(B, tau) synthesizes a random graph signal filtered
%       by a heat diffusion kernel and returns a bct object with the signal
%       added as a bct.signal.Signal object.
%
%   [B_out, xrec, a] = bct.sim.heat(B, tau) also returns:
%       xrec - N×1 synthesized vertex signal
%       a    - k×1 spectral coefficients used
%
%   Inputs:
%       B   - bct object with mesh-type Manifold
%       tau - Heat diffusion time parameter (controls smoothness)
%             Larger tau → smoother signal (more low-frequency content)
%             Smaller tau → rougher signal (more high-frequency content)
%
%   Parameters:
%       'k'          - Number of eigenmodes to use (default: uses cached or 200)
%       'band'       - [min, max] wavelength band in mesh units (optional)
%                      Example: [10, 50] for 10-50 mm wavelengths
%       'noise_power'- Total power of input noise before filtering (default: 1.0)
%       'normalize'  - Normalize output to unit RMS (default: true)
%       'label'      - Label for the Signal object (default: 'heat_tau_X.XX')
%       'return_raw' - If true, returns raw data [N×1] instead of bct object
%       'verbose'    - Print computation progress (default: true)
%
%   Returns:
%       B_out - bct object with Signal added (if return_raw=false)
%       xrec  - N×1 single precision synthesized vertex signal
%       a     - k×1 spectral coefficients after filtering
%
%   Heat Kernel Filter:
%       The heat kernel implements diffusion on the manifold:
%           g(λ) = exp(-τ * λ / λ_max)
%       where:
%           - λ are the Laplacian eigenvalues (spatial frequencies)
%           - λ_max is the maximum eigenvalue (mesh resolution)
%           - τ controls the diffusion time (smoothness)
%
%       Small τ (e.g., 0.01-0.1): Preserves high frequencies, rough signals
%       Medium τ (e.g., 0.5-2.0): Moderate smoothing
%       Large τ (e.g., 5-20): Strong smoothing, only low frequencies
%
%   Workflow:
%       1. Generate white noise in spectral domain: a_noise ~ N(0, 1)
%       2. Apply heat kernel filter: a = g(λ) .* a_noise
%       3. Reconstruct signal: x = U * a (synthesize from filtered spectrum)
%       4. Optional: normalize to unit RMS
%
%   Examples:
%       % Basic usage with smooth signal (large tau)
%       B = bct.io.import.mesh('test-data/freesurfer/fsaverage/surf/lh.pial');
%       B.Manifold.meshFourier(300);  % Precompute eigenbasis
%       B = bct.sim.heat(B, 2.0, 'label', 'smooth_heat');
%
%       % Rough signal with small tau
%       B = bct.sim.heat(B, 0.05, 'label', 'rough_heat');
%
%       % Band-limited heat signal (spatial frequency band)
%       B = bct.sim.heat(B, 1.0, 'band', [20, 60], 'label', 'bandlimited_heat');
%
%       % Multiple signals with different smoothness
%       for tau_val = [0.1, 0.5, 1.0, 2.0, 5.0]
%           B = bct.sim.heat(B, tau_val);
%       end
%
%       % Legacy mode (returns raw data)
%       x = bct.sim.heat(B, 1.0, 'return_raw', true);
%
%   See also: bct.filters.Filter, bct.sim.synth_mesh_signal, bct.signal.transform.filter

    % Validate inputs
    if ~isa(B, 'bct.bct')
        error('bct:sim:heat:InvalidInput', 'B must be a bct object');
    end
    
    if B.Manifold.Type ~= "mesh"
        error('bct:sim:heat:InvalidManifold', 'Manifold must be mesh type');
    end
    
    if ~isscalar(tau) || tau <= 0
        error('bct:sim:heat:InvalidTau', 'tau must be a positive scalar');
    end
    
    % Parse inputs
    p = inputParser;
    p.addParameter('k', [], @(x)isempty(x)||(isscalar(x)&&x>0));
    p.addParameter('band', [], @(x)isempty(x)||(isnumeric(x)&&numel(x)==2));
    p.addParameter('noise_power', 1.0, @(x)isscalar(x)&&x>0);
    p.addParameter('normalize', true, @islogical);
    p.addParameter('label', '', @(x)ischar(x)||isstring(x));
    p.addParameter('return_raw', false, @islogical);
    p.addParameter('verbose', true, @islogical);
    p.parse(varargin{:});
    
    k_requested = p.Results.k;
    band = p.Results.band;
    noise_power = p.Results.noise_power;
    do_normalize = p.Results.normalize;
    user_label = string(p.Results.label);
    return_raw = p.Results.return_raw;
    verbose = p.Results.verbose;
    
    N = B.Manifold.N;
    
    %% Get or compute eigenbasis
    available_modes = B.Manifold.NumModes;
    
    % Determine how many modes to use
    if isempty(k_requested)
        if available_modes > 0
            k = available_modes;
            if verbose
                fprintf('[bct.sim.heat] Using all cached eigenvectors (k=%d modes)\n', k);
            end
        else
            k = min(200, N-1);
            if verbose
                fprintf('[bct.sim.heat] No cached modes found, computing default k=%d modes\n', k);
            end
        end
    else
        k = min(round(k_requested), N-1);
        k = max(k, 1);
    end
    
    % Get or compute eigenvectors
    if available_modes > 0 && available_modes >= k
        if verbose && ~isempty(k_requested)
            fprintf('[bct.sim.heat] Using cached eigenvectors (k=%d/%d modes)\n', ...
                k, available_modes);
        end
        U = B.Manifold.Eigenvectors(:, 1:k);
        lam = B.Manifold.Eigenvalues(1:k);
    else
        if verbose
            fprintf('[bct.sim.heat] Computing eigenvectors using meshFourier (k=%d)...\n', k);
        end
        [U, lam] = B.Manifold.meshFourier(k);
        k = size(U, 2);
        if verbose
            fprintf('[bct.sim.heat] ✓ Eigendecomposition complete (k=%d modes)\n', k);
        end
    end
    
    M = B.Manifold.MassMatrix;
    d = full(diag(M));
    lam = lam(:);
    
    %% Create heat kernel filter
    if verbose
        fprintf('[bct.sim.heat] Designing heat kernel filter (tau=%.4f)...\n', tau);
    end
    
    filt = bct.filters.Filter(B.Manifold);
    
    % Set band if specified
    if ~isempty(band)
        if verbose
            fprintf('[bct.sim.heat] Setting wavelength band: [%.1f, %.1f] %s\n', ...
                band(1), band(2), B.Manifold.Units);
        end
        filt.setBand(band, bct.resolution.Quantity.wavelength);
    end
    
    % Design heat kernel
    filt.design('heat', 'tau', tau);
    
    % Get filter response for all computed eigenvalues
    g_lambda = filt.getResponse(lam);
    g_lambda = g_lambda(:);
    
    if verbose
        fprintf('[bct.sim.heat] ✓ Filter designed\n');
        fprintf('[bct.sim.heat]   Response range: [%.4f, %.4f]\n', ...
            min(g_lambda), max(g_lambda));
        if ~isempty(band)
            mode_indices = filt.getModeIndices();
            fprintf('[bct.sim.heat]   Modes in band: %d\n', length(mode_indices));
        end
    end
    
    %% Generate noise and apply filter
    if verbose
        fprintf('[bct.sim.heat] Generating noise and applying filter...\n');
    end
    
    % Generate white noise in spectral domain
    a_noise = randn(k, 1) * sqrt(noise_power / k);
    
    % Apply heat kernel filter
    a = g_lambda .* a_noise;
    
    % Reconstruct signal: x = M^(1/2) * U * a
    S = spdiags(sqrt(d), 0, numel(d), numel(d));
    xrec = S * (U * a);
    
    %% Normalize (optional)
    if do_normalize
        Ex = (xrec' * (spdiags(d, 0, length(d), length(d)) * xrec));
        if Ex > 0
            xrec = xrec / sqrt(Ex);
        end
        if verbose
            fprintf('[bct.sim.heat] ✓ Normalized to unit RMS\n');
        end
    end
    
    % Convert to single precision
    xrec = single(xrec);
    
    if verbose
        fprintf('[bct.sim.heat] ✓ Signal synthesized (N=%d vertices)\n', N);
    end
    
    %% Return based on mode
    if return_raw
        % Legacy mode: return raw data
        B_out = xrec;
    else
        % Create Signal object and add to bct
        B_out = B;
        
        % Generate label if not provided
        if isempty(user_label)
            if ~isempty(band)
                label = sprintf('heat_tau%.2f_band%.0f-%.0f', tau, band(1), band(2));
            else
                label = sprintf('heat_tau%.2f', tau);
            end
        else
            label = user_label;
        end
        
        % Create Signal object
        sig = bct.Signal(B_out.Manifold, xrec, label);
        
        % Add to bct object
        B_out.addSignal(sig);
        
        if verbose
            fprintf('[bct.sim.heat] ✓ Added signal "%s" to bct object\n', label);
        end
    end
end
