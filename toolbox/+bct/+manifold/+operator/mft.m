function [header, mft] = mft(meshInput, varargin)
%MFT Construct forward manifold Fourier transform operator matrix
%
% Syntax:
%   [header, mft] = bct.manifold.operator.mft(M)
%   [header, mft] = bct.manifold.operator.mft(M, Name=Value)
%   [header, mft] = bct.manifold.operator.mft(eigenvectors, Mass)
%   [header, mft] = bct.manifold.operator.mft(eigenvectors, Mass, Name=Value)
%
% Inputs:
%   M            - bct.Manifold object (uses cached or computes eigenmodes)
%   OR
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
%   k        - Number of eigenmodes (required if using Manifold input)
%
% Outputs:
%   header - Struct with computation metadata
%   mft    - Forward transform operator matrix [k×N]
%            If Annotate=false: numeric matrix
%            If Annotate=true: quantity struct with .value, .unit, .dim, .meta
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
%   % Direct from Manifold (uses cached eigenmodes if available)
%   mft = bct.manifold.operator.mft(M);
%   signal = randn(M.numVertices(), 1);
%   spectrum = mft * signal;
%
%   % Explicit eigenvectors and mass matrix
%   [eigvals, eigvecs] = bct.manifold.eigenmodes(M, 100);
%   [~, Mass] = bct.manifold.operator.mass(M);
%   mft = bct.manifold.operator.mft(eigvecs, Mass);
%   % size(mft) = [100, N]
%
%   % With annotation
%   mft = bct.manifold.operator.mft(M, 'Annotate', true);
%   % mft.unit = "m", mft.dim.Lexp = +1
%
% See also: bct.manifold.operator.imft, bct.manifold.eigenmodes,
%           bct.manifold.operator.mass, bct.manifold.metric.quantity

% Parse inputs
if isa(meshInput, 'bct.Manifold')
    % Case: mft(M, Name=Value...)
    M = meshInput;
    Mass = [];
    
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
    
    % Get mass matrix (cached or compute)
    if M.hasCached('operators')
        ops = M.operators();
        if isfield(ops, 'mass')
            Mass = ops.mass;
        else
            [~, Mass] = bct.manifold.operator.mass(M);
        end
    else
        [~, Mass] = bct.manifold.operator.mass(M);
    end
    
elseif isnumeric(meshInput)
    % Case: mft(eigenvectors, Mass, Name=Value...)
    eigenvectors = meshInput;
    
    % Check if second argument is Mass matrix
    if isempty(varargin)
        error('bct:manifold:operator:mft:MissingMass', ...
            'When providing eigenvectors directly, Mass matrix is required as second argument.');
    end
    
    % First varargin element should be Mass
    Mass = varargin{1};
    if ~isnumeric(Mass)
        error('bct:manifold:operator:mft:InvalidMass', ...
            'Second argument must be Mass matrix (numeric).');
    end
    
    % Parse remaining name-value pairs
    p = inputParser;
    p.addParameter('Annotate', false, @islogical);
    p.addParameter('Strict', true, @islogical);
    if length(varargin) > 1
        p.parse(varargin{2:end});
    else
        p.parse();
    end
    
    options.Annotate = p.Results.Annotate;
    options.Strict = p.Results.Strict;
    options.Annotate = p.Results.Annotate;
    options.Strict = p.Results.Strict;
    
    % Input validation for eigenvectors and Mass
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
    
else
    error('bct:manifold:operator:mft:InvalidInput', ...
        'First argument must be bct.Manifold or numeric eigenvectors matrix.');
end

% Compute forward transform operator: mft = eigenvectors' * Mass
% Output size: [k × N] where k = number of modes, N = number of vertices
mft_matrix = eigenvectors' * Mass;

% Build header
header = struct( ...
    'operator', 'mft', ...
    'k', size(eigenvectors, 2), ...
    'N', size(eigenvectors, 1), ...
    'normalization', 'mass-orthonormal', ...
    'annotate', options.Annotate ...
);

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
