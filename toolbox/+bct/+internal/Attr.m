classdef Attr
methods(Static)
  function write(fn, objPath, name, val)
    % Normalize common types for HDF5 attributes
    if islogical(val)
      val = uint8(val);                     % logical -> uint8(0/1)
    elseif isstring(val)
      val = char(val);                      % string -> char
    elseif isstruct(val)
      val = jsonencode(val);                % struct -> JSON string
    elseif isnumeric(val)                   % ok as-is
      % noop
    else
      % fallback to string
      val = char(string(val));
    end
    h5writeatt(fn, objPath, name, val);
  end
end
end