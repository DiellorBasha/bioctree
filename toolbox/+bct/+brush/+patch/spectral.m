function w = spectral(manifold, params)
    % SPECTRAL Create a spectral brush using FEM and eigenmode filtering
    %
    % Syntax:
    %   w = bct.brush.patch.spectral(manifold, params)
    %
    % Inputs:
    %   manifold - bct.Manifold object
    %   params   - Structure with fields:
    %              .source      - Seed vertex index (required)
    %              .kernel      - Kernel type from bct.kernel registry (default: 'heat')
    %              .sigma       - Kernel width parameter (default: 10)
    %              .bandwidth   - Frequency bandwidth parameter (default: [])
    %              Additional kernel-specific parameters can be passed
    %
    % Outputs:
    %   w - [N×1] Spectral brush signal on vertices
    %
    % Description:
    %   Creates a brush using spectral filtering:
    %   1. Gets FEM representation and computes eigenpairs (cached)
    %   2. Creates FEM-correct Dirac delta at seed vertex: delta = M \ ei
    %   3. Projects to spectral domain using Eigenpairs.project()
    %   4. Applies spectral kernel (heat, gaussian, etc.)
    %   5. Reconstructs to spatial domain using Eigenpairs.reconstruct()
    %
    %   This approach respects the manifold geometry through the eigenmodes
    %   and provides smooth, geodesic-aware brushes. The FEM eigenpairs are
    %   computed on-demand and cached for subsequent calls.
    %
    % Example:
    %   % Heat kernel brush
    %   params.source = 1000;
    %   params.kernel = 'heat';
    %   params.sigma = 10;
    %   w = bct.brush.patch.spectral(M, params);
    %
    %   % Gaussian kernel brush
    %   params.source = 1000;
    %   params.kernel = 'gaussian';
    %   params.sigma = 15;
    %   params.bandwidth = 50;  % Limit to first 50 modes
    %   w = bct.brush.patch.spectral(M, params);
    %
    %   % Custom kernel from registry
    %   params.source = 500;
    %   params.kernel = 'lowpass';
    %   params.cutoff = 20;
    %   w = bct.brush.patch.spectral(M, params);
    
    arguments
        manifold (1,1) bct.Manifold
        params struct
    end
    
    % Validate required parameters
    if ~isfield(params, 'source')
        error('bct:brush:spectral:MissingSource', ...
            'params.source (seed vertex) is required');
    end
    
    % Set default parameters
    if ~isfield(params, 'kernel')
        params.kernel = 'heat';
    end
    
    if ~isfield(params, 'sigma')
        params.sigma = 10;
    end
    
    % Get mesh properties
    Nv = size(manifold.Vertices, 1);
    i = params.source;
    
    % Validate seed vertex
    if i < 1 || i > Nv
        error('bct:brush:spectral:InvalidSource', ...
            'Source vertex %d out of range [1, %d]', i, Nv);
    end
    
    % Step 1: Get FEM representation and compute eigenpairs
    fem = manifold.FEM();
    
    % Determine number of modes
    if isfield(params, 'bandwidth') && ~isempty(params.bandwidth)
        numModes = params.bandwidth;
    else
        numModes = min(100, Nv);  % Default to 100 modes or mesh size
    end
    
    % Get eigenpairs (uses caching internally)
    E = fem.eigenpairs(numModes);
    eigenvalues = E.Values;
    
    % Step 2: Create FEM-correct Dirac delta at seed vertex
    ei = zeros(Nv, 1);
    ei(i) = 1;
    delta_i = fem.Mass \ ei;  % Correct FEM delta
    
    % Step 3: Project to spectral domain using Eigenpairs
    spectral_coeffs = E.project(delta_i);
    
    % Step 4: Build spectral kernel
    % Map sigma to appropriate scale for eigenvalues
    switch lower(params.kernel)
        case 'heat'
            % Heat kernel: exp(-lambda * t)
            % Map sigma to time parameter
            t = params.sigma^2;
            kernel_response = exp(-eigenvalues * t);
            
        case 'gaussian'
            % Gaussian in spectral domain
            % Map sigma to spectral bandwidth
            spectral_sigma = 1 / params.sigma;
            kernel_response = exp(-0.5 * (eigenvalues / spectral_sigma).^2);
            
        case 'lowpass'
            % Low-pass filter
            if isfield(params, 'cutoff')
                cutoff = params.cutoff;
            else
                cutoff = params.sigma;
            end
            kernel_response = double(eigenvalues <= cutoff);
            
        case 'bandpass'
            % Band-pass filter
            if isfield(params, 'low') && isfield(params, 'high')
                low = params.low;
                high = params.high;
            else
                % Default band around sigma
                low = max(1, params.sigma - 5);
                high = params.sigma + 5;
            end
            kernel_response = double(eigenvalues >= low & eigenvalues <= high);
            
        otherwise
            % Try to get kernel from registry
            try
                % Get kernel constructor from registry
                kernel_fn = bct.kernel.registry(params.kernel);
                
                % Build kernel parameters (eigenvalues as domain axis)
                kernel_params = params;
                kernel_params.axis = eigenvalues;
                
                kernel_obj = kernel_fn(kernel_params);
                kernel_response = kernel_obj.response;
                
            catch ME
                error('bct:brush:spectral:UnknownKernel', ...
                    'Unknown kernel type: %s\n%s', params.kernel, ME.message);
            end
    end
    
    % Step 5: Apply kernel in spectral domain
    filtered_coeffs = spectral_coeffs .* kernel_response;
    
    % Step 6: Reconstruct to spatial domain using Eigenpairs
    w = E.reconstruct(filtered_coeffs);
    
    % Normalize to [0, 1]
    w = w - min(w);
    if max(w) > 0
        w = w / max(w);
    end
end
