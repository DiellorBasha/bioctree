function prov = provenance(spec, context)
%PROVENANCE Generate provenance metadata for operator artifact
%
% Syntax:
%   prov = bct.runtime.operators.provenance(spec, context)
%
% Inputs:
%   spec    - OperatorSpec from registry
%   context - Runtime context struct
%
% Returns:
%   prov - struct with fields:
%          bctVersion       - BCT toolbox version string
%          createdAt        - datetime of operator creation
%          specId           - Operator ID from spec
%          specHash         - Hash of spec struct (for reproducibility)
%          contextSummary   - Summary of mesh/context dimensions
%          dependencyVersions - External dependency version info
%
% Provenance metadata enables tracking of operator origins and ensures
% reproducibility of results.
%
% See also: bct.runtime.operators.bind, bct.runtime.operators.cacheKey

arguments
    spec struct
    context struct
end

% =========================================================================
% BCT version (placeholder - would come from version file or git)
% =========================================================================
bctVersion = "dev";  % TODO: Read from version file if it exists

% =========================================================================
% Creation timestamp
% =========================================================================
createdAt = datetime('now');

% =========================================================================
% Spec ID and hash
% =========================================================================
specId = spec.id;

% Compute stable hash of spec struct
% Use DataHash if available, otherwise use simple struct2str hash
try
    % Try to use DataHash from toolbox_general or similar
    specHash = DataHash(spec);
catch
    % Fallback: simple hash based on ID and function name
    if isfield(spec, 'function') && ~isempty(spec.function)
        funcStr = func2str(spec.function);
    else
        funcStr = "";
    end
    specHash = sprintf("%s_%s", spec.id, funcStr);
end

% =========================================================================
% Context summary (mesh dimensions)
% =========================================================================
contextSummary = struct();

if isfield(context, 'Manifold') && ~isempty(context.Manifold)
    M = context.Manifold;
    contextSummary.numVertices = M.numVertices();
    contextSummary.numFaces = M.numFaces();
    
    if ismethod(M, 'numEdges')
        contextSummary.numEdges = M.numEdges();
    end
    
    % Check which representations are available
    contextSummary.hasDEC = isfield(context, 'DEC') || exist("DiscreteExteriorCalculus", "class") == 8;
    contextSummary.hasFEM = isfield(context, 'FEM');
    contextSummary.hasGraph = isfield(context, 'Graph');
end

% =========================================================================
% Dependency versions (external toolboxes)
% =========================================================================
dependencyVersions = struct();

if isfield(spec, 'dependency') && isstruct(spec.dependency)
    dep = spec.dependency;
    
    % Try to get version info for the provider
    if isfield(dep, 'provider')
        provider = dep.provider;
        
        % Try ver() command
        try
            verInfo = ver();
            idx = find(strcmp({verInfo.Name}, provider), 1);
            if ~isempty(idx)
                dependencyVersions.(provider) = verInfo(idx).Version;
            end
        catch
            % ver() may not work for all toolboxes
        end
        
        % For file-based toolboxes, could check for version.txt or similar
        % This is provider-specific and would need custom logic
    end
end

% =========================================================================
% Assemble provenance struct
% =========================================================================
prov = struct(...
    'bctVersion', bctVersion, ...
    'createdAt', createdAt, ...
    'specId', specId, ...
    'specHash', specHash, ...
    'contextSummary', contextSummary, ...
    'dependencyVersions', dependencyVersions);

end
