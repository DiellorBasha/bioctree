function timeNorm = normalizeTime_(time, numSamples)
%NORMALIZETIME_ Normalize time struct with default/inferred fields
%
% Private helper for bct.fields.make

arguments
    time struct
    numSamples (1,1) double
end

% Start with input
timeNorm = time;

% Ensure t0 exists
if ~isfield(timeNorm, 't0')
    timeNorm.t0 = 0.0;
end

% Ensure dt exists
if ~isfield(timeNorm, 'dt')
    timeNorm.dt = 1.0;
end

% Ensure unit exists
if ~isfield(timeNorm, 'unit')
    timeNorm.unit = 's';
end

% Convert string to char
if isstring(timeNorm.unit)
    timeNorm.unit = char(timeNorm.unit);
end

% Generate samples if missing
if ~isfield(timeNorm, 'samples')
    timeNorm.samples = timeNorm.t0 + (0:numSamples-1) * timeNorm.dt;
else
    % Ensure samples is row vector
    if ~isrow(timeNorm.samples)
        timeNorm.samples = timeNorm.samples(:)';
    end
end

% Validate consistency
if length(timeNorm.samples) ~= numSamples
    error('bct:Field:InconsistentTimeField', ...
        'time.samples length (%d) must match value time dimension (%d)', ...
        length(timeNorm.samples), numSamples);
end

% Ensure t0 and dt are consistent with samples if provided
if isfield(time, 'samples')
    expectedSamples = timeNorm.t0 + (0:numSamples-1) * timeNorm.dt;
    if max(abs(timeNorm.samples - expectedSamples)) > 1e-10
        % Recompute t0 and dt from samples
        timeNorm.t0 = timeNorm.samples(1);
        if numSamples > 1
            timeNorm.dt = mean(diff(timeNorm.samples));
        else
            timeNorm.dt = 1.0;
        end
    end
end

end
