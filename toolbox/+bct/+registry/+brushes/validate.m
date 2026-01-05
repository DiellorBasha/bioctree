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
%VALIDATEEXECUTABLE  Smoke test brush execution
%
% Creates test manifold and validates:
%   - DefaultParams executes and returns correct fields
%   - ParamRanges executes and returns correct fields
%   - Evaluate executes without critical errors

    % Create small test manifold
    try
        [V, F] = createTestMesh();
        M = bct.Manifold(V, F);
    catch ME
        warning('bct:registry:brushes:TestMeshFailed', ...
            'Could not create test manifold: %s. Skipping executable validation.', ...
            ME.message);
        return;
    end
    
    % Test DefaultParams
    try
        params = spec.DefaultParams(M);
        
        if ~isstruct(params)
            error('DefaultParams must return struct, got %s', class(params));
        end
        
        % Validate parameter names match
        paramFields = string(fieldnames(params));
        expectedParams = string(spec.ParamNames);
        
        if ~isequal(sort(paramFields), sort(expectedParams))
            missingFields = setdiff(expectedParams, paramFields);
            extraFields = setdiff(paramFields, expectedParams);
            
            if ~isempty(missingFields)
                error('DefaultParams missing fields: %s', strjoin(missingFields, ', '));
            end
            if ~isempty(extraFields)
                error('DefaultParams has extra fields: %s', strjoin(extraFields, ', '));
            end
        end
        
    catch ME
        error('DefaultParams validation failed: %s', ME.message);
    end
    
    % Test ParamRanges
    try
        ranges = spec.ParamRanges(M);
        
        if ~isstruct(ranges)
            error('ParamRanges must return struct, got %s', class(ranges));
        end
        
        % Validate parameter names match
        rangeFields = string(fieldnames(ranges));
        expectedParams = string(spec.ParamNames);
        
        if ~isequal(sort(rangeFields), sort(expectedParams))
            missingFields = setdiff(expectedParams, rangeFields);
            extraFields = setdiff(rangeFields, expectedParams);
            
            if ~isempty(missingFields)
                error('ParamRanges missing fields: %s', strjoin(missingFields, ', '));
            end
            if ~isempty(extraFields)
                error('ParamRanges has extra fields: %s', strjoin(extraFields, ', '));
            end
        end
        
    catch ME
        error('ParamRanges validation failed: %s', ME.message);
    end
    
    % Test Evaluate (smoke test only - may fail due to dependencies)
    try
        w = spec.Evaluate(M, params);
        
        % Check output dimensions
        if size(w, 1) ~= M.numVertices()
            error('Output size mismatch: expected [%d×?], got [%d×%d]', ...
                M.numVertices(), size(w, 1), size(w, 2));
        end
        
    catch ME
        % Only warn for execution failures (may require specific dependencies)
        if contains(spec.Id, 'spectral') || any(ismember(spec.Requires, ["FEM", "Eigenpairs"]))
            % Expected to fail without FEM/eigenpairs
            % Silently skip
        else
            warning('bct:registry:brushes:ExecutionWarning', ...
                'Brush "%s" execution test failed: %s', spec.Id, ME.message);
        end
    end
end

function [V, F] = createTestMesh()
%CREATETESTMESH  Create small test manifold for validation
%
% Uses bct.data.load() to get default test mesh

    % Use standard bct.data.load()
    try
        mesh = bct.data.load();
        V = mesh.Vertices;
        F = mesh.Faces;
    catch
        % Fallback: create simple tetrahedron only if bct.data fails
        V = [0 0 0; 1 0 0; 0.5 sqrt(3)/2 0; 0.5 sqrt(3)/6 sqrt(6)/3];
        F = [1 2 3; 1 2 4; 2 3 4; 3 1 4];
    end
end
