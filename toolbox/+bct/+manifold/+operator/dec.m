function out = dec(meshInput, varargin)
%DEC Construct DEC operators from manifold
%
% Syntax:
%   dec = bct.manifold.operator.dec(M)
%   dec = bct.manifold.operator.dec(Vertices, Faces)
%
% Inputs:
%   M - bct.Manifold object
%   OR
%   Vertices - [N×3] vertex coordinates
%   Faces - [M×3] face connectivity
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
%   M = bct.Manifold(Vertices, Faces);
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
%   % From Vertices, Faces directly
%   dec = bct.manifold.operator.dec(Vertices, Faces);
%
% See also: DiscreteExteriorCalculus, bct.Manifold.DEC

% Parse inputs
if nargin == 1 && isa(meshInput, 'bct.Manifold')
    % Input is Manifold object
    Vertices = meshInput.Vertices;
    Faces = meshInput.Faces;
elseif nargin == 2
    % Inputs are Vertices, Faces
    Vertices = meshInput;
    Faces = varargin{1};
else
    error('bct:manifold:operator:dec:InvalidInput', ...
        'Usage: dec(Manifold) or dec(Vertices, Faces)');
end

% Check for DECLab availability
if exist("DiscreteExteriorCalculus", "class") ~= 8
    error("bct:MissingDependency", ...
        ['DECLab not found on MATLAB path (DiscreteExteriorCalculus missing). ' ...
         'Add external/DECLab to your path.']);
end

% Convert to double for DiscreteExteriorCalculus constructor
Faces_double = double(Faces);
Vertices_double = double(Vertices);

% Construct DEC object
Obj = DiscreteExteriorCalculus(Faces_double, Vertices_double);

% Initialize output structure
out = struct();

% Group-level attributes (metadata for the entire DEC operator group)
out.attributes = struct();
out.attributes.method = 'DECLab';
out.attributes.backend = 'DiscreteExteriorCalculus';
out.attributes.numVertices = uint32(size(Vertices, 1));
out.attributes.numFaces = uint32(size(Faces, 1));
out.attributes.numEdges = uint32(size(Obj.E, 1));
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
out.d0 = createDataset('d0', Obj.d0, 'Exterior derivative d0: 0-forms → 1-forms (vertex → edge)');
out.d1 = createDataset('d1', Obj.d1, 'Exterior derivative d1: 1-forms → 2-forms (edge → face)');

% Codifferentials (δ = ⋆d⋆)
out.dd0 = createDataset('dd0', Obj.dd0, 'Codifferential δ0: 1-forms → 0-forms (edge → vertex)');
out.dd1 = createDataset('dd1', Obj.dd1, 'Codifferential δ1: 2-forms → 1-forms (face → edge)');

% Hodge star operators (⋆)
out.hd0 = createDataset('hd0', Obj.hd0, 'Hodge star ⋆0: primal 0-forms → dual 2-forms');
out.hd1 = createDataset('hd1', Obj.hd1, 'Hodge star ⋆1: primal 1-forms → dual 1-forms');
out.hd2 = createDataset('hd2', Obj.hd2, 'Hodge star ⋆2: primal 2-forms → dual 0-forms');

% Inverse Hodge star operators (⋆⁻¹)
out.hdd0 = createDataset('hdd0', Obj.hdd0, 'Inverse Hodge star ⋆0⁻¹: dual 2-forms → primal 0-forms');
out.hdd1 = createDataset('hdd1', Obj.hdd1, 'Inverse Hodge star ⋆1⁻¹: dual 1-forms → primal 1-forms');
out.hdd2 = createDataset('hdd2', Obj.hdd2, 'Inverse Hodge star ⋆2⁻¹: dual 0-forms → primal 2-forms');

% Flat operators (♭: vector fields → differential forms)
out.flatPP = createDataset('flatPP', Obj.flatPP, 'Flat ♭: primal vectors → primal 1-forms');
out.flatDP = createDataset('flatDP', Obj.flatDP, 'Flat ♭: dual vectors → primal 1-forms');
out.flatDD = createDataset('flatDD', Obj.flatDD, 'Flat ♭: dual vectors → dual 1-forms');

% Sharp operators (♯: differential forms → vector fields)
out.sharpPD = createDataset('sharpPD', Obj.sharpPD, 'Sharp ♯: primal 1-forms → dual vectors');
out.sharpDD = createDataset('sharpDD', Obj.sharpDD, 'Sharp ♯: dual 1-forms → dual vectors');

end
