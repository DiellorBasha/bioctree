function obj = out(M, targetType, options)
%OUT Convert bct.Manifold to MATLAB geometry object
%
% Syntax:
%   obj = bct.manifold.out(M, 'surfaceMesh')
%   obj = bct.manifold.out(M, 'triangulation')
%   obj = bct.manifold.out(M, 'patch')
%   obj = bct.manifold.out(M, 'graph')
%   obj = bct.manifold.out(M, 'graph', 'EdgeWeights', 'geometry')
%
% Supported Target Types:
%   - 'surfaceMesh': Creates MATLAB surfaceMesh object
%   - 'triangulation': Creates MATLAB triangulation object
%   - 'patch': Creates MATLAB Patch graphics object (in invisible figure)
%   - 'graph': Creates MATLAB graph object with edge weights
%
% Name-Value Arguments (for 'graph' only):
%   EdgeWeights - "geometry" (default) | "fem" | "uniform"
%
% Inputs:
%   M          - bct.Manifold object
%   targetType - String specifying target geometry type
%
% Outputs:
%   obj - Geometry object of specified type
%
% Notes:
%   - Faces are automatically converted to double for compatibility
%   - Patch objects are created in an invisible figure by default
%   - For patch objects with visible figures, use patch() directly
%   - Graph objects include node coordinates as properties (X, Y, Z)
%   - Graph edge weights: 'geometry' uses Euclidean lengths, 'fem' uses
%     cotangent stiffness, 'uniform' uses equal weights
%
% Examples:
%   % Convert to surfaceMesh
%   M = bct.Manifold(V, F);
%   smesh = bct.manifold.out(M, 'surfaceMesh');
%
%   % Convert to triangulation
%   tri = bct.manifold.out(M, 'triangulation');
%
%   % Convert to patch (in invisible figure)
%   p = bct.manifold.out(M, 'patch');
%
%   % Convert to MATLAB graph with geometric edge weights
%   G = bct.manifold.out(M, 'graph');
%
%   % Convert to MATLAB graph with FEM edge weights
%   G = bct.manifold.out(M, 'graph', 'EdgeWeights', 'fem');
%
% See also: bct.Manifold, bct.manifold.in, bct.manifold.convert

arguments
    M          bct.Manifold
    targetType (1,1) string {mustBeMember(targetType, ["surfaceMesh", "triangulation", "patch", "graph"])}
    options.EdgeWeights (1,1) string {mustBeMember(options.EdgeWeights, ["geometry", "fem", "uniform"])} = "geometry"
end

% Get vertices and faces from Manifold
V = M.Vertices;
F = M.Faces;

% Convert faces to double (required by all target types)
F = double(F);

% Dispatch based on target type
switch targetType
    case "surfaceMesh"
        % Create surfaceMesh object
        obj = surfaceMesh(V, F);
        
    case "triangulation"
        % Create triangulation object
        obj = triangulation(F, V);
        
    case "patch"
        % Create patch object in invisible figure
        fig = figure('Visible', 'off');
        obj = patch('Faces', F, 'Vertices', V);
        
        % Store figure handle in patch UserData for cleanup
        obj.UserData.Figure = fig;
        
    case "graph"
        % Create MATLAB graph object with edge weights
        E = M.Edges;
        N = size(V, 1);
        
        % Compute edge weights based on requested metric
        switch options.EdgeWeights
            case "geometry"
                % Geometric weights: Euclidean edge lengths
                geom = M.geometry();
                w = geom.edgeLengths;
                
            case "fem"
                % FEM weights: Extract from cotangent stiffness matrix
                ops = M.operators();
                K = ops.stiffness;
                i = E(:,1);
                j = E(:,2);
                w = -K(sub2ind(size(K), i, j));
                w(w < 0) = 0;  % numerical safety
                
            case "uniform"
                % Uniform weights: all edges have weight 1
                w = ones(size(E, 1), 1);
        end
        
        % Create weighted MATLAB graph
        obj = graph(E(:,1), E(:,2), full(w), N);
        
        % Attach coordinates as node properties
        obj.Nodes.X = V(:,1);
        obj.Nodes.Y = V(:,2);
        obj.Nodes.Z = V(:,3);
        
    otherwise
        error('bct:manifold:UnsupportedTargetType', ...
            'Unsupported target type: %s', targetType);
end

end
