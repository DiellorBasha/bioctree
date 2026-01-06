function newId = resolveAlias(oldId)
%RESOLVEALIAS Map deprecated operator IDs to new hierarchical IDs
%
% Syntax:
%   newId = bct.runtime.operators.resolveAlias(oldId)
%
% Inputs:
%   oldId - Old operator ID (e.g., "dec_gradient")
%
% Returns:
%   newId - New hierarchical ID (e.g., "gradient.dec"), or empty if no alias
%
% This function supports backward compatibility for one release cycle.
% Deprecated IDs will be removed in a future version.
%
% See also: bct.runtime.operators.dictionary

arguments
    oldId (1,1) string
end

% Persistent warning tracker to warn once per session
persistent warnedIds;
if isempty(warnedIds)
    warnedIds = string.empty;
end

% Define alias map: old → new
aliasMap = dictionary(...
    ["dec_gradient", "dec_divergence", "dec_curl", "dec_laplacian", "dec_hhd", ...
     "fem_gradient", "fem_divergence"], ...
    ["gradient.dec", "divergence.dec", "curl.dec", "laplacian.dec", "hhd.dec", ...
     "gradient.fem", "divergence.fem"]);

% Check if old ID has an alias
if isKey(aliasMap, oldId)
    newId = aliasMap(oldId);
    
    % Warn once per ID per session
    if ~ismember(oldId, warnedIds)
        warning('bct:DeprecatedOperatorId', ...
            ['Operator ID "%s" is deprecated. Use "%s" instead. ' ...
             'Old IDs will be removed in a future version.'], ...
            oldId, newId);
        warnedIds(end+1) = oldId;
    end
else
    % No alias found
    newId = string.empty;
end

end
