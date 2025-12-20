function style = mergeStyle(style, varargin)
%BCT.UI.MANIFOLD.MERGESTYLE  Merge section overrides into a style struct

    if mod(numel(varargin),2) ~= 0
        error("bct:ui:manifold:InvalidOverrides", "Overrides must be Name-Value pairs.");
    end

    for i = 1:2:numel(varargin)
        key = string(varargin{i});
        val = varargin{i+1};

        if ~isstruct(val)
            error("bct:ui:manifold:InvalidOverrideType", ...
                "Override '%s' must be a struct.", key);
        end

        if ~isfield(style, key)
            error("bct:ui:manifold:UnknownOverrideKey", ...
                "Unknown override key '%s'.", key);
        end

        style.(key) = localMergeStruct(style.(key), val);
    end
end

function a = localMergeStruct(a, b)
    f = fieldnames(b);
    for k = 1:numel(f)
        name = f{k};
        if isfield(a, name) && isstruct(a.(name)) && isstruct(b.(name))
            a.(name) = localMergeStruct(a.(name), b.(name));
        else
            a.(name) = b.(name);
        end
    end
end
