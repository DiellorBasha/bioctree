function S = schema()
%SCHEMA  BCT manifold HDF5 schema specification
%
%   S = bct.file.manifold.schema()
%
% Purpose
%   Returns the canonical HDF5 schema specification for BCT manifold files.
%   Documents required attributes, groups, and datasets.
%
% Output
%   S - struct with schema information:
%       .version      - schema version string
%       .root_attrs   - required root attributes
%       .manifold_attrs - required /manifold attributes
%       .index_base   - indexing convention
%
% Schema Overview
%   Root attributes:
%     - schema: "bct.manifold.h5@1"
%     - created_utc: ISO8601 timestamp
%     - bct_version: (optional) BCT toolbox version
%     - manifold_id: (optional) manifold identifier
%
%   /manifold attributes:
%     - units_length: "m" (canonical SI)
%     - index_base_faces: 1 (MATLAB convention)
%     - index_base_edges: 1 (MATLAB convention)
%     - edges_present: 1 (default)
%     - coordinate_system: (optional) e.g., "RAS"
%
%   Core datasets:
%     /manifold/vertices  [N×3] double
%     /manifold/faces     [F×3] int32/uint32
%     /manifold/edges     [E×2] int32/uint32 (optional)
%
%   Subtree groups:
%     /manifold/geometry
%     /manifold/topology
%     /manifold/operators
%     /manifold/eigenmodes
%     /manifold/health
%
% Examples
%   S = bct.file.manifold.schema();
%   fprintf("Schema version: %s\n", S.version);
%
% See also: bct.file.create, bct.file.validate, bct.file.manifold.paths

S = struct();

% Schema version
S.version = "bct.manifold.h5@1";

% Root attributes
S.root_attrs = struct( ...
    'schema', "bct.manifold.h5@1", ...
    'created_utc', "ISO8601 timestamp", ...
    'bct_version', "(optional) string", ...
    'manifold_id', "(optional) string");

% /manifold attributes
S.manifold_attrs = struct( ...
    'units_length', "m", ...
    'index_base_faces', int32(1), ...
    'index_base_edges', int32(1), ...
    'edges_present', int32(1), ...
    'coordinate_system', "(optional) string");

% Indexing convention
S.index_base = struct( ...
    'faces', int32(1), ...
    'edges', int32(1), ...
    'sparse_csc', int32(0));  % Note: sparse arrays use 0-based

% Core dataset specifications
S.core_datasets = struct( ...
    'vertices', struct('path', "/manifold/vertices", 'shape', "[N×3]", 'type', "double"), ...
    'faces', struct('path', "/manifold/faces", 'shape', "[F×3]", 'type', "int32/uint32"), ...
    'edges', struct('path', "/manifold/edges", 'shape', "[E×2]", 'type', "int32/uint32", 'required', false));

% Subtree groups
S.subtrees = [ ...
    "/manifold/geometry"; ...
    "/manifold/topology"; ...
    "/manifold/operators"; ...
    "/manifold/eigenmodes"; ...
    "/manifold/health"];

end
