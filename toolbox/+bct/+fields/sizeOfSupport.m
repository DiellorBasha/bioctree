function n = sizeOfSupport(support, M)
%SIZEOFSUPPORT Compute cardinality of a discrete support on manifold
%
% Syntax:
%   n = bct.fields.sizeOfSupport(support, M)
%
% Inputs:
%   support - Support type string: "vertex"|"face"|"edge"|"halfedge"|"dualFace"|"dualVertex"
%   M       - bct.Manifold object
%
% Returns:
%   n - Integer cardinality of support
%
% Support Definitions:
%   vertex    - Number of vertices in mesh
%   face      - Number of triangular faces
%   edge      - Number of unique edges
%   halfedge  - 3 * numFaces (each triangle has 3 halfedges)
%   dualFace  - Number of vertices (dual cells around vertices)
%   dualVertex - Number of faces (dual vertices at face centers)
%
% Examples:
%   M = bct.Manifold(V, F);
%   nV = bct.fields.sizeOfSupport("vertex", M);
%   nF = bct.fields.sizeOfSupport("face", M);
%   nHE = bct.fields.sizeOfSupport("halfedge", M);
%
% See also: bct.fields.make, bct.fields.validate

arguments
    support (1,1) string
    M (1,1) bct.Manifold
end

switch support
    case "vertex"
        n = M.numVertices();
        
    case "face"
        n = M.numFaces();
        
    case "edge"
        n = M.numEdges();
        
    case "halfedge"
        % Each triangular face has 3 halfedges
        n = 3 * M.numFaces();
        
    case "dualFace"
        % Dual faces correspond to vertices (dual cells around each vertex)
        n = M.numVertices();
        
    case "dualVertex"
        % Dual vertices correspond to primal faces (dual vertex at face center)
        n = M.numFaces();
        
    otherwise
        error('bct:Field:InvalidSupport', ...
            'Unknown support type: %s', support);
end

end
