function P = paths()
%PATHS  Canonical HDF5 paths for BCT manifold schema
%
%   P = bct.file.manifold.paths()
%
% Purpose
%   Returns a struct containing canonical HDF5 paths for manifold data
%   according to BCT HDF5 schema conventions.
%
% Output
%   P - struct with path fields
%
% Path Structure
%   P.manifold     = "/manifold"
%   P.vertices     = "/manifold/vertices"
%   P.faces        = "/manifold/faces"
%   P.edges        = "/manifold/edges"
%   P.geometry     = "/manifold/geometry"
%   P.topology     = "/manifold/topology"
%   P.operators    = "/manifold/operators"
%   P.eigenmodes   = "/manifold/eigenmodes"
%   P.health       = "/manifold/health"
%   
%   Common leaf paths:
%   P.halfedge     = "/manifold/topology/halfedge"
%   P.adjacency    = "/manifold/topology/adjacency"
%   P.eigenvalues  = "/manifold/eigenmodes/eigenvalues"
%   P.eigenvectors = "/manifold/eigenmodes/eigenvectors"
%
% Examples
%   P = bct.file.manifold.paths();
%   V = bct.file.read(file, P.vertices);
%
% See also: bct.file.manifold.read.core, bct.file.manifold.schema

% Root and subtrees
P.manifold = "/manifold";

% Core datasets
P.vertices = "/manifold/vertices";
P.faces = "/manifold/faces";
P.edges = "/manifold/edges";

% Subtree groups
P.geometry = "/manifold/geometry";
P.topology = "/manifold/topology";
P.operators = "/manifold/operators";
P.eigenmodes = "/manifold/eigenmodes";
P.health = "/manifold/health";

% Common leaf paths
P.halfedge = "/manifold/topology/halfedge";
P.adjacency = "/manifold/topology/adjacency";
P.eigenvalues = "/manifold/eigenmodes/eigenvalues";
P.eigenvectors = "/manifold/eigenmodes/eigenvectors";

end
