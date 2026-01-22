function w = spectral(manifold, params)
%BCT.BRUSH.TRAJECTORY.SPECTRAL  Spectral-filtered trajectory brush
%
%   w = bct.brush.trajectory.spectral(manifold, params)
%
%   Required params
%   ---------------
%   params.source : source vertex index
%   params.target : target vertex index
%   params.kernel : kernel type ('gaussian', 'heat', 'bandpass', etc.)
%
%   Optional params
%   ---------------
%   params.metric : "geometry" (default) | "fem" | custom metric
%   params.kernel_params : struct with kernel-specific parameters
%                          e.g., struct('tau', 0.1) for heat kernel
%                          e.g., struct('center', 10, 'sigma', 3) for Gaussian
%
%   Note: Creates a path via shortest path, then applies spectral filtering:
%         1. Computes eigenpairs from FEM representation (cached)
%         2. Creates binary signal from path vertices
%         3. Projects to eigenmode domain using Eigenpairs.project()
%         4. Applies spectral kernel (filter)
%         5. Reconstructs back to Manifold using Eigenpairs.reconstruct()
%
%   This produces a spatially smooth trajectory that respects the
%   spectral characteristics of the manifold.

    arguments
        manifold (1,1) bct.Manifold
        params struct
    end

    % --- Validate parameters ---
    if ~isfield(params,'source') || ~isfield(params,'target')
        error('bct:brush:trajectory:spectral', ...
              'params must contain source and target');
    end
    
    if ~isfield(params,'kernel')
        error('bct:brush:trajectory:spectral', ...
              'params must contain kernel type');
    end

    source = params.source;
    target = params.target;
    kernel_name = params.kernel;
    
    % --- Get metric ---
    if isfield(params, 'metric')
        metric = params.metric;
    else
        metric = "geometry";
    end
    
    % --- Get kernel parameters ---
    if isfield(params, 'kernel_params')
        kernel_params = params.kernel_params;
    else
        kernel_params = struct();
    end

    % --- Get eigenmodes for spectral analysis ---
    
    % Determine number of modes from kernel params or use default
    if isfield(kernel_params, 'numModes')
        numModes = kernel_params.numModes;
    else
        numModes = min(100, manifold.numVertices());  % Default to 100 modes
    end
    
    % Get eigenpairs (uses caching internally)
    E = manifold.eigenmodes(numModes);
    eigenvalues = E.eigenvalues.value;

    % --- Compute shortest path ---
    % Suppress warning about sparse-to-full conversion in graph operations
    warnState = warning('off', 'MATLAB:table:RowsAddedExistingVars');
    [path, ~] = manifold.Graph().shortestPath(source, target, metric);
    warning(warnState);

    % --- Create binary signal on path ---
    Nv = manifold.numVertices();
    path_signal = zeros(Nv, 1);
    path_signal(path) = 1;

    % --- Project to spectral domain using Eigenpairs ---
    spectral_coeffs = E.project(path_signal);

    % --- Build spectral filter ---
    % Convert kernel_params struct to cell array for Filter constructor
    param_cell = {};
    if ~isempty(fieldnames(kernel_params))
        param_names = fieldnames(kernel_params);
        for i = 1:length(param_names)
            param_cell{end+1} = param_names{i}; %#ok<AGROW>
            param_cell{end+1} = kernel_params.(param_names{i}); %#ok<AGROW>
        end
    end
    
    % Create filter with eigenvalues as domain axis
    kernel_params.axis = eigenvalues;
    filt = bct.filters.Filter(eigenvalues, kernel_name, param_cell{:});

    % --- Apply filter in spectral domain ---
    % Evaluate filter response on eigenvalues
    H = filt.evaluate();
    
    % Apply filter: multiply spectral coefficients by filter response
    filtered_coeffs = spectral_coeffs .* H(:);

    % --- Reconstruct to spatial domain using Eigenpairs ---
    w = E.reconstruct(filtered_coeffs);

    % --- Ensure non-negative and normalize ---
    % Spectral filtering can produce negative values; take absolute value
    w = abs(w);
    
    % Normalize to [0, 1] range
    if max(w) > 0
        w = w / max(w);
    end

    % --- Return as sparse column vector ---
    % Remove very small values to keep sparse
    w(w < 1e-6) = 0;
    w = sparse(w);

end
