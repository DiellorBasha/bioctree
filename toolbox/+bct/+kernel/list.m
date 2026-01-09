function ids = list(opts)
%BCT.KERNEL.LIST  List available kernel identifiers (façade)
%
%   ids = bct.kernel.list()
%   ids = bct.kernel.list(Name=Value)
%
% Options
%   Kind      - Filter by kind (e.g., "smoothing", "wavelet", "window")
%   Tags      - Filter by tags (string array)
%   AxisKinds - Filter by axis kinds (e.g., "lambda", "time")
%
% Output
%   ids - String column vector of kernel identifiers
%
% Usage
%   % List all kernels
%   all_kernels = bct.kernel.list();
%
%   % List only smoothing kernels
%   smoothing = bct.kernel.list(Kind="smoothing");
%
%   % List low-pass kernels
%   lowpass = bct.kernel.list(Tags=["lowpass"]);
%
% Note
%   This is a façade function. For new code, prefer:
%     ids = bct.registry.kernels.list();
%
% See also: bct.registry.kernels.list, bct.kernel.get

arguments
    opts.Kind (1,1) string = ""
    opts.Tags (1,:) string = string.empty
    opts.AxisKinds (1,:) string = string.empty
end

% Get registry
defs = bct.registry.kernels.defs();

% Get all IDs
ids = string({defs.Id}).';

% Filter by kind
if opts.Kind ~= ""
    mask = arrayfun(@(i) defs(i).Kind == opts.Kind, 1:numel(defs));
    ids = ids(mask);
    defs = defs(mask);
end

% Filter by tags
if ~isempty(opts.Tags)
    mask = false(size(ids));
    for i = 1:numel(defs)
        if isfield(defs(i), 'Tags')
            if any(ismember(opts.Tags, defs(i).Tags))
                mask(i) = true;
            end
        end
    end
    ids = ids(mask);
    defs = defs(mask);
end

% Filter by axis kinds
if ~isempty(opts.AxisKinds)
    mask = false(size(ids));
    for i = 1:numel(defs)
        if isfield(defs(i), 'AxisKinds')
            if any(ismember(opts.AxisKinds, defs(i).AxisKinds))
                mask(i) = true;
            end
        end
    end
    ids = ids(mask);
end

end
