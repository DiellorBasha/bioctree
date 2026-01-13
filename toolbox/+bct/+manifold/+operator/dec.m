function [header, operators] = dec(meshInput, varargin)
%DEC Construct DEC operators from manifold
%
% Syntax:
%   [header, operators] = bct.manifold.operator.dec(M)
%   [header, operators] = bct.manifold.operator.dec(V, F)
%
% Inputs:
%   M - bct.Manifold object
%   OR
%   V - [N×3] vertex coordinates
%   F - [M×3] face connectivity
%
% Outputs:
%   header - Structure with metadata about DEC computation:
%            .method       - 'DECLab'
%            .backend      - 'DiscreteExteriorCalculus'
%            .numVertices  - Number of vertices
%            .numFaces     - Number of faces
%            .numEdges     - Number of edges
%
%   operators - Structure with all DEC operator matrices:
%               .d0, .d1       - Exterior derivatives
%               .dd0, .dd1     - Codifferentials
%               .hd0, .hd1, .hd2    - Hodge star operators
%               .hdd0, .hdd1, .hdd2 - Inverse Hodge star operators
%               .flatPP, .flatDP, .flatDD - Flat operators
%               .sharpPD, .sharpDD        - Sharp operators
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
%   [header, ops] = bct.manifold.operator.dec(M);
%   
%   % Apply exterior derivative d0: C⁰ → C¹
%   f0 = rand(M.numVertices(), 1);
%   f1 = ops.d0 * f0;
%   
%   % Laplacian via Δ = dd0·d0 + d1·dd1
%   laplacian0 = ops.dd0 * ops.d0;
%   
%   % From V, F directly
%   [header, ops] = bct.manifold.operator.dec(V, F);
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

% Construct DiscreteExteriorCalculus object
F_double = double(F);
V_double = double(V);
dec = DiscreteExteriorCalculus(F_double, V_double);

% Build header with metadata
header = struct();
header.method = 'DECLab';
header.backend = 'DiscreteExteriorCalculus';
header.numVertices = size(V, 1);
header.numFaces = size(F, 1);
header.numEdges = size(dec.E, 1);

% Extract all DEC operators into structure
operators = struct();

% Exterior derivatives and codifferentials
operators.d0 = dec.d0;
operators.d1 = dec.d1;
operators.dd0 = dec.dd0;
operators.dd1 = dec.dd1;

% Hodge star operators
operators.hd0 = dec.hd0;
operators.hd1 = dec.hd1;
operators.hd2 = dec.hd2;

% Inverse Hodge star operators
operators.hdd0 = dec.hdd0;
operators.hdd1 = dec.hdd1;
operators.hdd2 = dec.hdd2;

% Flat and sharp operators
operators.flatPP = dec.flatPP;
operators.flatDP = dec.flatDP;
operators.flatDD = dec.flatDD;
operators.sharpPD = dec.sharpPD;
operators.sharpDD = dec.sharpDD;

end
