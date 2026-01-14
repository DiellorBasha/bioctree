function out = annotate(out, domain, options)
%ANNOTATE Wrap numeric outputs with unit/dimension annotations
%
% Syntax:
%   out = bct.manifold.metric.annotate(out, domain)
%   out = bct.manifold.metric.annotate(out, domain, 'Strict', false)
%   out = bct.manifold.metric.annotate(out, domain, 'Meta', metaStruct)
%
% Inputs:
%   out    - Structure with numeric fields (from geometry/operator/eigen)
%   domain - String specifying domain: "geometry" | "operator" | "eigen"
%
% Name-Value Arguments:
%   Strict - Enforce spec completeness (default: true)
%            If true, error on missing spec entries
%            If false, leave unspecified fields as numeric
%   Meta   - Additional metadata to inject into all quantities (default: struct())
%
% Outputs:
%   out - Same structure with fields wrapped as quantity structs
%
% Description:
%   Transforms numeric outputs from manifold umbrella functions into
%   unit-aware quantity structures. Each field is looked up in the domain
%   spec and wrapped with SI unit labels and dimension information.
%
%   Quantity structure schema:
%   - .value: Numeric data (unchanged)
%   - .unit: SI unit label string
%   - .dim.Lexp: Length dimension exponent
%   - .meta: Metadata (normalization, method, etc.)
%
% Strictness Policy:
%   In strict mode (default), every field must have a spec entry or
%   the function errors. This prevents unlabeled values from entering
%   the cache and ensures complete dimensional tracking.
%
% Examples:
%   % Annotate geometry outputs
%   geom = bct.manifold.geometry(M);
%   geomAnnotated = bct.manifold.metric.annotate(geom, 'geometry');
%   % geomAnnotated.faceAreas is now a quantity struct:
%   % .value = [numeric areas]
%   % .unit = "m^2"
%   % .dim.Lexp = 2
%
%   % Annotate with custom metadata
%   ops = bct.manifold.operator(M);
%   opsAnnotated = bct.manifold.metric.annotate(ops, 'operator', ...
%       'Meta', struct('method', 'FEM'));
%
%   % Non-strict mode (development)
%   out = bct.manifold.metric.annotate(out, 'geometry', 'Strict', false);
%
% See also: bct.manifold.metric.quantity, bct.manifold.metric.spec

arguments
    out struct
    domain (1,1) string {mustBeMember(domain, ["geometry", "operator", "eigen"])}
    options.Strict (1,1) logical = true
    options.Meta struct = struct()
end

% Load spec for this domain
specMap = bct.manifold.metric.spec(domain);

% Get all field names from output structure
fields = fieldnames(out);

% Iterate and wrap each field
for i = 1:length(fields)
    fname = fields{i};
    
    % Skip 'header' field (metadata, not a quantity)
    if strcmp(fname, 'header')
        continue;
    end
    
    % Check if spec exists for this field
    if specMap.isKey(fname)
        % Get spec
        s = specMap(fname);
        
        % Handle composite structures (like edgeWeights)
        if strcmp(s.unit, "mixed")
            % This is a structure containing sub-quantities
            % Recursively annotate if it's a struct
            if isstruct(out.(fname))
                % Annotate sub-fields based on their types
                subfields = fieldnames(out.(fname));
                for j = 1:length(subfields)
                    subfname = subfields{j};
                    % Edge weights sub-quantities: cotangent and euclidean are both lengths
                    if strcmp(subfname, 'cotangent') || strcmp(subfname, 'euclidean')
                        out.(fname).(subfname) = bct.manifold.metric.quantity(...
                            out.(fname).(subfname), "m", 1, options.Meta);
                    end
                end
            end
        else
            % Merge spec meta with options meta
            combinedMeta = mergeStructs(s.meta, options.Meta);
            
            % Wrap as quantity
            out.(fname) = bct.manifold.metric.quantity(...
                out.(fname), s.unit, s.Lexp, combinedMeta);
        end
    else
        % Field has no spec entry
        if options.Strict
            error('bct:manifold:metric:MissingSpec', ...
                ['No spec entry for field "%s" in domain "%s". ' ...
                 'Add specification to bct.manifold.metric.spec or use Strict=false.'], ...
                fname, domain);
        end
        % In non-strict mode, leave as numeric (no warning for now)
    end
end

end

%% Helper function
function merged = mergeStructs(s1, s2)
    % Merge two structs (s2 fields override s1)
    merged = s1;
    fields2 = fieldnames(s2);
    for i = 1:length(fields2)
        merged.(fields2{i}) = s2.(fields2{i});
    end
end
