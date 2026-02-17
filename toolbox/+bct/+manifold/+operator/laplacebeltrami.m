function [header, L] = laplacebeltrami(meshInput, varargin)
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
%   [header, L] = bct.manifold.operator.laplacebeltrami(M)
%   [header, L] = bct.manifold.operator.laplacebeltrami(V, F)
%   [header, L] = bct.manifold.operator.laplacebeltrami(..., Name, Value, ...)
%
% Inputs:
%   M  - bct.Manifold object
%   OR
%   V  - [N×3] vertex coordinates
%   F  - [nF×3] face connectivity (1-based)
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
%   % Default: generalized form for eigenmodes (using Manifold)
%   [header, L] = bct.manifold.operator.laplacebeltrami(M);
%   [V, D] = eigs(L.S, L.M, 100, 'sm');  % First 100 eigenmodes
%
%   % Using vertex coordinates and faces directly
%   [header, L] = bct.manifold.operator.laplacebeltrami(V, F);
%
%   % Strong-form matrix operator
%   [header, L] = bct.manifold.operator.laplacebeltrami(M, 'form', 'matrix');
%   Lu = L.A * u;  % Apply Laplacian to scalar field u
%
%   % Custom mass/stiffness configuration with V, F
%   [header, L] = bct.manifold.operator.laplacebeltrami(V, F, ...
%       'massVariant', 'full', ...
%       'stiffnessSign', 'positive', ...
%       'precision', 'double');
%
%   % Single precision for GPU export
%   [header, L] = bct.manifold.operator.laplacebeltrami(M, 'precision', 'single');
%
% See also: bct.manifold.operator.mass, bct.manifold.operator.stiffness,
%           bct.manifold.eigenmodes

% ----------------------------
% Parse inputs
% ----------------------------
if nargin == 0
    error('bct:manifold:operator:laplacebeltrami:NoInput', ...
        'At least one input required: laplacebeltrami(M) or laplacebeltrami(V, F)');
end

% Check if first argument is Manifold or numeric
if isa(meshInput, 'bct.Manifold')
    % Case: laplacebeltrami(M, Name=Value...)
    nameValueStart = 1;
elseif isnumeric(meshInput) && ~isempty(varargin) && isnumeric(varargin{1})
    % Case: laplacebeltrami(V, F, Name=Value...)
    V = meshInput;
    F = varargin{1};
    nameValueStart = 2;
    
    % Validate V, F
    if size(V, 2) ~= 3
        error('bct:manifold:operator:laplacebeltrami:InvalidVertices', ...
            'V must be an [N×3] numeric array.');
    end
    if size(F, 2) ~= 3
        error('bct:manifold:operator:laplacebeltrami:InvalidFaces', ...
            'F must be an [nF×3] numeric array of vertex indices.');
    end
    if any(F(:) < 1) || any(F(:) ~= round(F(:)))
        error('bct:manifold:operator:laplacebeltrami:InvalidFaces', ...
            'F must contain positive 1-based integer indices.');
    end
    if max(F(:)) > size(V, 1)
        error('bct:manifold:operator:laplacebeltrami:InvalidFaces', ...
            'F references vertex index %d but V has only %d vertices.', ...
            max(F(:)), size(V, 1));
    end
else
    error('bct:manifold:operator:laplacebeltrami:InvalidInput', ...
        'Input must be either laplacebeltrami(M) or laplacebeltrami(V, F). Got %s.', class(meshInput));
end

% Parse Name-Value pairs
p = inputParser;
p.addParameter('method', 'fem', @(x) ismember(x, ["fem","dec"]));
p.addParameter('form', 'generalized', @(x) ismember(x, ["generalized","matrix"]));
p.addParameter('massVariant', 'voronoi', @(x) ismember(x, ["voronoi","barycentric","full"]));
p.addParameter('stiffnessVariant', 'cotan', @(x) ismember(x, ["cotan"]));
p.addParameter('stiffnessSign', 'positive', @(x) ismember(x, ["positive","negative"]));
p.addParameter('symmetrize', true, @islogical);
p.addParameter('precision', 'double', @(x) ismember(x, ["double","single"]));
p.parse(varargin{nameValueStart:end});

options = p.Results;

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
        % Pass either Manifold or V, F depending on input
        if isa(meshInput, 'bct.Manifold')
            % [massHeader, M0] = bct.manifold.operator.mass(meshInput, ...
            %     'variant', options.massVariant, ...
            %     'symmetrize', options.symmetrize, ...
            %     'precision', options.precision);
            % 
            % [stiffHeader, S0] = bct.manifold.operator.stiffness(meshInput, ...
            %     'variant', options.stiffnessVariant, ...
            %     'sign', options.stiffnessSign, ...
            %     'symmetrize', options.symmetrize, ...
            %     'precision', options.precision);
        mass=meshInput.mass;
        massHeader=mass.attributes; M0=mass.value;
        stiff=meshInput.stiffness;
        stiffHeader=stiff.attributes; S0=stiff.value;
        else
            % Using V, F
            [massHeader, M0] = bct.manifold.operator.mass(V, F, ...
                'variant', options.massVariant, ...
                'symmetrize', options.symmetrize, ...
                'precision', options.precision);

            [stiffHeader, S0] = bct.manifold.operator.stiffness(V, F, ...
                'variant', options.stiffnessVariant, ...
                'sign', options.stiffnessSign, ...
                'symmetrize', options.symmetrize, ...
                'precision', options.precision);
        end

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
