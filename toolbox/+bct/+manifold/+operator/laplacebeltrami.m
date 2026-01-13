function [header, L] = laplacebeltrami(Manifold, options)
%LAPLACEBELTRAMI Construct Laplace–Beltrami operator on a surface mesh
%
% Default behavior (eigenmode-ready):
%   Returns the generalized FEM operator representation (S, M) such that
%     S u = λ M u
%
% Optional:
%   Returns strong-form matrix A = M \ S (maps vertex scalars -> vertex scalars).
%
% Syntax:
%   [header, L] = bct.manifold.operator.laplacebeltrami(Manifold)
%   [header, L] = bct.manifold.operator.laplacebeltrami(Manifold, Name, Value, ...)
%
% Inputs:
%   Manifold - bct.Manifold object
%
% Name-Value Parameters:
%   method           - Construction method (default: 'fem')
%                      'fem' - Build from FEM mass and stiffness matrices
%                      'dec' - Reserved (Laplace–Beltrami via DEC k=0 Hodge Laplacian)
%   form             - Output form (default: 'generalized')
%                      'generalized' - Return L.S and L.M for eigenvalue problem
%                      'matrix'      - Return L.A where A = M \ S (strong form)
%   massVariant      - Mass matrix variant (default: 'voronoi')
%                      'voronoi' | 'barycentric' | 'full'
%   stiffnessVariant - Stiffness matrix variant (default: 'cotan')
%                      'cotan' (only current option)
%   stiffnessSign    - Sign convention for stiffness (default: 'positive')
%                      'positive' - Positive semidefinite (λ ≥ 0, recommended)
%                      'negative' - Negative semidefinite (λ ≤ 0)
%   symmetrize       - Force symmetric matrices (default: true)
%   precision        - Matrix precision (default: 'double')
%                      'double' | 'single'
%
% Outputs:
%   header - Struct describing parameters and sub-operator headers:
%            .operator - 'laplacebeltrami'
%            .kform - 0 (scalar functions / 0-forms)
%            .method - Construction method used
%            .form - Output form ('generalized' or 'matrix')
%            .massHeader - Header from bct.manifold.operator.mass
%            .stiffnessHeader - Header from bct.manifold.operator.stiffness
%            .notes - String array with usage guidance
%   L      - Operator representation struct:
%            Always contains: .operator, .kform, .method, .form
%            If form='generalized': .S (stiffness), .M (mass)
%            If form='matrix': .A (strong-form operator A = M \ S)
%
% Description:
%   Constructs the Laplace–Beltrami operator in two possible forms:
%
%   1. Generalized form (default, eigenmode-ready):
%      Returns S and M matrices for the generalized eigenvalue problem:
%        S u = λ M u
%      This is the recommended form for eigenmode computation and spectral analysis.
%
%   2. Strong-form matrix:
%      Returns A = M \ S, which directly maps vertex scalar fields to vertex scalars.
%      Note: A is self-adjoint under the M-inner product but NOT symmetric in
%      the Euclidean inner product. Do not use this form for eigenmodes.
%
%   Design invariants:
%   - For method='fem', form='generalized' produces symmetric PSD stiffness S
%     when stiffnessSign='positive' and symmetric SPD mass M
%   - Precision is preserved through sub-operator calls
%   - On closed meshes, S*ones ≈ 0 (constant function in null space)
%
% Examples:
%   % Default: generalized form for eigenmodes
%   [header, L] = bct.manifold.operator.laplacebeltrami(M);
%   [V, D] = eigs(L.S, L.M, 100, 'sm');  % First 100 eigenmodes
%
%   % Strong-form matrix operator
%   [header, L] = bct.manifold.operator.laplacebeltrami(M, 'form', 'matrix');
%   Lu = L.A * u;  % Apply Laplacian to scalar field u
%
%   % Custom mass/stiffness configuration
%   [header, L] = bct.manifold.operator.laplacebeltrami(M, ...
%       'massVariant', 'full', ...
%       'stiffnessSign', 'positive', ...
%       'precision', 'double');
%
%   % Single precision for GPU export
%   [header, L] = bct.manifold.operator.laplacebeltrami(M, 'precision', 'single');
%
% See also: bct.manifold.operator.mass, bct.manifold.operator.stiffness,
%           bct.manifold.eigenmodes

arguments
    Manifold (1,1) bct.Manifold

    options.method (1,1) string {mustBeMember(options.method, ["fem","dec"])} = "fem"
    options.form (1,1) string {mustBeMember(options.form, ["generalized","matrix"])} = "generalized"

    options.massVariant (1,1) string {mustBeMember(options.massVariant, ["voronoi","barycentric","full"])} = "voronoi"
    options.stiffnessVariant (1,1) string {mustBeMember(options.stiffnessVariant, ["cotan"])} = "cotan"
    options.stiffnessSign (1,1) string {mustBeMember(options.stiffnessSign, ["positive","negative"])} = "positive"

    options.symmetrize (1,1) logical = true
    options.precision (1,1) string {mustBeMember(options.precision, ["double","single"])} = "double"
end

% Initialize outputs
header = struct();
L = struct();

% Operator identity metadata (stable across representations)
header.operator = "laplacebeltrami";
header.kform = 0;
header.method = options.method;
header.form = options.form;

L.operator = "laplacebeltrami";
L.kform = 0;
L.method = options.method;
L.form = options.form;

switch options.method
    case "fem"
        % Build mass and stiffness using existing operator factories
        [massHeader, M0] = bct.manifold.operator.mass(Manifold, ...
            'variant', options.massVariant, ...
            'symmetrize', options.symmetrize, ...
            'precision', options.precision);

        [stiffHeader, S0] = bct.manifold.operator.stiffness(Manifold, ...
            'variant', options.stiffnessVariant, ...
            'sign', options.stiffnessSign, ...
            'symmetrize', options.symmetrize, ...
            'precision', options.precision);

        header.massHeader = massHeader;
        header.stiffnessHeader = stiffHeader;

        switch options.form
            case "generalized"
                L.S = S0;
                L.M = M0;

                header.notes = [
                    "Generalized Laplace–Beltrami FEM representation: S u = λ M u."
                    "Use eigs(L.S, L.M, k, 'sm') for eigenmodes."
                    "Strong-form apply: y = L.M \ (L.S * x)."
                ];

            case "matrix"
                % Strong form: A = M^{-1} S
                % Do not symmetrize A by default; self-adjointness is with respect to M-inner product
                A = M0 \ S0;

                L.A = A;

                header.notes = [
                    "Strong-form Laplace–Beltrami operator A = M \ S (maps vertex scalars to vertex scalars)."
                    "Note: A is generally not symmetric in the Euclidean inner product; use generalized form for eigenmodes."
                ];
        end

    case "dec"
        % Reserved: Laplace–Beltrami via DEC k=0 Hodge Laplacian
        error('bct:manifold:operator:laplacebeltrami:NotImplemented', ...
            'method="dec" is reserved but not implemented yet. Use method="fem" for now.');

    otherwise
        error('bct:manifold:operator:laplacebeltrami:InvalidMethod', ...
            'Unsupported method: %s', options.method);
end

end
