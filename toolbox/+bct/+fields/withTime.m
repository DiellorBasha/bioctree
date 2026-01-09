function Fout = withTime(F, timeStruct)
%WITHTIME Update time metadata for time-varying Field
%
% FOUT = WITHTIME(F, timeStruct) updates time metadata of Field F
%
% Arguments:
%   F          - Time-varying Field struct
%   timeStruct - New time struct with fields: t0, dt, unit, samples
%
% The function validates that timeStruct is consistent with the number
% of time samples in F.value, normalizes the struct, and returns a new
% Field with updated time metadata.
%
% Examples:
%   % Update time units
%   Fout = bct.fields.withTime(F, struct('t0', 0, 'dt', 0.001, 'unit', 's'));
%
%   % Change time origin
%   Fout = bct.fields.withTime(F, struct('t0', -0.5, 'dt', 0.01, 'unit', 's'));

arguments
    F struct
    timeStruct struct
end

% Check if time-varying
if ~bct.fields.isTimeVarying(F)
    error('bct:Field:NotTimeVarying', ...
        'Field is not time-varying; cannot update time metadata');
end

% Determine number of time samples
valueType = string(F.valueType);
switch valueType
    case {"scalar", "complexScalar"}
        numSamples = size(F.value, 2);
    case {"vector3", "tangent2", "complexVector3"}
        numSamples = size(F.value, 3);
end

% Normalize and validate time struct
timeNorm = normalizeTime_(timeStruct, numSamples);

% Copy input and update time
Fout = F;
Fout.time = timeNorm;

% Validate result
bct.fields.validate(Fout);

end
