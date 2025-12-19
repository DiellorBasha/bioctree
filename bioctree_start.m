function bioctree_start()
% BIOCTREE_START [DEPRECATED] Use bct_start() instead
%
% This function is deprecated and will be removed in a future release.
% Please use bct_start() for BCT package initialization.
%
% See also: bct_start

warning('bioctree:Deprecated', ...
    ['bioctree_start is deprecated. Use bct_start() instead.\n' ...
     'The old bioctree_* naming has been replaced with bct_* naming.\n' ...
     'Please update your startup scripts to call bct_start()']);

fprintf('\n╔══════════════════════════════════════════════════════════╗\n');
fprintf('║  DEPRECATED: Please use bct_start() instead              ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

% Call the new initialization script
bct_start();

end
