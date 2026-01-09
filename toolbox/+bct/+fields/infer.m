function F = infer(support, value, varargin)
%INFER Convenient Field constructor with type inference
%
% F = INFER(support, value) creates Field struct inferring valueType from value shape
%
% F = INFER(support, value, Name, Value, ...) additionally accepts optional arguments
%
% Arguments:
%   support - Support type: 'vertex', 'face', 'edge', etc.
%   value   - Numeric array (shape determines valueType)
%
% Optional Name-Value Arguments:
%   meshId   - Mesh identifier
%   time     - Time struct
%   frame    - Frame basis (if valueType inferred as tangent2)
%   metadata - Metadata struct
%
% Value Type Inference Rules:
%   [S×1] or [S×T]         -> scalar
%   [S×3] or [S×3×T]       -> vector3 (if real), complexVector3 (if complex)
%   [S×2] or [S×2×T]       -> tangent2 (requires frame)
%   Complex [S×1]/[S×T]    -> complexScalar
%
% Examples:
%   % Infer scalar field
%   F = bct.fields.infer('vertex', rand(1000, 1));
%
%   % Infer time-varying vector field
%   F = bct.fields.infer('face', rand(500, 3, 100), ...
%                        'time', struct('dt', 0.01, 'unit', 's'));
%
%   % Infer tangent field
%   F = bct.fields.infer('vertex', rand(1000, 2), ...
%                        'frame', rand(1000, 2, 3));

arguments
    support {mustBeTextScalar}
    value {mustBeNumeric}
end

arguments (Repeating)
    varargin
end

% Parse optional arguments
p = inputParser;
p.addParameter('meshId', '', @(x) ischar(x) || isstring(x));
p.addParameter('time', struct([]), @isstruct);
p.addParameter('frame', [], @isnumeric);
p.addParameter('metadata', struct(), @isstruct);
p.parse(varargin{:});
opts = p.Results;

% Infer valueType from value shape
sz = size(value);
nd = ndims(value);
isComplex = ~isreal(value);

if nd == 2
    % Static field
    if sz(2) == 1
        % [S×1]
        valueType = 'scalar';
        if isComplex
            valueType = 'complexScalar';
        end
    elseif sz(2) == 2
        % [S×2] - assume tangent2
        valueType = 'tangent2';
        if isempty(opts.frame)
            error('bct:Field:MissingFrame', ...
                'frame required for [S×2] tangent field; provide frame or use make()');
        end
    elseif sz(2) == 3
        % [S×3]
        valueType = 'vector3';
        if isComplex
            valueType = 'complexVector3';
        end
    else
        % [S×T] - assume time-varying scalar
        valueType = 'scalar';
        if isComplex
            valueType = 'complexScalar';
        end
    end
    
elseif nd == 3
    % Time-varying field [S×D×T]
    if sz(2) == 2
        % [S×2×T] - tangent2
        valueType = 'tangent2';
        if isempty(opts.frame)
            error('bct:Field:MissingFrame', ...
                'frame required for [S×2×T] tangent field; provide frame or use make()');
        end
    elseif sz(2) == 3
        % [S×3×T]
        valueType = 'vector3';
        if isComplex
            valueType = 'complexVector3';
        end
    else
        error('bct:Field:AmbiguousShape', ...
            'Cannot infer valueType from shape [%s]; use make() with explicit valueType', ...
            sprintf('%d×', sz));
    end
    
else
    error('bct:Field:InvalidShape', ...
        'Value must be 2D or 3D; got %dD', nd);
end

% Build arguments for make()
makeArgs = {'support', support, ...
            'valueType', valueType, ...
            'value', value};

if ~isempty(opts.meshId)
    makeArgs = [makeArgs, {'meshId', opts.meshId}];
end

if ~isempty(opts.time)
    makeArgs = [makeArgs, {'time', opts.time}];
end

if ~isempty(opts.frame)
    makeArgs = [makeArgs, {'frame', opts.frame}];
end

if ~isempty(fieldnames(opts.metadata))
    makeArgs = [makeArgs, {'metadata', opts.metadata}];
end

% Create Field using make()
F = bct.fields.make(makeArgs{:});

end
