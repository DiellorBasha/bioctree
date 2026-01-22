function w = heat(manifold, time, params)
%BCT.BRUSH.TIME.HEAT  Spatiotemporal heat diffusion brush along trajectory
%
%   w = bct.brush.time.heat(manifold, time, params)
%
%   Creates a spatiotemporal brush [N×T] that shows heat diffusion along
%   a geodesic path over time. The brush:
%   1. Gets FEM representation and computes eigenpairs (cached)
%   2. Computes shortest path between source and target
%   3. Creates initial spatial signal on the path
%   4. Projects to eigenmode domain using Eigenpairs.project()
%   5. Applies time-varying heat kernel with increasing diffusion
%   6. Reconstructs to spatial domain at each time step using Eigenpairs.reconstruct()
%
%   Required params
%   ---------------
%   params.source : source vertex index
%   params.target : target vertex index
%   params.tau_range : [tau_start, tau_end] - heat diffusion range
%                     Default: [0.01, 0.5]
%
%   Optional params
%   ---------------
%   params.metric : "geometry" (default) | "fem" | custom metric
%   params.tau_profile : 'linear' (default) | 'exponential' | 'sigmoid'
%                       Controls how tau evolves over time
%
%   Output
%   ------
%   w : [N×T] sparse matrix
%       Spatiotemporal weights where:
%       - N = number of vertices on manifold
%       - T = number of time steps
%       - w(n,t) = heat-diffused weight at vertex n, time t
%
%   Notes:
%   ------
%   - Diffusion increases over time (tau grows from tau_start to tau_end)
%   - Earlier time steps show more localized activity along path
%   - Later time steps show more diffused activity
%   - The heat kernel is: H(λ) = exp(-τ·λ/λ_max)
%
%   Example:
%   --------
%   % Setup
%   M = bct.Manifold(V, F);
%   time_axis = bct.Time(0:0.01:1, 100);  % 1 second at 100 Hz
%
%   % Create heat brush
%   params.source = 100;
%   params.target = 500;
%   params.tau_range = [0.02, 0.4];
%   params.tau_profile = 'exponential';
%   
%   w = bct.brush.time.heat(M, time_axis, params);
%   
%   % Visualize at specific time
%   figure; M.plot('data', full(w(:, 50)));

    arguments
        manifold (1,1) bct.Manifold
        time (1,1) bct.Time
        params struct
    end

    % --- Validate parameters ---
    if ~isfield(params,'source') || ~isfield(params,'target')
        error('bct:brush:time:heat', ...
              'params must contain source and target');
    end

    source = params.source;
    target = params.target;
    
    % --- Get tau range ---
    if isfield(params, 'tau_range')
        tau_range = params.tau_range;
        if numel(tau_range) ~= 2 || tau_range(1) >= tau_range(2)
            error('bct:brush:time:heat', ...
                  'tau_range must be [tau_start, tau_end] with tau_start < tau_end');
        end
    else
        tau_range = [0.01, 0.5];
    end
    
    % --- Get tau profile ---
    if isfield(params, 'tau_profile')
        tau_profile = params.tau_profile;
    else
        tau_profile = 'linear';
    end
    
    % --- Get metric ---
    if isfield(params, 'metric')
        metric = params.metric;
    else
        metric = "geometry";
    end

    % --- Get eigenmodes for spectral analysis ---
    
    % Determine number of modes (default to 100)
    numModes = min(100, manifold.numVertices());
    
    % Get eigenpairs (uses caching internally)
    E = manifold.eigenmodes(numModes);
    eigenvalues = E.eigenvalues.value;
    lambda_max = max(eigenvalues);
    
    if lambda_max == 0
        error('bct:brush:time:heat', 'Maximum eigenvalue is zero');
    end

    % --- Compute shortest path ---
    % Suppress warning about sparse-to-full conversion
    warnState = warning('off', 'MATLAB:table:RowsAddedExistingVars');
    [path, ~] = manifold.Graph().shortestPath(source, target, metric);
    warning(warnState);

    % --- Create initial spatial signal on path ---
    Nv = manifold.numVertices();
    path_signal = zeros(Nv, 1);
    path_signal(path) = 1;

    % --- Project to spectral domain using Eigenpairs ---
    spectral_coeffs = E.project(path_signal);

    % --- Generate tau values over time ---
    T = time.N;
    tau_start = tau_range(1);
    tau_end = tau_range(2);
    
    switch lower(tau_profile)
        case 'linear'
            tau_vec = linspace(tau_start, tau_end, T);
        case 'exponential'
            % Exponential growth from tau_start to tau_end
            t_norm = linspace(0, 1, T);
            tau_vec = tau_start * exp(t_norm * log(tau_end / tau_start));
        case 'sigmoid'
            % Sigmoid (slow-fast-slow) profile
            t_norm = linspace(-6, 6, T);
            sigmoid = 1 ./ (1 + exp(-t_norm));
            tau_vec = tau_start + (tau_end - tau_start) * sigmoid;
        otherwise
            error('bct:brush:time:heat', ...
                  'Unknown tau_profile: %s. Use ''linear'', ''exponential'', or ''sigmoid''', ...
                  tau_profile);
    end

    % --- Initialize output ---
    Nv = manifold.numVertices();
    w = zeros(Nv, T);

    % --- Apply heat kernel at each time step ---
    for t = 1:T
        tau_t = tau_vec(t);
        
        % Heat kernel: H(λ) = exp(-τ·λ/λ_max)
        H = exp(-tau_t * eigenvalues / lambda_max);
        
        % Apply filter in spectral domain
        filtered_coeffs = spectral_coeffs .* H(:);
        
        % Reconstruct to spatial domain using Eigenpairs
        w_t = E.reconstruct(filtered_coeffs);
        
        % Store (absolute value and normalize)
        w_t = abs(w_t);
        if max(w_t) > 0
            w_t = w_t / max(w_t);
        end
        
        w(:, t) = w_t;
    end

    % --- Convert to sparse and threshold ---
    w(w < 1e-6) = 0;
    w = sparse(w);

end
