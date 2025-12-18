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
%         1. Creates binary signal from path vertices
%         2. Projects to eigenmode domain (Lambda) via MFT
%         3. Applies spectral kernel (filter)
%         4. Reconstructs back to Manifold via IMFT
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

    % --- Get Lambda domain (dual of Manifold) ---
    lambda_domain = manifold.dual;
    
    if isempty(lambda_domain) || isempty(lambda_domain.U) || isempty(lambda_domain.lambda)
        error('bct:brush:trajectory:spectral', ...
              'Manifold must have computed eigenbasis with dual Lambda domain. ' + ...
              'Use: B.Lambda = B.Manifold.dual(''numModes'', k) or B.computeEigenbasis(k)');
    end

    % --- Compute shortest path ---
    % Suppress warning about sparse-to-full conversion in graph operations
    warnState = warning('off', 'MATLAB:table:RowsAddedExistingVars');
    [path, ~] = manifold.Graph.shortestPath(source, target, metric);
    warning(warnState);

    % --- Create binary signal on path ---
    % Initialize signal with zeros
    path_signal = zeros(manifold.N, 1);
    
    % Set path vertices to 1
    path_signal(path) = 1;

    % --- Project to spectral domain (MFT) ---
    % Forward transform: x_hat = U' * M * x
    % where U = eigenvectors, M = mass matrix
    M = manifold.MassMatrix;
    U = lambda_domain.U;
    
    % Compute spectral coefficients
    spectral_coeffs = U' * (M * path_signal);

    % Create filter on Lambda domain
    % Convert kernel_params struct to cell array for Filter constructor
    param_cell = {};
    if ~isempty(fieldnames(kernel_params))
        param_names = fieldnames(kernel_params);
        for i = 1:length(param_names)
            param_cell{end+1} = param_names{i}; %#ok<AGROW>
            param_cell{end+1} = kernel_params.(param_names{i}); %#ok<AGROW>
        end
    end
    
    filt = bct.filters.Filter(lambda_domain, kernel_name, param_cell{:});

    % --- Apply filter in spectral domain ---
    % Evaluate filter response on eigenvalues
    H = filt.evaluate();
    
    % Apply filter: multiply spectral coefficients by filter response
    filtered_coeffs = spectral_coeffs .* H(:);

    % --- Reconstruct to spatial domain (IMFT) ---
    % Inverse transform: x_rec = U * x_hat
    w = U * filtered_coeffs;

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
