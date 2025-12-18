function tf = hasTimeData(filename)
%HASTIMEDATA Check if HDF5 file contains Time domain data
%
%   tf = bct.io.hasTimeData(filename)
%
% Inputs:
%   filename - Path to HDF5 file
%
% Outputs:
%   tf - true if /time group exists, false otherwise
%
% Example:
%   if bct.io.hasTimeData('my_analysis.h5')
%       fprintf('Time domain data present\n');
%   end

try
  info = h5info(filename);
  tf = any(strcmp({info.Groups.Name}, '/time'));
catch
  tf = false;
end

end
