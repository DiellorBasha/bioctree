function ops = operator(meshInput, varargin)
%OPERATOR Compute and aggregate all differential operators
%
% Syntax:
%   ops = bct.manifold.operator(M)
%   ops = bct.manifold.operator(V, F)
%   ops = bct.manifold.operator(__, Name, Value)
%
% Inputs:
%   M      - bct.Manifold object
%   V      - [N×3] vertex coordinates
%   F      - [M×3] face connectivity
%
% Optional Parameters:
%   MassVariant      - 'voronoi' (default), 'barycentric', 'full'
%   StiffnessVariant - 'cotan' (default)
%   StiffnessSign    - 'positive' (default), 'negative'
%   Symmetrize       - true (default), false
%
% Outputs:
%   ops - Structure with fields:
%     .mass            - [N×N] FEM mass matrix
%     .stiffness       - [N×N] FEM stiffness matrix (cotangent Laplacian)
%     .laplacebeltrami - [N×N] Laplace-Beltrami operator (M^(-1) * K)
%     .dec             - Structure with 15 DEC operators:
%       .d0, .d1       - Exterior derivatives
%       .dd0, .dd1     - Codifferentials
%       .hd0-2         - Hodge stars
%       .hdd0-2        - Inverse Hodge stars
%       .flatPP, etc.  - Flat operators
%       .sharpPD, etc. - Sharp operators
%     % Top-level DEC shortcuts
%     .d0, .d1, .dd0, .dd1  - Exterior derivatives
%     % Derived DEC composition operators
%     .gradient        - Gradient operator (vertex → face tangent vectors)
%     .divergence      - Divergence operator (edge → vertex, primal route)
%     .curl            - Curl operator (edge → face, primal route)
%     .hodgelaplacian  - Hodge Laplacian struct (kform0, kform1, kform2)
%
% Description:
%   Aggregates all operator computations from the bct.manifold.operator
%   subpackage. Computes FEM matrices (mass, stiffness, Laplace-Beltrami)
%   and all DEC operators (exterior derivatives, Hodge stars, etc.), plus
%   derived composition operators (gradient, divergence, curl, Hodge Laplacian).
%
%   This is an aggregator function similar to bct.manifold.geometry() and
%   bct.manifold.topology(). It computes all operators in one call for
%   convenience and completeness.
%
%   The Laplace-Beltrami operator is computed as the generalized eigenvalue
%   form: L = M^(-1) * K, where M is the mass matrix and K is the stiffness
%   matrix. This is the standard FEM discretization of the Laplace-Beltrami
%   operator on manifolds.
%
% Examples:
%   % Compute all operators for a Manifold
%   M = bct.Manifold(V, F);
%   ops = bct.manifold.operator(M);
%   
%   % Access individual operators
%   L = ops.laplacebeltrami;
%   d0 = ops.dec.d0;
%   
%   % Vector calculus operators
%   grad = ops.gradient;           % [3*nF × nV]
%   div = ops.divergence;          % [nV × nE]
%   curl = ops.curl;               % [nF × nE]
%   Lap0 = ops.hodgelaplacian.kform0;  % [nV × nV]
%   
%   % Apply gradient to scalar field
%   f = randn(M.numVertices(), 1);
%   grad_f = ops.gradient * f;  % Tangent vectors at faces
%   
%   % Compute with custom parameters
%   ops = bct.manifold.operator(M, 'MassVariant', 'barycentric');
%   
%   % Direct V, F input
%   ops = bct.manifold.operator(V, F);
%
% See also: bct.manifold.operator.mass, bct.manifold.operator.stiffness,
%           bct.manifold.operator.dec, bct.manifold.operator.gradient,
%           bct.manifold.operator.divergence, bct.manifold.operator.curl,
%           bct.manifold.operator.hodgelaplacian, bct.manifold.geometry,
%           bct.manifold.topology

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.operator';
p.addRequired('meshInput');
p.addOptional('F', []);
p.addParameter('MassVariant', 'voronoi', @(x) ischar(x) || isstring(x));
p.addParameter('StiffnessVariant', 'cotan', @(x) ischar(x) || isstring(x));
p.addParameter('StiffnessSign', 'positive', @(x) ischar(x) || isstring(x));
p.addParameter('Symmetrize', true, @islogical);
p.parse(meshInput, varargin{:});

% Extract mesh data
if isa(meshInput, 'bct.Manifold')
    M = meshInput;
    V = M.Vertices;
    F = M.Faces;
elseif isnumeric(meshInput) && ~isempty(p.Results.F)
    % V, F interface
    V = meshInput;
    F = p.Results.F;
    M = bct.Manifold(V, F);
else
    error('bct:manifold:operator:InvalidInput', ...
        'Input must be bct.Manifold or (V, F) pair');
end

% Extract parameters
massVariant = string(p.Results.MassVariant);
stiffnessVariant = string(p.Results.StiffnessVariant);
stiffnessSign = string(p.Results.StiffnessSign);
symmetrize = p.Results.Symmetrize;

% Initialize output structure
ops = struct();

% ===============================================================
% FEM Operators
% ===============================================================

% Compute mass matrix
[~, Mass] = bct.manifold.operator.mass(M, 'variant', massVariant);
ops.mass = Mass;

% Compute stiffness matrix
[~, Stiffness] = bct.manifold.operator.stiffness(M, ...
    'variant', stiffnessVariant, ...
    'sign', stiffnessSign, ...
    'symmetrize', symmetrize);
ops.stiffness = Stiffness;

% Compute Laplace-Beltrami operator: L = M^(-1) * K
% This is the standard FEM discretization as a linear operator
if issparse(Mass)
    % Solve M * L = K for L (more numerically stable than inv(M) * K)
    ops.laplacebeltrami = Mass \ Stiffness;
else
    % If mass is diagonal (voronoi, barycentric), can use direct division
    if isdiag(Mass)
        massInv = spdiags(1./diag(Mass), 0, size(Mass,1), size(Mass,2));
        ops.laplacebeltrami = massInv * Stiffness;
    else
        ops.laplacebeltrami = Mass \ Stiffness;
    end
end

% ===============================================================
% DEC Operators
% ===============================================================

% Compute all DEC operators
[~, dec_ops] = bct.manifold.operator.dec(M);
ops.dec = dec_ops;

% Also expose key DEC operators at top level for convenience
ops.d0 = dec_ops.d0;
ops.d1 = dec_ops.d1;
ops.dd0 = dec_ops.dd0;
ops.dd1 = dec_ops.dd1;

% ===============================================================
% Derived DEC Composition Operators
% ===============================================================

% Gradient: scalar field (vertex) → tangent vector field (face)
% Composition: sharpPD * d0
[~, ops.gradient] = bct.manifold.operator.gradient(M);

% Divergence: edge 1-form → vertex scalar (primal route)
% Composition: hdd2 * dd1 * hd1
[~, ops.divergence] = bct.manifold.operator.divergence(M, 'route', 'primal');

% Curl: edge 1-form → face scalar (primal route)
% Composition: hd2 * d1
[~, ops.curl] = bct.manifold.operator.curl(M, 'route', 'primal');

% Hodge Laplacian: All three k-forms
ops.hodgelaplacian = struct();
[~, ops.hodgelaplacian.kform0] = bct.manifold.operator.hodgelaplacian(M, 'kform', 0);
[~, ops.hodgelaplacian.kform1] = bct.manifold.operator.hodgelaplacian(M, 'kform', 1);
[~, ops.hodgelaplacian.kform2] = bct.manifold.operator.hodgelaplacian(M, 'kform', 2);

end
