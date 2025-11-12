classdef Schema
methods(Static)
  function M = loadFrozenManifest()
    base = fileparts(mfilename('fullpath'));
    jsonPath = fullfile(base(1:strfind(base,'+bct')+3),'schema','bct-core-1.0.0.json');
    M = jsondecode(fileread(jsonPath));
  end
  function writeSkeleton(fn, M)
     if ~isfile(fn)
    fid = H5F.create(fn,'H5F_ACC_TRUNC','H5P_DEFAULT','H5P_DEFAULT'); H5F.close(fid);
    end
     for g = ["/axes","/graph","/signals","/decomp","/filters","/results","/events","/masks","/schema"]
      bct.internal.Util.ensureGroup(fn, g);
    end
    h5writeatt(fn,'/','datatype','bct');
    h5writeatt(fn,'/','schema_name',M.schema_name);
    h5writeatt(fn,'/','schema_version',M.schema_version);
    h5writeatt(fn,'/','indexing','zero_based');
    h5writeatt(fn,'/','uuid', bct.internal.Util.uuid4());
    h5writeatt(fn,'/','created_utc', datestr(datetime('now','TimeZone','UTC'),'yyyy-mm-ddTHH:MM:SSZ'));
    h5create(fn,'/schema/manifest_json',[1 1],'Datatype','string');
    h5write(fn,'/schema/manifest_json', string(jsonencode(M)));
  end
  function M = readManifest(fn)
    M = jsondecode(char(h5read(fn,'/schema/manifest_json')));
  end
end
end
