function validate(defs)
%BCT.REGISTRY.KERNELS.VALIDATE  Validate kernel registry definitions
%
%   bct.registry.kernels.validate(defs)
%
% Purpose
%   Enforces schema compliance and invariants for kernel registry.
%   Must error (not warn) for any violations.
%
% Inputs
%   defs - struct array from bct.registry.kernels.defs()
%
% Validation Rules
%   - All required fields present
%   - All Id values unique
%   - ParamNames unique within each entry
%   - DefaultParams(axis) returns struct with all ParamNames
%   - ParamRanges(axis) returns struct with all ParamNames
%   - Evaluate(x,p) executes without error on sample axis
%   - Kind and AxisKinds values from allowed sets
%
% Contract
%   Registry must never silently accept invalid entries.
%   Validation errors must be actionable (include Id in message).
%
% See also: bct.registry.kernels.schema, bct.registry.kernels.defs

    arguments
        defs struct
    end
    
    % Empty registry is valid
    if isempty(defs)
        return;
    end
    
    S = bct.registry.kernels.schema();
    
    % Check all entries have required fields
    entryFields = string(fieldnames(defs));
    missingFields = setdiff(S.RequiredFields, entryFields);
    assert(isempty(missingFields), 'bct:registry:kernels:MissingFields', ...
        'Registry entries missing required fields: %s', strjoin(missingFields, ', '));
    
    % Check for duplicate IDs
    ids = [defs.Id];
    [uniqueIds, ~, ic] = unique(ids);
    if numel(uniqueIds) < numel(ids)
        counts = accumarray(ic, 1);
        duplicates = uniqueIds(counts > 1);
        error('bct:registry:kernels:DuplicateIds', ...
            'Duplicate kernel Ids found: %s', strjoin(duplicates, ', '));
    end
    
    % Validate each entry using schema validator
    for i = 1:numel(defs)
        try
            S.ValidateEntry(defs(i));
        catch ME
            error('bct:registry:kernels:EntryValidationFailed', ...
                'Validation failed for entry %d (Id=%s): %s', ...
                i, defs(i).Id, ME.message);
        end
    end
end
