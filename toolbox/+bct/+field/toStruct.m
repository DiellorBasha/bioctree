function S = toStruct(F)
%TOSTRUCT Convert Field to plain struct (serialization helper)
%
% S = TOSTRUCT(F) converts Field F to plain struct for serialization
%
% This is primarily a pass-through since Field is already a struct,
% but can be used for future serialization enhancements or to ensure
% all nested structures are plain structs.
%
% Examples:
%   S = bct.field.toStruct(F);
%   save('field.mat', '-struct', 'S');

arguments
    F struct
end

% Validate input
bct.field.validate(F);

% For now, just return a copy (Field is already a struct)
S = F;

% Future: could add serialization transforms here
% - Convert char to string for JSON compatibility
% - Add serialization metadata
% - Flatten nested structures

end
