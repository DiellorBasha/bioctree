function validateTime_(time, numSamples)
%VALIDATETIME_ Validate time struct fields and consistency
%
% Private helper for bct.fields.validate

arguments
    time struct
    numSamples (1,1) double
end

% Required fields
requiredFields = ["t0", "dt", "unit"];
for i = 1:length(requiredFields)
    if ~isfield(time, requiredFields(i))
        error('bct:Field:MissingTimeField', ...
            'time struct missing required field: %s', requiredFields(i));
    end
end

% Validate t0
if ~isscalar(time.t0) || ~isnumeric(time.t0) || ~isreal(time.t0)
    error('bct:Field:InvalidTimeField', ...
        'time.t0 must be real numeric scalar');
end

% Validate dt
if ~isscalar(time.dt) || ~isnumeric(time.dt) || ~isreal(time.dt)
    error('bct:Field:InvalidTimeField', ...
        'time.dt must be real numeric scalar');
end
if time.dt <= 0
    error('bct:Field:InvalidTimeField', ...
        'time.dt must be positive, got %g', time.dt);
end

% Validate unit
if ~(ischar(time.unit) || isstring(time.unit))
    error('bct:Field:InvalidTimeField', ...
        'time.unit must be char or string');
end
if isstring(time.unit)
    time.unit = char(time.unit);
end

% Optional: validate samples field if present
if isfield(time, 'samples')
    if ~isvector(time.samples) || ~isnumeric(time.samples) || ~isreal(time.samples)
        error('bct:Field:InvalidTimeField', ...
            'time.samples must be real numeric vector');
    end
    
    % Check consistency with numSamples
    if length(time.samples) ~= numSamples
        error('bct:Field:InconsistentTimeField', ...
            'time.samples length (%d) must match value time dimension (%d)', ...
            length(time.samples), numSamples);
    end
    
    % Check consistency with t0 and dt
    expectedSamples = time.t0 + (0:numSamples-1) * time.dt;
    if ~isequal(size(time.samples), size(expectedSamples))
        time.samples = time.samples(:)';
    end
    if max(abs(time.samples - expectedSamples)) > 1e-10
        warning('bct:Field:InconsistentTimeField', ...
            'time.samples not consistent with t0 + (0:T-1)*dt');
    end
end

end
