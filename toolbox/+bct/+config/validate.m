function validate(cfg)
%VALIDATE Validate BCT configuration struct
%
% Checks that required fields exist and directories are valid.
%
% Inputs:
%   cfg - Configuration struct from bct.config.load
%
% Throws error if validation fails.
%
% See also: bct.config.load

% Required fields
requiredFields = {'root', 'packageRoot', 'configRoot'};

for i = 1:numel(requiredFields)
    field = requiredFields{i};
    if ~isfield(cfg, field)
        error('bct:config:MissingField', ...
            'Configuration missing required field: %s', field);
    end
end

% Validate paths exist
pathFields = {'root', 'packageRoot', 'configRoot'};

for i = 1:numel(pathFields)
    field = pathFields{i};
    path = cfg.(field);
    
    if ~ischar(path) && ~isstring(path)
        error('bct:config:InvalidType', ...
            'Field %s must be a string, got %s', field, class(path));
    end
    
    if ~exist(path, 'dir')
        error('bct:config:PathNotFound', ...
            'Path for %s does not exist: %s', field, path);
    end
end

% Validate depsManifest if present
if isfield(cfg, 'depsManifest')
    if ~isstruct(cfg.depsManifest)
        error('bct:config:InvalidDepsManifest', ...
            'depsManifest must be a struct');
    end
end

end
