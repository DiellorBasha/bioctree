function out = bct_list_groups_datasets(schemaPath)
% out = bct_schema_groups_datasets(schemaPath)
% Reads a bct JSON schema and returns a struct array with:
%   out(i).group       -> top-level group path (e.g. "/signal")
%   out(i).attributes  -> string array of attribute names on that group
%   out(i).datasets    -> string array of dataset paths within that group's subtree
%
% Notes:
% - Only top-level groups are listed (keys of root "groups").
% - Attributes are NOT inherited; we only list attributes declared on the group itself.
% - Datasets are collected recursively from any nested subgroups under the group.

    txt = fileread(schemaPath);
    S   = jsondecode(txt);

    if ~isfield(S, "groups") || ~isstruct(S.groups)
        out = struct('group', strings(0,1), 'attributes', strings(0,1), 'datasets', strings(0,1));
        return
    end

    topGroups = string(fieldnames(S.groups));
    out = repmat(struct('group',"", 'attributes',strings(0,1), 'datasets',strings(0,1)), numel(topGroups), 1);

    for i = 1:numel(topGroups)
        gname = topGroups(i);
        gobj  = S.groups.(gname);
        out(i).group = gname;

        % attributes ON THIS GROUP (not recursive)
        if isfield(gobj, "attributes") && isstruct(gobj.attributes)
            out(i).attributes = string(fieldnames(gobj.attributes));
        else
            out(i).attributes = strings(0,1);
        end

        % datasets UNDER THIS GROUP (recursive through nested subgroups)
        ds = collectDatasetsUnderGroup(gobj);
        out(i).datasets = unique(string(ds(:)));
    end
end

function ds = collectDatasetsUnderGroup(gobj)
% Return a cell array of dataset paths found in this group object recursively.
    ds = {};
    if isfield(gobj, "datasets") && isstruct(gobj.datasets)
        ds = [ds; fieldnames(gobj.datasets)]; %#ok<AGROW>
    end
    if isfield(gobj, "groups") && isstruct(gobj.groups)
        subNames = fieldnames(gobj.groups);
        for k = 1:numel(subNames)
            subObj = gobj.groups.(subNames{k});
            ds = [ds; collectDatasetsUnderGroup(subObj)]; %#ok<AGROW>
        end
    end
end
