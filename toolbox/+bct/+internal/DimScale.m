classdef DimScale
methods(Static)
  function attach(fn, dsetPath, scalePaths, labels)
    fid=H5F.open(fn,'H5F_ACC_RDWR','H5P_DEFAULT');
    dset=H5D.open(fid,dsetPath);
    for i=1:numel(scalePaths)
      sc=H5D.open(fid,scalePaths{i});
      H5DS.set_scale(sc,labels{i});
      H5DS.attach_scale(dset,sc,i-1);
      H5DS.set_label(dset,i-1,labels{i});
      H5D.close(sc);
    end
    H5D.close(dset); H5F.close(fid);
  end
end
end
