function manifest = readManifest()
%READMANIFEST Load dependency manifest via bct.config
%
% Delegates to bct.config.deps() for authoritative manifest.

try
    manifest = bct.config.deps();
catch ME
    error('bct:install:ManifestNotFound', ...
        'Failed to load dependency manifest: %s\n\nReinstall BCT or check installation integrity.', ...
        ME.message);
end

end
