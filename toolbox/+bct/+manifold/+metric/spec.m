function specMap = spec(domain)
%SPEC Return unit/dimension specifications for manifold quantities
%
% Syntax:
%   specMap = bct.manifold.metric.spec(domain)
%
% Inputs:
%   domain - String specifying domain: "geometry" | "operator" | "eigen"
%
% Outputs:
%   specMap - containers.Map keyed by field name with spec structs:
%             .unit - SI unit label
%             .Lexp - Length dimension exponent
%             .meta - Default metadata (optional)
%
% Description:
%   Returns canonical specifications for all annotatable quantities in
%   each domain. This is the "truth table" mapping output field names to
%   their physical dimensions and SI units.
%
% Geometry Domain:
%   - edgeLengths: m (Lexp=1)
%   - faceAreas: m^2 (Lexp=2)
%   - dualEdgeLengths: m (Lexp=1)
%   - dualVertexAreas: m^2 (Lexp=2)
%   - centroids: m (Lexp=1, positions)
%   - faceCircumcenters: m (Lexp=1, positions)
%   - normals: 1 (Lexp=0, normalized vectors)
%   - tangents: 1 (Lexp=0, normalized vectors)
%   - frame: 1 (Lexp=0, orthonormal basis)
%   - cotan: 1 (Lexp=0, dimensionless angles)
%   - edgeWeights: structure with cotangent/euclidean sub-specs
%
% Operator Domain:
%   - gradient: 1/m (Lexp=-1)
%   - divergence: 1/m (Lexp=-1)
%   - curl: 1/m (Lexp=-1)
%   - laplacebeltrami: 1/m^2 (Lexp=-2)
%   - mass: m^2 (Lexp=2, area/volume measure)
%   - stiffness: 1 (Lexp=0, dimensionless for cotangent weights)
%   - d0, d1, d2: 1 (Lexp=0, topological incidence)
%   - hodge0, hodge1, hodge2: varies (see meta)
%
% Eigen Domain:
%   - Values: 1/m^2 (Lexp=-2, eigenvalues of Laplacian)
%   - Vectors: 1 (Lexp=0, eigenmodes, normalized)
%
% Examples:
%   geomSpec = bct.manifold.metric.spec('geometry');
%   areaSpec = geomSpec('faceAreas');
%   % areaSpec.unit = "m^2"
%   % areaSpec.Lexp = 2
%
% See also: bct.manifold.metric.annotate, bct.manifold.metric.quantity

arguments
    domain (1,1) string {mustBeMember(domain, ["geometry", "operator", "eigen"])}
end

switch domain
    case "geometry"
        specMap = geometrySpec();
    case "operator"
        specMap = operatorSpec();
    case "eigen"
        specMap = eigenSpec();
end

end

%% Domain-specific spec functions

function m = geometrySpec()
    m = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    % Length measurements
    m('edgeLengths') = struct('unit', "m", 'Lexp', 1, 'meta', struct());
    m('dualEdgeLengths') = struct('unit', "m", 'Lexp', 1, 'meta', struct());
    
    % Area measurements
    m('faceAreas') = struct('unit', "m^2", 'Lexp', 2, 'meta', struct());
    m('dualVertexAreas') = struct('unit', "m^2", 'Lexp', 2, 'meta', struct());
    
    % Position measurements
    m('centroids') = struct('unit', "m", 'Lexp', 1, 'meta', struct('type', 'position'));
    m('faceCircumcenters') = struct('unit', "m", 'Lexp', 1, 'meta', struct('type', 'position'));
    
    % Dimensionless geometric quantities
    m('normals') = struct('unit', "1", 'Lexp', 0, 'meta', struct('normalized', true));
    m('tangents') = struct('unit', "1", 'Lexp', 0, 'meta', struct('normalized', true));
    m('frame') = struct('unit', "1", 'Lexp', 0, 'meta', struct('type', 'orthonormal_basis'));
    m('cotan') = struct('unit', "1", 'Lexp', 0, 'meta', struct('type', 'cotangent_angles'));
    
    % Edge weights structure (contains sub-quantities)
    m('edgeWeights') = struct('unit', "mixed", 'Lexp', nan, 'meta', struct('type', 'composite'));
end

function m = operatorSpec()
    m = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    % First-order differential operators (gradient-like)
    m('gradient') = struct('unit', "1/m", 'Lexp', -1, 'meta', struct('order', 1));
    m('divergence') = struct('unit', "1/m", 'Lexp', -1, 'meta', struct('order', 1));
    m('curl') = struct('unit', "1/m", 'Lexp', -1, 'meta', struct('order', 1));
    m('d0') = struct('unit', "1", 'Lexp', 0, 'meta', struct('type', 'topological'));
    m('d1') = struct('unit', "1", 'Lexp', 0, 'meta', struct('type', 'topological'));
    m('d2') = struct('unit', "1", 'Lexp', 0, 'meta', struct('type', 'topological'));
    
    % Second-order differential operators (Laplacian-like)
    m('laplacebeltrami') = struct('unit', "1/m^2", 'Lexp', -2, 'meta', struct('order', 2));
    m('hodgelaplacian0') = struct('unit', "1/m^2", 'Lexp', -2, 'meta', struct('order', 2, 'form', 0));
    m('hodgelaplacian1') = struct('unit', "1/m^2", 'Lexp', -2, 'meta', struct('order', 2, 'form', 1));
    m('hodgelaplacian2') = struct('unit', "1/m^2", 'Lexp', -2, 'meta', struct('order', 2, 'form', 2));
    m('graphlaplacian') = struct('unit', "1", 'Lexp', 0, 'meta', struct('type', 'topological'));
    
    % Mass and metric operators
    m('mass') = struct('unit', "m^2", 'Lexp', 2, 'meta', struct('type', 'area_measure'));
    m('stiffness') = struct('unit', "1", 'Lexp', 0, 'meta', struct('type', 'cotangent'));
    
    % Hodge stars (metric-dependent, dimension-converting)
    m('hodge0') = struct('unit', "m^2", 'Lexp', 2, 'meta', struct('maps', '0-form to 2-form'));
    m('hodge1') = struct('unit', "1", 'Lexp', 0, 'meta', struct('maps', '1-form to 1-form'));
    m('hodge2') = struct('unit', "1/m^2", 'Lexp', -2, 'meta', struct('maps', '2-form to 0-form'));
end

function m = eigenSpec()
    m = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    % Laplacian eigenvalues (inverse square length)
    m('Values') = struct('unit', "1/m^2", 'Lexp', -2, 'meta', struct('operator', 'Laplacian'));
    m('lambda') = struct('unit', "1/m^2", 'Lexp', -2, 'meta', struct('operator', 'Laplacian'));
    
    % Eigenmodes (dimensionless, normalized)
    m('Vectors') = struct('unit', "1", 'Lexp', 0, 'meta', struct('normalized', true, 'orthogonality', 'mass'));
    m('phi') = struct('unit', "1", 'Lexp', 0, 'meta', struct('normalized', true, 'orthogonality', 'mass'));
end
