function validateValue_(value, valueType, support, supportSize, schema)
%VALIDATEVALUE_ Validate value field shape and type
%
% Private helper for bct.fields.validate

arguments
    value
    valueType string
    support string
    supportSize (1,1) double
    schema struct
end

% Check value is numeric
if ~isnumeric(value)
    error('bct:Field:InvalidValueType', ...
        'value must be numeric array');
end

% Check first dimension matches support size
S = size(value, 1);
if S ~= supportSize
    error('bct:Field:InvalidValueShape', ...
        'value first dimension (%d) must match support cardinality (%d) for %s', ...
        S, supportSize, support);
end

% Validate shape based on valueType
switch valueType
    case "scalar"
        % [S×1] or [S×T]
        if size(value, 2) < 1
            error('bct:Field:InvalidValueShape', ...
                'scalar field must have at least one sample: [S×1] or [S×T]');
        end
        if ndims(value) > 2
            error('bct:Field:InvalidValueShape', ...
                'scalar field must be 2D: [S×T], got %dD', ndims(value));
        end
        
    case "vector3"
        % [S×3] or [S×3×T]
        if size(value, 2) ~= 3
            error('bct:Field:InvalidValueShape', ...
                'vector3 field requires size(...,2)==3, got %d', size(value, 2));
        end
        if ndims(value) > 3
            error('bct:Field:InvalidValueShape', ...
                'vector3 field must be 2D or 3D: [S×3] or [S×3×T], got %dD', ndims(value));
        end
        
    case "tangent2"
        % [S×2] or [S×2×T]
        if size(value, 2) ~= 2
            error('bct:Field:InvalidValueShape', ...
                'tangent2 field requires size(...,2)==2, got %d', size(value, 2));
        end
        if ndims(value) > 3
            error('bct:Field:InvalidValueShape', ...
                'tangent2 field must be 2D or 3D: [S×2] or [S×2×T], got %dD', ndims(value));
        end
        
    case "complexScalar"
        % [S×1] or [S×T], must be complex
        if isreal(value)
            error('bct:Field:InvalidValueType', ...
                'complexScalar field must have complex values');
        end
        if ndims(value) > 2
            error('bct:Field:InvalidValueShape', ...
                'complexScalar field must be 2D: [S×T], got %dD', ndims(value));
        end
        
    case "complexVector3"
        % [S×3×T], must be complex
        if isreal(value)
            error('bct:Field:InvalidValueType', ...
                'complexVector3 field must have complex values');
        end
        if size(value, 2) ~= 3
            error('bct:Field:InvalidValueShape', ...
                'complexVector3 field requires size(...,2)==3, got %d', size(value, 2));
        end
        if ndims(value) > 3
            error('bct:Field:InvalidValueShape', ...
                'complexVector3 field must be 2D or 3D: [S×3×T], got %dD', ndims(value));
        end
        
    otherwise
        error('bct:Field:InvalidValueType', ...
            'Unknown valueType: %s', valueType);
end

end
