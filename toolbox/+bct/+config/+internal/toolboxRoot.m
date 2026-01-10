function root = toolboxRoot()
%TOOLBOXROOT Determine BCT toolbox root directory
%
% Computes the toolbox root by walking up from this function's location.
% Works in both development and packaged installations.
%
% Returns:
%   root - Absolute path to BCT toolbox root
%
% File hierarchy:
%   root/
%     toolbox/
%       +bct/
%         +config/
%           +internal/
%             toolboxRoot.m  <- we are here

% Get location of this file
thisFile = mfilename('fullpath');

% Walk up the directory tree
internalDir = fileparts(thisFile);     % .../+bct/+config/+internal
configPkgDir = fileparts(internalDir); % .../+bct/+config
bctPkgDir = fileparts(configPkgDir);   % .../+bct
toolboxDir = fileparts(bctPkgDir);     % .../toolbox
root = fileparts(toolboxDir);          % root

end
