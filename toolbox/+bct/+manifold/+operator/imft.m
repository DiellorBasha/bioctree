function imft = imft(meshInput, options)
%IMFT Construct inverse manifold Fourier transform operator matrix
%
% Syntax:
%   imft = bct.manifold.operator.imft(M)
%   imft = bct.manifold.operator.imft(M, Name=Value)
%   imft = bct.manifold.operator.imft(eigenvectors)
%   imft = bct.manifold.operator.imft(eigenvectors, Name=Value)
%
% Inputs:
%   M            - bct.Manifold object (uses cached or computes eigenmodes)
%   OR
%   eigenvectors - [N×k] numeric matrix of eigenmodes
%                  Columns are Mass-orthonormal eigenvectors from
%                  bct.manifold.eigenmodes()
%
% Name-Value Arguments:
%   Annotate - Wrap output as quantity struct (default: false)
%   Strict   - Enforce input validation (default: true)
%
% Outputs:
%   imft - Inverse transform operator matrix [N×k]
%          If Annotate=false: numeric matrix
%          If Annotate=true: quantity struct with .value, .unit, .dim, .meta
%
% Description:
%   Constructs the inverse manifold Fourier transform operator:
%
%     IMFT = eigenvectors
%
%   This operator reconstructs vertex-domain signals from spectral coefficients:
%
%     signal = imft * spectrum
%
%   The operator has SI units of 1/m (Lexp = -1) because eigenvectors
%   are Mass-orthonormal with units 1/m.
%
% Dimensional Analysis:
%   Input spectrum:  [k×1] spectral coefficients (with field units * m)
%   Output signal:   [N×1] reconstructed field (inherits field units)
%   Operator units:  1/m (inverse length dimension, Lexp = -1)
%
% Examples:
%   % Direct from Manifold (uses cached eigenmodes if available)
%   imft = bct.manifold.operator.imft(M);
%   spectrum = randn(size(imft, 2), 1);
%   signal = imft * spectrum;
%
%   % Explicit eigenvectors
%   [eigvals, eigvecs] = bct.manifold.eigenmodes(M, 100);
%   imft = bct.manifold.operator.imft(eigvecs);
%   % size(imft) = [N, 100]
%
%   % With annotation
%   imft = bct.manifold.operator.imft(M, 'Annotate', true);
%   % imft.unit = "1/m", imft.dim.Lexp = -1
%
%   % Round-trip example
%   mft = bct.manifold.operator.mft(M);
%   imft = bct.manifold.operator.imft(M);
%   original = randn(M.numVertices(), 1);
%   spectrum = mft * original;
%   reconstructed = imft * spectrum;
%   % reconstructed ≈ original (up to truncation at k modes)
%
% See also: bct.manifold.operator.mft, bct.manifold.eigenmodes,
%           bct.manifold.operator.mass, bct.manifold.metric.quantity

% Parse inputs
if isa(meshInput, 'bct.Manifold')
    % Case: imft(M, Name=Value...)
    M = meshInput;
    
    % Parse name-value pairs from varargin
    p = inputParser;
    p.addParameter('Annotate', false, @islogical);
    p.addParameter('Strict', true, @islogical);
    p.parse(varargin{:});
    
    options.Annotate = p.Results.Annotate;
    options.Strict = p.Results.Strict;
    
    % Get eigenmodes (cached or compute with default k=50)
    Eigen = M.eigenmodes();
    eigenvectors = Eigen.vectors;
    
elseif isnumeric(meshInput)
    % Case: imft(eigenvectors, Name=Value...)
    eigenvectors = meshInput;
    
    % Parse name-value pairs from varargin
    p = inputParser;
    p.addParameter('Annotate', false, @islogical);
    p.addParameter('Strict', true, @islogical);
    p.parse(varargin{:});
    
    options.Annotate = p.Results.Annotate;
    options.Strict = p.Results.Strict;
    
    % Input validation
    if options.Strict
        % Check numeric and 2D
        if ~ismatrix(eigenvectors)
            error('bct:manifold:operator:imft:InvalidEigenvectors', ...
                'eigenvectors must be a 2D matrix');
        end
        
        % Check non-empty
        [N, k] = size(eigenvectors);
        if N < 1 || k < 1
            error('bct:manifold:operator:imft:EmptyEigenvectors', ...
                'eigenvectors must be non-empty, got [%d×%d]', N, k);
        end
    end
    
else
    error('bct:manifold:operator:imft:InvalidInput', ...
        'First argument must be bct.Manifold or numeric eigenvectors matrix.');
end

% Compute inverse transform operator: imft = eigenvectors
% Output size: [N × k] where N = number of vertices, k = number of modes
imft_matrix = eigenvectors;

% Return with or without annotation
if options.Annotate
    % Wrap as quantity struct with operator metric spec
    imft = bct.manifold.metric.quantity( ...
        imft_matrix, ...
        "1/m", ...        % unit
        -1, ...           % Lexp = -1
        struct( ...
            'operator', "imft", ...
            'normalization', "mass-orthonormal", ...
            'innerProduct', "Mass" ...
        ) ...
    );
else
    imft = imft_matrix;
end

end
