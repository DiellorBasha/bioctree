classdef Util
methods(Static)
  function ensureGroup(fn, path)
    if ~bct.internal.Util.pathExists(fn, path)
      fid=H5F.open(fn,'H5F_ACC_RDWR','H5P_DEFAULT');
      gid=H5G.create(fid,path,0); H5G.close(gid); H5F.close(fid);
    end
  end
  function tf = pathExists(fn, path)
    try, h5info(fn,path); tf=true; catch, tf=false; end
  end
  function u = uuid4()
    bytes = randi([0 255],[16 1],'uint8');
    u = sprintf('%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x', bytes);
  end
end
end
