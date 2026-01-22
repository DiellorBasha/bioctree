function out = dec(meshInput, varargin)
%DEC Construct DEC operators from manifold
%
% Syntax:
%   dec = bct.manifold.operator.dec(M)
%   dec = bct.manifold.operator.dec(V, F)
%
% Inputs:
%   M - bct.Manifold object
%   OR
%   V - [N×3] vertex coordinates
%   F - [M×3] face connectivity
%
% Outputs:
%   out - Structure matching DEC operator group schema:
%     .attributes - Group-level metadata:
%       .method       - 'DECLab'
%       .backend      - 'DiscreteExteriorCalculus'
%       .numVertices  - Number of vertices
%       .numFaces     - Number of faces
%       .numEdges     - Number of edges
%       .path         - 'operator/dec'
%       .description  - 'Discrete Exterior Calculus operators'
%     
%     Each operator is a dataset structure with .value and .attributes:
%     .d0, .d1       - Exterior derivatives
%     .dd0, .dd1     - Codifferentials
%     .hd0, .hd1, .hd2    - Hodge star operators
%     .hdd0, .hdd1, .hdd2 - Inverse Hodge star operators
%     .flatPP, .flatDP, .flatDD - Flat operators
%     .sharpPD, .sharpDD        - Sharp operators
%
% Description:
%   Constructs a DiscreteExteriorCalculus object from DECLab and extracts
%   all operator matrices. This provides access to the full DEC operator
%   suite for discrete differential geometry computations.
%
%   The operators include:
%   - Exterior derivatives (d0, d1): Differential operators on forms
%   - Codifferentials (dd0, dd1): Adjoint operators
%   - Hodge stars (hd0, hd1, hd2): Metric-dependent duality operators
%   - Inverse Hodge stars (hdd0, hdd1, hdd2): Inverses of Hodge stars
%   - Flat/Sharp: Musical isomorphisms between vector fields and forms
%
% Examples:
%   % From Manifold
%   M = bct.Manifold(V, F);
%   dec = bct.manifold.operator.dec(M);
%   
%   % Apply exterior derivative d0: C⁰ → C¹
%   f0 = rand(M.numVertices(), 1);
%   f1 = dec.d0.value * f0;
%   
%   % Laplacian via Δ = dd0·d0 + d1·dd1
%   laplacian0 = dec.dd0.value * dec.d0.value;
%   
%   % Access metadata
%   method = dec.attributes.method;  % 'DECLab'
%   d0_desc = dec.d0.attributes.description;
%   
%   % From V, F directly
%   dec = bct.manifold.operator.dec(V, F);
%
% See also: DiscreteExteriorCalculus, bct.Manifold.DEC

% Parse inputs
if nargin == 1 && isa(meshInput, 'bct.Manifold')
    % Input is Manifold object
    V = meshInput.Vertices;
    F = meshInput.Faces;
elseif nargin == 2
    % Inputs are V, F
    V = meshInput;
    F = varargin{1};
else
    error('bct:manifold:operator:dec:InvalidInput', ...
        'Usage: dec(Manifold) or dec(V, F)');
end

% Check for DECLab availability
if exist("DiscreteExteriorCalculus", "class") ~= 8
    error("bct:MissingDependency", ...
        ['DECLab not found on MATLAB path (DiscreteExteriorCalculus missing). ' ...
         'Add external/DECLab to your path.']);
end
Obj = DiscreteExteriorCalculus(F_double, V_double);

% Initialize output structure
out = struct();

% Group-level attributes (metadata for the entire DEC operator group)
out.attributes = struct();
out.attributes.method = 'DECLab';
out.attributes.backend = 'DiscreteExteriorCalculus';
out.attributes.numVertices = uint32(size(V, 1));
out.attributes.numFaces = uint32(size(F, 1));
out.attributes.numEdges = uint32(size(decObj.E, 1));
out.attributes.path = 'operator/dec';
out.attributes.description = 'Discrete Exterior Calculus operators';
out.attributes.schema = 'bct.manifold.operator.dec@1.0.0';

% Helper function to create dataset structure
createDataset = @(name, matrix, desc) struct(...
    'value', matrix, ...
    'attributes', struct(...
        'name', name, ...
        'path', ['operator/dec/' name], ...
        'description', desc, ...
        'shape', [size(matrix, 1), size(matrix, 2)], ...
        'nnz', nnz(matrix), ...
        'storage', 'sparse'));

% Exterior derivatives
out.d0 = createDataset('d0', decObj.d0, 'Exterior derivative d0: 0-forms → 1-forms (vertex → edge)');
out.d1 = createDataset('d1', decObj.d1, 'Exterior derivative d1: 1-forms → 2-forms (edge → face)');

% Codifferentials (δ = ⋆d⋆)
out.dd0 = createDataset('dd0', decObj.dd0, 'Codifferential δ0: 1-forms → 0-forms (edge → vertex)');
out.dd1 = createDataset('dd1', decObj.dd1, 'Codifferential δ1: 2-forms → 1-forms (face → edge)');

% Hodge star operators (⋆)
out.hd0 = createDataset('hd0', decObj.hd0, 'Hodge star ⋆0: primal 0-forms → dual 2-forms');
out.hd1 = createDataset('hd1', decObj.hd1, 'Hodge star ⋆1: primal 1-forms → dual 1-forms');
out.hd2 = createDataset('hd2', decObj.hd2, 'Hodge star ⋆2: primal 2-forms → dual 0-forms');

% Inverse Hodge star operators (⋆⁻¹)
out.hdd0 = createDataset('hdd0', decObj.hdd0, 'Inverse Hodge star ⋆0⁻¹: dual 2-forms → primal 0-forms');
out.hdd1 = createDataset('hdd1', decObj.hdd1, 'Inverse Hodge star ⋆1⁻¹: dual 1-forms → primal 1-forms');
out.hdd2 = createDataset('hdd2', decObj.hdd2, 'Inverse Hodge star ⋆2⁻¹: dual 0-forms → primal 2-forms');

% Flat operators (♭: vector fields → differential forms)
out.flatPP = createDataset('flatPP', decObj.flatPP, 'Flat ♭: primal vectors → primal 1-forms');
out.flatDP = createDataset('flatDP', decObj.flatDP, 'Flat ♭: dual vectors → primal 1-forms');
out.flatDD = createDataset('flatDD', decObj.flatDD, 'Flat ♭: dual vectors → dual 1-forms');

% Sharp operators (♯: differential forms → vector fields)
out.sharpPD = createDataset('sharpPD', decObj.sharpPD, 'Sharp ♯: primal 1-forms → dual vectors');
out.sharpDD = createDataset('sharpDD', decObj.sharpDD, 'Sharp ♯: dual 1-forms → dual vectors')
operators.flatDP = dec.flatDP;
operators.flatDD = dec.flatDD;
operators.sharpPD = dec.sharpPD;
operators.sharpDD = dec.sharpDD;

end
