function S = manifold(file, options)
%MANIFOLD  Read full manifold workflow from HDF5 file
%
%   S = bct.file.read.manifold(file)
%   S = bct.file.read.manifold(file, Name=Value)
%
% Purpose
%   Single ergonomic entry point for reading a complete manifold workflow
%   from HDF5 file. Orchestrates reading of core mesh data and optional
%   subtrees (geometry, topology, operators, eigenmodes, health).
%
% Inputs
%   file - string, HDF5 file path
%
% Name-Value Arguments
%   Parts     - string array (default ["core"])
%               Subtrees to read. Options:
%               "core" - vertices, faces, edges
%               "geometry" - cached geometry quantities (Phase 3)
%               "topology" - topology data structures (Phase 2)
%               "operators" - differential operators (Phase 2)
%               "eigenmodes" - eigendecomposition (Phase 3)
%               "health" - mesh health metrics (Phase 3)
%   Strict    - logical (default true), enforce validation
%   WithAttrs - logical (default false), include attributes in output
%
% Output
%   S - struct with fields corresponding to requested parts:
%       .core       - vertices, faces, edges struct
%       .geometry   - geometry subtree (if requested, Phase 3)
%       .topology   - topology subtree (if requested, Phase 2)
%       .operators  - operators subtree (if requested, Phase 2)
%       .eigenmodes - eigenmodes subtree (if requested, Phase 3)
%       .health     - health subtree (if requested, Phase 3)
%
% Examples
%   % Read core only (Phase 1)
%   S = bct.file.read.manifold("mesh.h5");
%   V = S.core.vertices;
%   F = S.core.faces;
%
%   % Read core and operators (Phase 2)
%   S = bct.file.read.manifold("mesh.h5", "Parts", ["core", "operators"]);
%
%   % Read everything (Phase 3)
%   S = bct.file.read.manifold("mesh.h5", ...
%       "Parts", ["core", "geometry", "topology", "operators", "eigenmodes", "health"]);
%
% Implementation Status
%   Phase 1: core - IMPLEMENTED
%   Phase 2: topology, operators - TODO
%   Phase 3: geometry, eigenmodes, health - TODO
%
% See also: bct.file.manifold.read.core, bct.file.info, bct.file.validate

arguments
    file (1,1) string
    options.Parts (1,:) string = "core"
    options.Strict (1,1) logical = true
    options.WithAttrs (1,1) logical = false
end

%% Validate file and schema
if ~isfile(file)
    error('bct:file:read:manifold:FileNotFound', ...
        'File "%s" does not exist.', file);
end

if options.Strict
    bct.file.validate(file, "Throw", true);
end

%% Initialize output struct
S = struct();

%% Read requested parts
for part = options.Parts
    switch part
        case "core"
            S.core = bct.file.manifold.read.core(file, "Strict", options.Strict);
            
        case "geometry"
            % Phase 3: TODO
            if bct.file.exists(file, "/manifold/geometry")
                warning('bct:file:read:manifold:NotImplemented', ...
                    'Geometry subtree reading not yet implemented (Phase 3).');
                S.geometry = struct();
            else
                S.geometry = struct();
            end
            
        case "topology"
            % Phase 2: TODO
            if bct.file.exists(file, "/manifold/topology")
                warning('bct:file:read:manifold:NotImplemented', ...
                    'Topology subtree reading not yet implemented (Phase 2).');
                S.topology = struct();
            else
                S.topology = struct();
            end
            
        case "operators"
            % Phase 2: TODO
            if bct.file.exists(file, "/manifold/operators")
                warning('bct:file:read:manifold:NotImplemented', ...
                    'Operators subtree reading not yet implemented (Phase 2).');
                S.operators = struct();
            else
                S.operators = struct();
            end
            
        case "eigenmodes"
            % Phase 3: TODO
            if bct.file.exists(file, "/manifold/eigenmodes")
                warning('bct:file:read:manifold:NotImplemented', ...
                    'Eigenmodes subtree reading not yet implemented (Phase 3).');
                S.eigenmodes = struct();
            else
                S.eigenmodes = struct();
            end
            
        case "health"
            % Phase 3: TODO
            if bct.file.exists(file, "/manifold/health")
                warning('bct:file:read:manifold:NotImplemented', ...
                    'Health subtree reading not yet implemented (Phase 3).');
                S.health = struct();
            else
                S.health = struct();
            end
            
        otherwise
            warning('bct:file:read:manifold:UnknownPart', ...
                'Unknown part "%s" requested. Skipping.', part);
    end
end

end
