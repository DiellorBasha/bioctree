function validateSupport_(support, schema)
%VALIDATESUPPORT_ Validate support field
%
% Private helper for bct.fields.validate

arguments
    support
    schema struct
end

% Check type
if ~isstring(support) && ~ischar(support)
    error('bct:Field:InvalidSupport', ...
        'support must be string or char');
end

support = string(support);

% Check is scalar
if ~isscalar(support)
    error('bct:Field:InvalidSupport', ...
        'support must be scalar string');
end

% Check is valid support type
if ~ismember(support, schema.supports)
    error('bct:Field:InvalidSupport', ...
        'Unsupported support type: %s. Valid: %s', ...
        support, strjoin(schema.supports, ", "));
end

end
