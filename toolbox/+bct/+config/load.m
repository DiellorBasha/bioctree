function cfg = load(options)
%LOAD Load BCT configuration
%
% Primary configuration entry point. Computes toolbox paths and loads
% dependency manifest. Works in both development and packaged installations.
%
% Syntax:
%   cfg = bct.config.load()
%   cfg = bct.config.load(Name=Value)
%
% Name-Value Arguments:
%   overrides - struct (default: struct())
%               Override specific config fields
%   validate  - logical (default: true)
%               Validate configuration after loading
%
% Returns:
%   cfg - Configuration struct with fields:
%         root         - BCT toolbox root path
%         packageRoot  - Folder containing +bct package (toolbox/)
%         configRoot   - Config data folder (+bct/+config/data)
%         dataRoot     - Optional data folder
%         examplesRoot - Optional examples folder  
%         docsRoot     - Optional docs folder
%         testsRoot    - Optional tests folder
%         depsManifest - Parsed deps.json manifest
%
% Examples:
%   % Standard usage
%   cfg = bct.config.load();
%   
%   % With overrides
%   cfg = bct.config.load('overrides', struct('dataRoot', '/custom/data'));
%
% See also: bct.config.deps, bct.config.validate, bct.start

arguments
    options.overrides (1,1) struct = struct()
    options.validate (1,1) logical = true
end

% Compute toolbox root
root = bct.config.internal.toolboxRoot();

% Build base configuration
cfg = struct();
cfg.root = root;

% Core paths (these are deterministic, no JSON needed)
cfg.packageRoot = fullfile(root, 'toolbox');

% Config data location
thisFile = mfilename('fullpath');
configPkgDir = fileparts(thisFile);
cfg.configRoot = fullfile(configPkgDir, 'data');

% Optional paths (check if they exist)
optionalPaths = struct(...
    'dataRoot', fullfile(root, 'data'), ...
    'examplesRoot', fullfile(root, 'examples'), ...
    'docsRoot', fullfile(root, 'docs'), ...
    'testsRoot', fullfile(root, 'tests'));

optFields = fieldnames(optionalPaths);
for i = 1:numel(optFields)
    field = optFields{i};
    path = optionalPaths.(field);
    if exist(path, 'dir')
        cfg.(field) = path;
    end
end

% Load dependency manifest
try
    cfg.depsManifest = bct.config.deps();
catch ME
    warning('bct:config:DepsManifestFailed', ...
        'Failed to load deps manifest: %s', ME.message);
    cfg.depsManifest = struct();
end

% Apply overrides
if ~isempty(options.overrides)
    cfg = bct.config.internal.mergeStruct(cfg, options.overrides);
end

% Validate
if options.validate
    bct.config.validate(cfg);
end

end
