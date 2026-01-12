function Fout = selectTime(F, timeIndices)
%SELECTTIME Extract temporal subset of time-varying Field
%
% FOUT = SELECTTIME(F, timeIndices) extracts time samples from Field F
%
% Arguments:
%   F            - Time-varying Field struct
%   timeIndices  - Vector of time indices to extract (1-based)
%
% Returns:
%   Fout - New Field struct with selected time samples
%
% If the result has only one time sample, the output becomes static
% (time dimension removed, time field removed).
%
% Examples:
%   % Extract first 10 time points
%   Fout = bct.field.selectTime(F, 1:10);
%
%   % Extract single snapshot (becomes static)
%   Fsnap = bct.field.selectTime(F, 50);
%
%   % Extract every other sample
%   Fdown = bct.field.selectTime(F, 1:2:100);

arguments
    F struct
    timeIndices (:,1) double {mustBeInteger, mustBePositive}
end

% Check if time-varying
if ~bct.field.isTimeVarying(F)
    error('bct:Field:NotTimeVarying', ...
        'Field is not time-varying; cannot select time samples');
end

% Copy input
Fout = F;

valueType = string(F.valueType);
numSelected = length(timeIndices);

% Extract time samples based on valueType
switch valueType
    case {"scalar", "complexScalar"}
        % [S×T] -> [S×Tsel]
        maxT = size(F.value, 2);
        if any(timeIndices > maxT)
            error('bct:Field:InvalidTimeIndex', ...
                'Time index out of range [1, %d]', maxT);
        end
        Fout.value = F.value(:, timeIndices);
        
    case {"vector3", "tangent2", "complexVector3"}
        % [S×D×T] -> [S×D×Tsel]
        maxT = size(F.value, 3);
        if any(timeIndices > maxT)
            error('bct:Field:InvalidTimeIndex', ...
                'Time index out of range [1, %d]', maxT);
        end
        Fout.value = F.value(:, :, timeIndices);
        
        % Handle frame for tangent2
        if valueType == "tangent2" && isfield(F, 'frame')
            Fout.frame = F.frame(:, :, :, timeIndices);
        end
end

% Update time field
if isfield(F, 'time')
    if numSelected == 1
        % Single sample: remove time field (becomes static)
        Fout = rmfield(Fout, 'time');
        
        % Squeeze value to remove singleton dimension
        switch valueType
            case {"scalar", "complexScalar"}
                % Already [S×1], no squeeze needed
            case {"vector3", "tangent2", "complexVector3"}
                % [S×D×1] -> [S×D]
                Fout.value = squeeze(Fout.value);
                if valueType == "tangent2" && isfield(Fout, 'frame')
                    Fout.frame = squeeze(Fout.frame);
                end
        end
    else
        % Multiple samples: update time metadata
        Fout.time.samples = F.time.samples(timeIndices);
        Fout.time.t0 = Fout.time.samples(1);
        
        % Recompute dt if uniformly spaced
        if numSelected > 1
            diffs = diff(Fout.time.samples);
            if max(abs(diffs - diffs(1))) < 1e-10
                Fout.time.dt = diffs(1);
            else
                % Non-uniform: keep original dt as nominal value
                warning('bct:Field:NonUniformSampling', ...
                    'Selected time samples are not uniformly spaced');
            end
        end
    end
end

% Validate result
bct.field.validate(Fout);

end
