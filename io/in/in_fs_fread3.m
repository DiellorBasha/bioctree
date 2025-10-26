function [retval] = in_fs_fread3(fid)

% in_fs_fread3 - read a 3 byte integer out of a file
% 
% This function is based on freesurfer_fread3 from the bioelectromagnetism 
% toolbox (https://eeg.sourceforge.net/bioelectromagnetism.html)
% Original code by Darren L. Weber and contributors.
%
% [retval] = in_fs_fread3(fid)
%
% see also in_fs_write3, in_fs_read_surf, in_fs_write_surf
% 

b1 = fread(fid, 1, 'uchar') ;
b2 = fread(fid, 1, 'uchar') ;
b3 = fread(fid, 1, 'uchar') ;
retval = bitshift(b1, 16) + bitshift(b2,8) + b3 ;