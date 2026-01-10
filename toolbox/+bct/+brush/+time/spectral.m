function w = spectral(manifold, time, params)
%BCT.BRUSH.TIME.SPECTRAL  Spatiotemporal spectral patch brush
%
%   w = bct.brush.time.spectral(manifold, time, params)
%
%   Creates a spatiotemporal brush [N×T] by generating a spectral patch
%   at each time step. The patch parameters can vary over time, creating
%   dynamic spatial patterns.
%
%   Required params
%   ---------------
%   params.source : source vertex index or function handle
%                   - Scalar: fixed source for all time steps
%                   - Function: source = f(t, time.N) returns vertex index
%                   - Array: [T×1] explicit source per time step
%
%   Optional params
%   ---------------
%   params.kernel : kernel type ('heat', 'gaussian', etc.) - default: 'heat'
%   params.kernel_params : struct with kernel-specific parameters
%   params.sigma : sigma parameter (can be scalar, function, or array)
%   params.tau : tau parameter for heat kernel (can be scalar, function, or array)
%   params.bandwidth : eigenmode bandwidth limit
%
%   Parameter Evolution:
%   --------------------
%   Parameters can be:
%   - Scalar: same value for all time steps
%   - Function: param_value = f(t, T) where t is time index, T is total
%   - Array: [T×1] explicit values per time step
%
%   Output
%   ------
%   w : [N×T] sparse matrix
%       Spatiotemporal weights where:
%       - N = number of vertices on manifold
%       - T = number of time steps
%       - w(:,t) = spectral patch at time t
%
%   Example 1: Fixed source with varying tau
%   -----------------------------------------
%   params.source = 100;
%   params.kernel = 'heat';
%   params.tau = @(t, T) 0.01 + 0.4*(t/T);  % Increase over time
%   
%   w = bct.brush.time.spectral(B.Manifold, B.Time, params);
%
%   Example 2: Moving source along path
%   ------------------------------------
%   [path, ~] = B.Manifold.Graph.shortestPath(100, 500);
%   params.source = @(t, T) path(min(round(t/T * length(path)), length(path)));
%   params.kernel = 'gaussian';
%   params.sigma = 15;
%   
%   w = bct.brush.time.spectral(B.Manifold, B.Time, params);
%
%   Example 3: Explicit source array
%   ---------------------------------
%   params.source = [100, 120, 150, 180, 200, ...];  % One per time step
%   params.kernel = 'heat';
%   params.tau = linspace(0.05, 0.3, B.Time.N);
%   
%   w = bct.brush.time.spectral(B.Manifold, B.Time, params);

    arguments
        manifold (1,1) bct.Manifold
        time (1,1) bct.Time
        params struct
    end

    % --- Validate parameters ---
    if ~isfield(params, 'source')
        error('bct:brush:time:spectral', ...
              'params.source is required');
    end

    % --- Set defaults ---
    if ~isfield(params, 'kernel')
        params.kernel = 'heat';
    end
    
    if ~isfield(params, 'kernel_params')
        params.kernel_params = struct();
    end

    % --- Get dimensions ---
    N = manifold.N;
    T = time.N;

    % --- Parse source parameter ---
    source_type = get_param_type(params.source, T);
    
    % --- Parse other parameters ---
    % Extract commonly used parameters that might vary
    param_names = fieldnames(params);
    varying_params = struct();
    
    for i = 1:length(param_names)
        pname = param_names{i};
        if ~ismember(pname, {'source', 'kernel', 'kernel_params'})
            varying_params.(pname) = params.(pname);
        end
    end

    % --- Initialize output ---
    w = zeros(N, T);

    % --- Generate patch at each time step ---
    for t = 1:T
        % Build parameters for this time step
        patch_params = struct();
        patch_params.kernel = params.kernel;
        
        % Get source for this time step
        switch source_type
            case 'scalar'
                patch_params.source = params.source;
            case 'function'
                patch_params.source = params.source(t, T);
            case 'array'
                % Only index if array length matches T
                if length(params.source) == T
                    patch_params.source = params.source(t);
                else
                    error('bct:brush:time:spectral', ...
                        'Source array length (%d) does not match time steps (%d)', ...
                        length(params.source), T);
                end
        end
        
        % Get other parameters for this time step
        vp_names = fieldnames(varying_params);
        for i = 1:length(vp_names)
            pname = vp_names{i};
            pval = varying_params.(pname);
            ptype = get_param_type(pval, T);
            
            switch ptype
                case 'scalar'
                    patch_params.(pname) = pval;
                case 'function'
                    patch_params.(pname) = pval(t, T);
                case 'array'
                    % Only index if array length matches T
                    if length(pval) == T
                        patch_params.(pname) = pval(t);
                    else
                        % Pass through as-is (e.g., tau_range, bandwidth)
                        patch_params.(pname) = pval;
                    end
                case 'struct'
                    % Pass through structs (like kernel_params)
                    patch_params.(pname) = pval;
            end
        end
        
        % Merge with kernel_params if it exists
        if isfield(params, 'kernel_params')
            kp_names = fieldnames(params.kernel_params);
            for i = 1:length(kp_names)
                pname = kp_names{i};
                if ~isfield(patch_params, pname)
                    patch_params.(pname) = params.kernel_params.(pname);
                end
            end
        end
        
        % Generate spectral patch for this time step
        w_t = bct.brush.patch.spectral(manifold, patch_params);
        
        % Store in output array
        w(:, t) = w_t;
    end

    % --- Convert to sparse and threshold ---
    w(w < 1e-6) = 0;
    w = sparse(w);

end

%% Helper function
function ptype = get_param_type(param, T)
    % Determine parameter type: scalar, function, array, or struct
    % Only treat as time-varying array if length matches T
    if isstruct(param)
        ptype = 'struct';
    elseif isa(param, 'function_handle')
        ptype = 'function';
    elseif isscalar(param)
        ptype = 'scalar';
    elseif isvector(param) && length(param) == T
        ptype = 'array';  % Time-varying array
    else
        % Treat as scalar/config parameter (pass through)
        ptype = 'array';  % But will be passed through as-is
    end
end
