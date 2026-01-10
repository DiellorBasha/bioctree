function spec = fieldSignature(varargin)
%FIELDSIGNATURE Create Field signature struct for operator registry
%
% Syntax:
%   sig = bct.registry.operators.fieldSignature(Name, Value, ...)
%
% Name-Value Arguments:
%   kind        - "Field" (default) or "Raw" for legacy support
%   support     - Support type: "vertex"|"face"|"edge"|"halfedge"|"dualFace"|"dualVertex"
%   valueType   - Value type: "scalar"|"vector3"|"tangent2"|"complexScalar"|"complexVector3"
%   time        - Time policy: "preserve"|"require"|"optional"|"drop"|"align"
%                 preserve: output inherits input time (default)
%                 require: input must be time-varying
%                 optional: accept static or time-varying
%                 drop: output is always static
%                 align: multiple inputs must have aligned time
%   framePolicy - Frame policy: "none"|"requiredForTangent2"|"requiresInputFrame"|"producesFrame"
%   optional    - logical, whether this input is optional (default: false)
%
% Returns:
%   spec - Field signature struct
%
% Examples:
%   % Scalar vertex input
%   input = bct.registry.operators.fieldSignature(...
%       'support', 'vertex', 'valueType', 'scalar');
%
%   % Vector face output with preserved time
%   output = bct.registry.operators.fieldSignature(...
%       'support', 'face', 'valueType', 'vector3', 'time', 'preserve');
%
%   % Tangent field requiring frame
%   input = bct.registry.operators.fieldSignature(...
%       'support', 'vertex', 'valueType', 'tangent2', ...
%       'framePolicy', 'requiresInputFrame');
%
% See also: bct.registry.operators.defs, bct.fields.schema

arguments (Repeating)
    varargin
end

% Parse name-value pairs
p = inputParser;
p.addParameter('kind', 'Field', @(x) ismember(x, {'Field', 'Raw'}));
p.addParameter('support', '', @(x) ischar(x) || isstring(x));
p.addParameter('valueType', '', @(x) ischar(x) || isstring(x));
p.addParameter('time', 'preserve', @(x) ismember(x, {'preserve', 'require', 'optional', 'drop', 'align'}));
p.addParameter('framePolicy', 'none', @(x) ismember(x, {'none', 'requiredForTangent2', 'requiresInputFrame', 'producesFrame'}));
p.addParameter('optional', false, @islogical);

p.parse(varargin{:});
args = p.Results;

% Build signature struct
spec = struct();
spec.kind = char(args.kind);

if strcmp(spec.kind, 'Field')
    spec.support = char(args.support);
    spec.valueType = char(args.valueType);
    spec.time = char(args.time);
    spec.framePolicy = char(args.framePolicy);
    spec.optional = args.optional;
    
    % Validate support
    if ~isempty(spec.support)
        schema = bct.fields.schema();
        if ~ismember(string(spec.support), schema.supports)
            error('bct:registry:InvalidSupport', ...
                'Invalid support: %s', spec.support);
        end
    end
    
    % Validate valueType
    if ~isempty(spec.valueType)
        schema = bct.fields.schema();
        if ~ismember(string(spec.valueType), schema.valueTypes)
            error('bct:registry:InvalidValueType', ...
                'Invalid valueType: %s', spec.valueType);
        end
    end
end

end
