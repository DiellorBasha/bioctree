function mft = mft(eigenvectors, Mass, options)
%MFT Construct forward manifold Fourier transform operator matrix
%
% Syntax:
%   mft = bct.manifold.operator.mft(eigenvectors, Mass)
%   mft = bct.manifold.operator.mft(eigenvectors, Mass, Name=Value)
%
% Inputs:
%   eigenvectors - [N×k] numeric matrix of eigenmodes
%                  Columns are Mass-orthonormal eigenvectors from
%                  bct.manifold.eigenmodes()
%   Mass         - [N×N] numeric sparse matrix
%                  Mass matrix from bct.manifold.operator.mass()
%                  Defines the area-weighted inner product (units: m²)
%
% Name-Value Arguments:
%   Annotate - Wrap output as quantity struct (default: false)
%   Strict   - Enforce input validation (default: true)
%
% Outputs:
%   mft - Forward transform operator matrix [k×N]
%         If Annotate=false: numeric matrix
%         If Annotate=true: quantity struct with .value, .unit, .dim, .meta
%
% Description:
%   Constructs the forward manifold Fourier transform operator:
%
%     MFT = eigenvectors' * Mass
%
%   This operator projects vertex-domain signals onto the spectral basis:
%
%     spectrum = mft * signal
%
%   The operator has SI units of meters (Lexp = +1) because:
%   - eigenvectors have units 1/m (Mass-orthonormal)
%   - Mass has units m² (area-weighted inner product)
%   - Product: (1/m) * (m²) = m
%
% Dimensional Analysis:
%   Input signal:    [N×1] scalar field (dimensionless or with field units)
%   Output spectrum: [k×1] spectral coefficients (inherits field units * m)
%   Operator units:  m (length dimension, Lexp = +1)
%
% Examples:
%   % Compute eigenmodes and mass matrix
%   [eigvals, eigvecs] = bct.manifold.eigenmodes(M, 100);
%   [~, Mass] = bct.manifold.operator.mass(M);
%
%   % Construct forward transform operator
%   mft = bct.manifold.operator.mft(eigvecs, Mass);
%   % size(mft) = [100, N]
%
%   % Apply to signal
%   signal = randn(M.numVertices(), 1);
%   spectrum = mft * signal;  % [100×1]
%
%   % With annotation
%   mft = bct.manifold.operator.mft(eigvecs, Mass, 'Annotate', true);
%   % mft.unit = "m", mft.dim.Lexp = +1
%
% See also: bct.manifold.operator.imft, bct.manifold.eigenmodes,
%           bct.manifold.operator.mass, bct.manifold.metric.quantity

arguments
    eigenvectors {mustBeNumeric}
    Mass {mustBeNumeric}
    options.Annotate (1,1) logical = false
    options.Strict (1,1) logical = true
end

% Input validation
if options.Strict
    % Check numeric and 2D
    if ~ismatrix(eigenvectors)
        error('bct:manifold:operator:mft:InvalidEigenvectors', ...
            'eigenvectors must be a 2D matrix');
    end
    
    if ~ismatrix(Mass)
        error('bct:manifold:operator:mft:InvalidMass', ...
            'Mass must be a 2D matrix');
    end
    
    % Mass must be square
    if size(Mass, 1) ~= size(Mass, 2)
        error('bct:manifold:operator:mft:NonSquareMass', ...
            'Mass matrix must be square [N×N], got [%d×%d]', ...
            size(Mass, 1), size(Mass, 2));
    end
    
    % Compatible sizes
    N_eig = size(eigenvectors, 1);
    N_mass = size(Mass, 1);
    if N_eig ~= N_mass
        error('bct:manifold:operator:mft:SizeMismatch', ...
            'eigenvectors has %d rows but Mass is [%d×%d]', ...
            N_eig, N_mass, N_mass);
    end
end

% Compute forward transform operator: mft = eigenvectors' * Mass
% Output size: [k × N] where k = number of modes, N = number of vertices
mft_matrix = eigenvectors' * Mass;

% Return with or without annotation
if options.Annotate
    % Wrap as quantity struct with operator metric spec
    mft = bct.manifold.metric.quantity( ...
        mft_matrix, ...
        "m", ...          % unit
        1, ...            % Lexp = +1
        struct( ...
            'operator', "mft", ...
            'normalization', "mass-orthonormal", ...
            'innerProduct', "Mass" ...
        ) ...
    );
else
    mft = mft_matrix;
end

end
