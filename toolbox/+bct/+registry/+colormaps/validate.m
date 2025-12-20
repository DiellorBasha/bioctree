function validate(defs)
%BCT.REGISTRY.COLORMAPS.VALIDATE  Validate colormap registry definitions
%
%   bct.registry.colormaps.validate(defs)
%
% Purpose
%   Enforces schema compliance and invariants for colormap registry.
%   Must error (not warn) for any violations.
%
% Inputs
%   defs - struct array from bct.registry.colormaps.defs()
%
% Validation Rules
%   - All required fields present
%   - All Id values unique
%   - Provider in allowed set ("matlab" | "bct")
%   - Kind in allowed set ("sequential"|"diverging"|"cyclic"|"categorical")
%   - DefaultN is positive integer
%
% See also: bct.registry.colormaps.schema, bct.registry.colormaps.defs

    arguments
        defs struct
    end
    
    % Empty registry is valid
    if isempty(defs)
        return;
    end
    
    S = bct.registry.colormaps.schema();
    
    % Check all entries have required fields
    entryFields = string(fieldnames(defs));
    missingFields = setdiff(S.RequiredFields, entryFields);
    assert(isempty(missingFields), 'bct:registry:colormaps:MissingFields', ...
        'Registry entries missing required fields: %s', strjoin(missingFields, ', '));
    
    % Check for duplicate IDs
    ids = [defs.Id];
    [uniqueIds, ~, ic] = unique(ids);
    if numel(uniqueIds) < numel(ids)
        counts = accumarray(ic, 1);
        duplicates = uniqueIds(counts > 1);
        error('bct:registry:colormaps:DuplicateIds', ...
            'Duplicate colormap Ids found: %s', strjoin(duplicates, ', '));
    end
    
    % Validate each entry using schema validator
    for i = 1:numel(defs)
        try
            S.ValidateEntry(defs(i));
        catch ME
            error('bct:registry:colormaps:EntryValidationFailed', ...
                'Validation failed for entry %d (Id=%s): %s', ...
                i, defs(i).Id, ME.message);
        end
    end
end
