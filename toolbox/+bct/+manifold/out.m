function obj = out(M, targetType, options)
%OUT Convert bct.Manifold to MATLAB geometry object
%
% Syntax:
%   obj = bct.manifold.out(M, 'surfaceMesh')
%   obj = bct.manifold.out(M, 'triangulation')
%   obj = bct.manifold.out(M, 'patch')
%   obj = bct.manifold.out(M, 'graph')
%   obj = bct.manifold.out(M, 'graph', 'EdgeWeights', 'geometry')
%   obj = bct.manifold.out(M, 'gspbox')
%   obj = bct.manifold.out(M, 'gspbox', 'EdgeWeights', 'cotangent', 'LaplacianType', 'normalized')
%
% Supported Target Types:
%   - 'surfaceMesh': Creates MATLAB surfaceMesh object
%   - 'triangulation': Creates MATLAB triangulation object
%   - 'patch': Creates MATLAB Patch graphics object (in invisible figure)
%   - 'graph': Creates MATLAB graph object with edge weights
%   - 'gspbox': Creates GSPBox graph structure for graph signal processing
%
% Name-Value Arguments (for 'graph' and 'gspbox'):
%   EdgeWeights   - "cotangent" (default) | "euclidean"
%   LaplacianType - "combinatorial" (default) | "normalized" | "randomwalk" (gspbox only)
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
%   - GSPBox graphs are populated with gsp_graph_default_parameters()
%   - Edge weights: 'cotangent' uses FEM stiffness, 'euclidean' uses geometric lengths
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
%   % Convert to MATLAB graph with cotangent edge weights
%   G = bct.manifold.out(M, 'graph');
%
%   % Convert to GSPBox graph with normalized Laplacian
%   G = bct.manifold.out(M, 'gspbox', 'LaplacianType', 'normalized');
%
% See also: bct.Manifold, bct.manifold.in, bct.manifold.convert

arguments
    M          bct.Manifold
    targetType (1,1) string {mustBeMember(targetType, ["surfaceMesh", "triangulation", "patch", "graph", "gspbox"])}
    options.EdgeWeights (1,1) string {mustBeMember(options.EdgeWeights, ["cotangent", "euclidean"])} = "cotangent"
    options.LaplacianType (1,1) string {mustBeMember(options.LaplacianType, ["combinatorial", "normalized", "randomwalk"])} = "combinatorial"
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
        
        % Get edge weights from cached geometry
        geom = M.geometry();
        w = geom.edgeWeights.(options.EdgeWeights);
        
        % Create weighted MATLAB graph
        obj = graph(E(:,1), E(:,2), full(w), N);
        
        % Attach coordinates as node properties
        obj.Nodes.X = V(:,1);
        obj.Nodes.Y = V(:,2);
        obj.Nodes.Z = V(:,3);
        
    case "gspbox"
        % Create GSPBox graph structure
        E = M.Edges;
        N = size(V, 1);
        
        % Get edge weights from cached geometry
        geom = M.geometry();
        w = geom.edgeWeights.(options.EdgeWeights);
        
        % Build sparse symmetric adjacency matrix
        W = sparse(E(:,1), E(:,2), w, N, N);
        W = W + W.';  % ensure symmetry
        
        % Build GSP structure
        obj = struct();
        obj.N = N;
        obj.W = W;
        obj.coords = V;
        obj.type = char(options.LaplacianType);
        
        % Let GSPBox populate operators lazily
        obj = gsp_graph_default_parameters(obj);
        
    otherwise
        error('bct:manifold:UnsupportedTargetType', ...
            'Unsupported target type: %s', targetType);
end

end
