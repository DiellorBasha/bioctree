function merged = mergeStruct(base, overrides)
%MERGESTRUCT Merge two structs with overrides taking precedence
%
% Performs shallow merge where override fields replace base fields.
%
% Inputs:
%   base      - Base struct
%   overrides - Override struct (fields replace base)
%
% Returns:
%   merged - Merged struct

% Start with base
merged = base;

% Apply overrides
if ~isempty(overrides) && isstruct(overrides)
    fields = fieldnames(overrides);
    for i = 1:numel(fields)
        merged.(fields{i}) = overrides.(fields{i});
    end
end

end
