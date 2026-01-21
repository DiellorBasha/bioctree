function [header, gradPsi] = gradient(M, varargin)
%GRADIENT Compute gradient operator projected onto eigenmode basis
%
% Syntax:
%   gradPsi = bct.manifold.transform.gradient(M)
%   gradPsi = bct.manifold.transform.gradient(M, eigen)
%   gradPsi = bct.manifold.transform.gradient(M, Name, Value)
%   [header, gradPsi] = bct.manifold.transform.gradient(__)
%
% Inputs:
%   M     - bct.Manifold object
%   eigen - (Optional) Eigenmode structure with fields:
%           .vectors - [nV x K] eigenvectors
%           .k       - Number of modes
%           If not provided, uses M.eigenmodes()
%
% Name-Value Arguments:
%   Eigen          - Eigenmode structure (alternative to positional)
%   TangentProject - true (default) | false, project to face tangent plane
%   Precision      - 'single' (default) | 'double' for output precision
%
% Outputs:
%   gradPsi - [nF x K x 3] gradient eigenbasis
%             gradPsi(f, k, :) is the gradient of mode k at face f
%             Components are [X, Y, Z] in ambient coordinates
%             If TangentProject=true, tangent to face normal
%   header  - Metadata structure with computation info
%
% Description:
%   Computes the gradient operator applied to the eigenmode basis:
%     gradPsi = grad * U
%   where U are the eigenvectors and grad is the gradient operator.
%
%   The gradient operator is [3*nF x nV] with layout:
%     [X-block; Y-block; Z-block] (component blocks)
%
%   Result is reshaped to [nF x K x 3] for convenience.
%
%   Tangent projection removes the normal component at each face:
%     gradPsi_tangent = gradPsi - (gradPsi · n) * n
%   This ensures the gradient vectors lie in the face tangent plane.
%
% Examples:
%   % Compute gradient eigenbasis with cached eigenmodes
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   M.eigenmodes(100);  % Compute and cache
%   gradPsi = bct.manifold.transform.gradient(M);
%   size(gradPsi)  % [nF x 100 x 3]
%
%   % Provide eigenmodes explicitly
%   eigen = M.eigenmodes(50);
%   gradPsi = bct.manifold.transform.gradient(M, eigen);
%
%   % Double precision without tangent projection
%   gradPsi = bct.manifold.transform.gradient(M, ...
%       'Precision', 'double', 'TangentProject', false);
%
%   % Use in spectral reconstruction
%   coeffs = randn(100, 1);  % Spectral coefficients
%   gradField = squeeze(sum(gradPsi .* reshape(coeffs, 1, [], 1), 2));
%   % gradField is [nF x 3] gradient field
%
% See also: bct.manifold.operator.gradient, bct.manifold.eigenmodes,
%           bct.manifold.transform.divergence

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.transform.gradient';
p.addRequired('M', @(x) isa(x, 'bct.Manifold'));
p.addOptional('Eigen', [], @(x) isempty(x) || isstruct(x));
p.addParameter('TangentProject', true, @islogical);
p.addParameter('Precision', 'single', @(x) ismember(x, {'single', 'double'}));
p.parse(M, varargin{:});

eigen = p.Results.Eigen;
tangentProject = p.Results.TangentProject;
precision = p.Results.Precision;

% Get eigenmodes if not provided
if isempty(eigen)
    eigen = M.eigenmodes();
end

% Validate eigenmode structure
if ~isfield(eigen, 'vectors') || ~isfield(eigen, 'k')
    error('bct:manifold:transform:InvalidEigen', ...
        'Eigen structure must have fields: vectors, k');
end

K = double(eigen.k);
nF = M.numFaces();
nV = M.numVertices();

% Validate dimensions
if size(eigen.vectors, 1) ~= nV
    error('bct:manifold:transform:DimensionMismatch', ...
        'Eigenvectors must be [nV x K], got [%d x %d]', ...
        size(eigen.vectors, 1), size(eigen.vectors, 2));
end

% Get gradient operator
[gradHeader, grad] = M.gradient();

% Validate gradient dimensions
if size(grad, 1) ~= 3*nF || size(grad, 2) ~= nV
    error('bct:manifold:transform:InvalidGradient', ...
        'Gradient operator must be [3*nF x nV], got [%d x %d]', ...
        size(grad, 1), size(grad, 2));
end

% Project gradient onto eigenmodes: [3*nF x K]
% grad is [3*nF x nV], eigen.vectors is [nV x K]
Gpsi = grad * eigen.vectors;

% Extract component blocks
Gx = Gpsi(1:nF, :);              % [nF x K]
Gy = Gpsi(nF+1:2*nF, :);          % [nF x K]
Gz = Gpsi(2*nF+1:3*nF, :);        % [nF x K]

% Assemble as [nF x K x 3]
if strcmp(precision, 'single')
    gradPsi = single(cat(3, Gx, Gy, Gz));
else
    gradPsi = cat(3, Gx, Gy, Gz);
end

% Apply tangent projection if requested
if tangentProject
    % Get face normals
    geom = M.geometry();
    N = geom.face.normals;  % [nF x 3]
    
    % Convert to requested precision
    if strcmp(precision, 'single')
        N = single(N);
    end
    
    % Ensure unit normals
    N = N ./ max(vecnorm(N, 2, 2), eps(precision));
    
    % Compute dot product: <gradPsi(f,k), n(f)> for all f, k
    % gradPsi is [nF x K x 3], N is [nF x 3]
    dotUN = gradPsi(:,:,1) .* N(:,1) + ...
            gradPsi(:,:,2) .* N(:,2) + ...
            gradPsi(:,:,3) .* N(:,3);  % [nF x K]
    
    % Project to tangent plane: gradPsi_tan = gradPsi - (gradPsi·n)*n
    gradPsi(:,:,1) = gradPsi(:,:,1) - dotUN .* N(:,1);
    gradPsi(:,:,2) = gradPsi(:,:,2) - dotUN .* N(:,2);
    gradPsi(:,:,3) = gradPsi(:,:,3) - dotUN .* N(:,3);
end

% Build header
header = struct();
header.source = 'bct.manifold.transform.gradient';
header.manifoldId = M.Header.ID;
header.shape = [nF, K, 3];
header.nFaces = nF;
header.nModes = K;
header.tangentProjected = tangentProject;
header.precision = precision;
header.gradientHeader = gradHeader;
header.timestamp = datetime('now');

end
