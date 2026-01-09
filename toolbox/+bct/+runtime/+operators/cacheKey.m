function key = cacheKey(spec, context)
%CACHEKEY Generate stable cache key for operator artifact
%
% Syntax:
%   key = bct.runtime.operators.cacheKey(spec, context)
%
% Inputs:
%   spec    - OperatorSpec from registry
%   context - Runtime context struct
%
% Returns:
%   key - string cache key derived from:
%         - Operator ID
%         - Mesh ID or hash
%         - Relevant parameters
%         - Backend version (if available)
%
% The cache key is used to store and retrieve expensive operator assemblies
% (e.g., precomputed matrices) without recomputation.
%
% See also: bct.runtime.operators.bind, bct.runtime.operators.provenance

arguments
    spec struct
    context struct
end

% =========================================================================
% Start with operator ID
% =========================================================================
keyParts = string(spec.id);

% =========================================================================
% Add mesh identifier
% =========================================================================
meshId = "";
if isfield(context, 'Manifold') && ~isempty(context.Manifold)
    M = context.Manifold;
    
    % Try to get mesh ID
    if isprop(M, 'ID') && ~isempty(M.ID)
        meshId = M.ID;
    else
        % Fallback: use mesh dimensions as proxy
        N = M.numVertices();
        F = M.numFaces();
        meshId = sprintf("V%d_F%d", N, F);
    end
end
keyParts(end+1) = meshId;

% =========================================================================
% Add relevant parameters (if any)
% =========================================================================
if isfield(spec, 'parameters') && ~isempty(spec.parameters)
    params = spec.parameters;
    paramFields = fieldnames(params);
    
    % Sort fields for stability
    paramFields = sort(paramFields);
    
    for i = 1:length(paramFields)
        field = paramFields{i};
        value = params.(field);
        
        % Convert value to string representation
        if isnumeric(value)
            valueStr = sprintf("%g", value);
        elseif ischar(value) || isstring(value)
            valueStr = string(value);
        else
            valueStr = class(value);
        end
        
        keyParts(end+1) = sprintf("%s=%s", field, valueStr);
    end
end

% =========================================================================
% Add backend version (if available from dependency)
% =========================================================================
if isfield(spec, 'dependency') && isstruct(spec.dependency)
    dep = spec.dependency;
    if isfield(dep, 'provider')
        provider = dep.provider;
        
        % Try to get version
        try
            verInfo = ver();
            idx = find(strcmp({verInfo.Name}, provider), 1);
            if ~isempty(idx)
                keyParts(end+1) = sprintf("v%s", verInfo(idx).Version);
            end
        catch
            % Ignore version lookup failures
        end
    end
end

% =========================================================================
% Combine parts with separator
% =========================================================================
key = strjoin(keyParts, ":");

end
