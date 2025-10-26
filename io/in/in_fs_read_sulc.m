function [sulc, fnum] = in_fs_read_sulc(fname)

% in_fs_read_sulc - FreeSurfer I/O function to read an sulc file
%
% This function is based on freesurfer_read_sulc from the bioelectromagnetism 
% toolbox (https://eeg.sourceforge.net/bioelectromagnetism.html)
% Original code by Darren L. Weber and contributors.
%
% [sulc, fnum] = in_fs_read_sulc(fname)
% 
% reads a binary sulc file into a vector
%
% After reading an associated surface, with in_fs_read_surf, try:
% patch('vertices',vert,'faces',face,...
%       'facecolor','interp','edgecolor','none',...
%       'FaceVertexCData',sulc); light
% 
% See also in_fs_read_curv, in_fs_read_surf, in_fs_read_wfile


% This is just a wrapper, the .sulc format is the same as a .curv format

[sulc, fnum] = in_fs_read_curv(fname);

return