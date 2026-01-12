function F = fromStruct(S)
%FROMSTRUCT Create Field from plain struct (deserialization helper)
%
% F = FROMSTRUCT(S) creates Field from plain struct S
%
% Validates the struct and returns a properly formed Field.
% Useful after loading from disk or receiving from external sources.
%
% Examples:
%   S = load('field.mat');
%   F = bct.field.fromStruct(S);

arguments
    S struct
end

% Validate the input struct
bct.field.validate(S);

% Return validated Field (already a struct)
F = S;

% Future: could add deserialization transforms here
% - Convert string to char for consistency
% - Handle legacy schema versions
% - Migrate old field names

end
