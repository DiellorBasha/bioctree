function Fout = cast(F, targetClass)
%CAST Convert Field value to different numeric type
%
% FOUT = CAST(F, targetClass) converts Field values to target numeric class
%
% Arguments:
%   F           - Field struct
%   targetClass - Target class: 'single', 'double', etc.
%
% Returns new Field with value cast to targetClass. Preserves all other
% properties including time, frame, and metadata.
%
% Examples:
%   % Convert to single precision
%   Fsingle = bct.fields.cast(F, 'single');
%
%   % Convert to double precision
%   Fdouble = bct.fields.cast(F, 'double');

arguments
    F struct
    targetClass char {mustBeMember(targetClass, {'single', 'double', 'int8', 'int16', 'int32', 'int64', 'uint8', 'uint16', 'uint32', 'uint64'})}
end

% Copy input
Fout = F;

% Cast value
Fout.value = cast(F.value, targetClass);

% Cast frame if present
if isfield(F, 'frame')
    Fout.frame = cast(F.frame, targetClass);
end

% Validate result
bct.fields.validate(Fout);

end
