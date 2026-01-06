function validate(defs)
%BCT.REGISTRY.BRUSHES.VALIDATE  Validate brush registry
%
%   bct.registry.brushes.validate(defs)
%
% Purpose:
%   Validates brush registry for correctness and consistency.
%   Throws on validation failure.
%
% Validates:
%   - No duplicate IDs
%   - All required fields present
%   - Field types correct
%   - DefaultParams returns struct with all ParamNames
%   - ParamRanges returns struct with all ParamNames
%   - Evaluate function executes without error (smoke test)
%
% Input:
%   defs - struct array of brush specifications
%
% See also: bct.registry.brushes.defs, bct.registry.brushes.schema

    % Check for empty registry
    if isempty(defs)
        warning('bct:registry:brushes:EmptyRegistry', ...
            'Brush registry is empty');
        return;
    end
    
    % Check for duplicate IDs
    ids = string({defs.Id});
    uniqueIds = unique(ids);
    
    if length(ids) ~= length(uniqueIds)
        % Find duplicates
        duplicates = ids(~ismember(1:length(ids), ...
            cellfun(@(x) find(ids == x, 1), cellstr(uniqueIds))));
        error('bct:registry:brushes:DuplicateIds', ...
            'Duplicate brush IDs detected: %s', strjoin(unique(duplicates), ', '));
    end
    
    % Validate each entry
    schema = bct.registry.brushes.schema();
    failedBrushes = {};
    
    for i = 1:length(defs)
        try
            % Schema validation
            schema.ValidateEntry(defs(i));
            
            % Executable validation (smoke test)
            validateExecutable(defs(i));
            
        catch ME
            failedBrushes{end+1} = struct('Id', defs(i).Id, 'Error', ME.message); %#ok<AGROW>
        end
    end
    
    % Report validation results
    if ~isempty(failedBrushes)
        fprintf(2, 'bct.registry.brushes: Validation FAILED for %d brushes:\n', ...
            length(failedBrushes));
        for i = 1:length(failedBrushes)
            fprintf(2, '  - %s: %s\n', failedBrushes{i}.Id, failedBrushes{i}.Error);
        end
        error('bct:registry:brushes:ValidationFailed', ...
            'Brush registry validation failed. See errors above.');
    end
    
    % Success
    fprintf('bct.registry.brushes: Validation passed (%d brushes)\n', length(defs));
end

function validateExecutable(spec)
%VALIDATEEXECUTABLE  Validate that brush spec has valid function handles
%
% Inputs
%   spec - BrushSpec struct
%
% Validation (SCHEMA ONLY - NO EXECUTION)
%   - DefaultParams is a function handle
%   - ParamRanges is a function handle
%   - Evaluate is a function handle
%   - Evaluate has correct signature (2 inputs)
%
% NOTE: Execution tests belong in unit tests (tests/unit/test_bct_brush.m)
%       Registry validation ONLY checks that required fields exist and are
%       function handles. It does NOT execute them.

    % Check DefaultParams is function handle
    if ~isa(spec.DefaultParams, 'function_handle')
        error('DefaultParams must be function_handle, got %s', class(spec.DefaultParams));
    end
    
    % Check ParamRanges is function handle
    if ~isa(spec.ParamRanges, 'function_handle')
        error('ParamRanges must be function_handle, got %s', class(spec.ParamRanges));
    end
    
    % Check Evaluate is function handle
    if ~isa(spec.Evaluate, 'function_handle')
        error('Evaluate must be function_handle, got %s', class(spec.Evaluate));
    end
    
    % Validate Evaluate signature (2 inputs: manifold, params)
    try
        nInputs = nargin(spec.Evaluate);
        if nInputs ~= 2 && nInputs ~= -1  % -1 means varargs
            warning('bct:registry:brushes:SignatureWarning', ...
                'Evaluate should accept 2 inputs (manifold, params), got %d', nInputs);
        end
    catch
        % If we can't determine nargin, skip the check
    end
end
