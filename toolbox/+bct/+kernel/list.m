function ids = list(opts)
%BCT.KERNEL.LIST List available kernel identifiers
%
% Syntax:
%   ids = bct.kernel.list()
%   ids = bct.kernel.list(Name=Value)
%
% Options:
%   Category  - Filter by category (e.g., "kernel", "window")
%   Tags      - Filter by tags (string array)
%   AxisKinds - Filter by axis kinds (e.g., "lambda", "time")
%
% Outputs:
%   ids - String array of kernel identifiers
%
% Description:
%   Lists kernel identifiers from the registry, optionally filtered
%   by category, tags, or axis kinds.
%
% Example:
%   % List all kernels
%   all_kernels = bct.kernel.list();
%
%   % List only spectral kernels
%   spectral = bct.kernel.list(Category="kernel");
%
%   % List low-pass kernels
%   lowpass = bct.kernel.list(Tags=["lowpass"]);
%
% See also: bct.kernel.get, bct.registry.kernels

arguments
    opts.Category (1,1) string = ""
    opts.Tags (1,:) string = string.empty
    opts.AxisKinds (1,:) string = string.empty
end

% Get registry
registry = bct.registry.kernels();

% Get all IDs
ids = string({registry.Id});

% Filter by category
if opts.Category ~= ""
    mask = arrayfun(@(i) registry(i).Category == opts.Category, 1:numel(registry));
    ids = ids(mask);
    registry = registry(mask);
end

% Filter by tags
if ~isempty(opts.Tags)
    mask = false(size(ids));
    for i = 1:numel(registry)
        if isfield(registry(i), 'Tags')
            if any(ismember(opts.Tags, registry(i).Tags))
                mask(i) = true;
            end
        end
    end
    ids = ids(mask);
    registry = registry(mask);
end

% Filter by axis kinds
if ~isempty(opts.AxisKinds)
    mask = false(size(ids));
    for i = 1:numel(registry)
        if isfield(registry(i), 'AxisKinds')
            if any(ismember(opts.AxisKinds, registry(i).AxisKinds))
                mask(i) = true;
            end
        end
    end
    ids = ids(mask);
end

end
