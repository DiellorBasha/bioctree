function tf = isTimeVarying(F)
%ISTIMEVARYING Check if Field is time-varying
%
% TF = ISTIMEVARYING(F) returns true if Field F contains time-varying data
%
% A field is considered time-varying if:
%   - scalar/complexScalar: size(value, 2) > 1
%   - vector3/tangent2/complexVector3: ndims(value) == 3
%
% Examples:
%   % Static scalar field
%   F = bct.field.make('support', 'vertex', ...
%                       'valueType', 'scalar', ...
%                       'value', rand(1000, 1));
%   bct.field.isTimeVarying(F)  % false
%
%   % Time-varying scalar field
%   F = bct.field.make('support', 'vertex', ...
%                       'valueType', 'scalar', ...
%                       'value', rand(1000, 100));
%   bct.field.isTimeVarying(F)  % true

arguments
    F struct
end

% Validate input
if ~isfield(F, 'value') || ~isfield(F, 'valueType')
    error('bct:Field:InvalidField', ...
        'Field must have value and valueType fields');
end

valueType = string(F.valueType);

switch valueType
    case {"scalar", "complexScalar"}
        tf = size(F.value, 2) > 1;
        
    case {"vector3", "tangent2", "complexVector3"}
        tf = ndims(F.value) == 3;
        
    otherwise
        error('bct:Field:InvalidValueType', ...
            'Unknown valueType: %s', F.valueType);
end

end
