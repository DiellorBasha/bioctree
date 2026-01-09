function [factory, def] = resolveInspector(obj, options)
%BCT.RUNTIME.UI.RESOLVEINSPECTOR  Resolve object to inspector factory
%
%   [factory, def] = bct.runtime.ui.resolveInspector(obj)
%   [factory, def] = bct.runtime.ui.resolveInspector(obj, Name, Value, ...)
%
% Purpose
%   Runtime dispatch layer that selects appropriate inspector for given object.
%   Used by bct.ui.show() and bct.ui.viewer().
%
% Inputs
%   obj - Object to be visualized (bct.Manifold, struct, etc.)
%
% Name-Value Arguments
%   InspectorId  - string, override automatic selection
%   Priority     - double, minimum priority threshold (default: 0)
%
% Outputs
%   factory - function_handle @(parent)->inspector_instance
%   def     - struct, registry entry that was selected
%
% Selection Algorithm
%   1. If InspectorId provided, select by Id
%   2. Otherwise, find all inspectors that support obj's class
%   3. Sort by Priority (descending)
%   4. Return factory for highest priority match
%
% Errors
%   - bct:runtime:ui:NoInspector if no matching inspector found
%   - bct:runtime:ui:UnknownInspectorId if specified Id doesn't exist
%   - bct:runtime:ui:ClassNotFound if inspector class doesn't exist
%
% See also: bct.registry.ui.inspectors, bct.ui.show

    arguments
        obj
        options.InspectorId (1,1) string = ""
        options.Priority (1,1) double = 0
    end
    
    % Get registry
    defs = bct.registry.ui.inspectors();
    
    if isempty(defs)
        error('bct:runtime:ui:EmptyRegistry', ...
            'Inspector registry is empty. Check bct.registry.ui.inspectors().');
    end
    
    % Override selection by Id if provided
    if options.InspectorId ~= ""
        idx = find([defs.Id] == options.InspectorId, 1);
        if isempty(idx)
            error('bct:runtime:ui:UnknownInspectorId', ...
                'Unknown inspector ID: "%s". Available: %s', ...
                options.InspectorId, strjoin([defs.Id], ', '));
        end
        def = defs(idx);
        factory = buildFactory(def);
        return;
    end
    
    % Automatic selection by class match
    objClass = class(obj);
    
    % Find matching inspectors
    matches = false(size(defs));
    for i = 1:numel(defs)
        if any(ismember(defs(i).Supports, objClass))
            matches(i) = true;
        end
    end
    
    % Filter by priority threshold
    if any(matches)
        matchedDefs = defs(matches);
        priorities = [matchedDefs.Priority];
        aboveThreshold = priorities >= options.Priority;
        matchedDefs = matchedDefs(aboveThreshold);
    else
        matchedDefs = [];
    end
    
    if isempty(matchedDefs)
        error('bct:runtime:ui:NoInspector', ...
            ['No inspector found for class "%s".\n' ...
             'Available inspectors:\n%s\n' ...
             'Try passing "InspectorId" explicitly.'], ...
            objClass, formatInspectorList(defs));
    end
    
    % Sort by priority (descending)
    [~, sortIdx] = sort([matchedDefs.Priority], 'descend');
    def = matchedDefs(sortIdx(1));
    
    % Build factory
    factory = buildFactory(def);
end

function factory = buildFactory(def)
    % Convert class name to factory function
    % Factory signature: @(parent) -> inspector_instance
    
    className = char(def.Class);
    
    % Verify class exists
    try
        metacls = meta.class.fromName(className);
        if isempty(metacls)
            error('Class not found: %s', className);
        end
    catch ME
        error('bct:runtime:ui:ClassNotFound', ...
            'Inspector class "%s" (Id=%s) not found: %s', ...
            className, def.Id, ME.message);
    end
    
    % Build factory
    factory = @(parent) feval(className, parent);
end

function str = formatInspectorList(defs)
    % Format inspector list for error messages
    lines = cell(numel(defs), 1);
    for i = 1:numel(defs)
        supports = strjoin(defs(i).Supports, ', ');
        lines{i} = sprintf('  %s: supports [%s]', defs(i).Id, supports);
    end
    str = strjoin(lines, newline);
end
