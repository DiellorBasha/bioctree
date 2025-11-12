classdef Paths
methods(Static)
  function root = repoRoot()
    % Derive repo root from the location of bioctree_init.m
    % (robust even if called from anywhere)
    here = which('bioctree_init');  % must be on path
    assert(~isempty(here), 'bct:RepoRootNotFound', ...
      'bioctree_init.m not found on path. Run bioctree_init() first.');
    root = fileparts(here);  % bioctree_init.m lives at <repo>/
  end

  function p = dataRoot()
    p = fullfile(bct.internal.Paths.repoRoot(), 'data');
    assert(exist(p,'dir')==7, 'bct:DataRootMissing', ...
      'Expected data root at: %s', p);
  end

  function absfn = underData(outSpec, defaultSubdir)
    % Normalize a user-supplied name or subpath to <repo>/data/<defaultSubdir>/...
    if nargin < 2 || isempty(defaultSubdir), defaultSubdir = ''; end
    data = bct.internal.Paths.dataRoot();

    if contains(outSpec, filesep) || contains(outSpec, '/')
      % If outSpec is absolute and already under data/, keep it; otherwise, rebase under data/
      if isfolder(outSpec) || endsWith(outSpec, filesep)
        error('bct:InvalidOutSpec','Expected a filename, got a directory: %s', outSpec);
      end
      if isabsolute(outSpec)
        if strncmpi(outSpec, data, length(data))
          absfn = outSpec;        % already under /data
        else
          % Rebase absolute paths into /data while preserving the tail filename
          [~,name,ext] = fileparts(outSpec);
          absfn = fullfile(data, defaultSubdir, [name ext]);
        end
      else
        % Relative path: place it under /data
        absfn = fullfile(data, outSpec);
      end
    else
      % Simple basename: place in /data/<defaultSubdir>/
      absfn = fullfile(data, defaultSubdir, outSpec);
    end

    % Ensure parent directory exists
    pdir = fileparts(absfn);
    if ~exist(pdir,'dir'), mkdir(pdir); end
  end
end
end

function tf = isabsolute(p)
% cross-platform absolute path check
if ispc
  tf = ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || strncmp(p,'\\',2);
else
  tf = startsWith(p, filesep);
end
end
