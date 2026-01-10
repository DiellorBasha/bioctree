function S = schema()
%BCT.REGISTRY.COLORMAPS.SCHEMA  Schema definition for colormap registry entries
%
%   S = bct.registry.colormaps.schema()
%
% Purpose
%   Returns declarative specification of required/optional fields and
%   invariant checks for colormap registry entries.
%
% Output
%   S - struct with fields:
%       RequiredFields   (string array): must be present in every entry
%       OptionalFields   (string array): may be present
%       AllowedProviders (string array): valid Provider values
%       AllowedKinds     (string array): valid Kind values
%       ValidateEntry    (function_handle): @(entry)->mustPassOrError
%
% See also: bct.registry.colormaps.validate, bct.registry.colormaps.defs

    S = struct();
    
    % Required fields
    S.RequiredFields = [ ...
        "Id", ...
        "Provider", ...
        "Kind", ...
        "DefaultN" ...
    ];
    
    % Optional fields
    S.OptionalFields = [ ...
        "Tags", ...
        "Notes" ...
    ];
    
    % Allowed Provider values
    S.AllowedProviders = [ ...
        "matlab", ...
        "bct" ...
    ];
    
    % Allowed Kind values
    S.AllowedKinds = [ ...
        "sequential", ...
        "diverging", ...
        "cyclic", ...
        "categorical" ...
    ];
    
    % Entry-level validator
    S.ValidateEntry = @validateEntry;
end

function validateEntry(entry)
    % Validates a single colormap registry entry
    % Throws error if validation fails
    
    S = bct.registry.colormaps.schema();
    
    % Check Id
    mustBeTextScalar(entry.Id);
    assert(strlength(entry.Id) > 0, 'bct:registry:colormaps:EmptyId', ...
        'Colormap Id must be non-empty');
    
    % Check Provider
    mustBeTextScalar(entry.Provider);
    mustBeMember(entry.Provider, S.AllowedProviders);
    
    % Check Kind
    mustBeTextScalar(entry.Kind);
    mustBeMember(entry.Kind, S.AllowedKinds);
    
    % Check DefaultN
    mustBeNumeric(entry.DefaultN);
    assert(isscalar(entry.DefaultN) && entry.DefaultN > 0 && mod(entry.DefaultN, 1) == 0, ...
        'bct:registry:colormaps:InvalidDefaultN', ...
        'DefaultN must be positive integer for colormap %s', entry.Id);
    
    % Validate optional fields if present
    if isfield(entry, 'Tags')
        mustBeText(entry.Tags);
    end
    
    if isfield(entry, 'Notes')
        mustBeTextScalar(entry.Notes);
    end
end
