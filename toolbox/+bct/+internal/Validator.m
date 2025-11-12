classdef Validator
methods(Static)
  function report = validateSkeleton(fn, M)
    ok=true; msgs=string.empty(0,1);
    root=h5info(fn,"/"); present=string({root.Attributes.Name});
    req=string(M.root_attributes_required);
    miss=setdiff(req,present);
    if ~isempty(miss), ok=false; msgs(end+1)="Missing root attrs: "+strjoin(miss,", "); end
    for g = ["/axes","/graph","/signals","/decomp","/filters","/results","/events","/masks","/schema"]
      if ~bct.internal.Util.pathExists(fn,g), ok=false; msgs(end+1)="Missing group: "+g; end
    end
    report=struct('ok',ok,'messages',msgs);
    if ~ok, error("bct:SchemaInvalid","%s",strjoin(msgs,newline)); end
  end
  function report = validateAll(fn, M)
    V=bct.internal.Validator.validateSkeleton(fn,M); %#ok<NASGU>
    ok=true; msgs=string.empty(0,1);
    if bct.internal.Util.pathExists(fn,"/signals/raw")
      s=h5info(fn,"/signals/raw"); T=s.Dataspace.Size(1); N=s.Dataspace.Size(2);
      if bct.internal.Util.pathExists(fn,"/axes/time_s") && numel(h5read(fn,"/axes/time_s"))~=T
        ok=false; msgs(end+1)="time_s length must equal raw T.";
      end
      if bct.internal.Util.pathExists(fn,"/axes/node_id") && numel(h5read(fn,"/axes/node_id"))~=N
        ok=false; msgs(end+1)="node_id length must equal raw N.";
      end
    end
    if bct.internal.Util.pathExists(fn,"/signals/raw_stack")
    sRS = h5info(fn,"/signals/raw_stack");
    L = sRS.Dataspace.Size(1); T = sRS.Dataspace.Size(2); N = sRS.Dataspace.Size(3);
    if ~bct.internal.Util.pathExists(fn,"/axes/layer_id")
        ok=false; msgs(end+1) = "Missing /axes/layer_id for raw_stack.";
    else
        if numel(h5read(fn,"/axes/layer_id")) ~= L
            ok=false; msgs(end+1) = "layer_id length must equal raw_stack L.";
        end
    end
    if bct.internal.Util.pathExists(fn,"/signals/raw")
        sRaw = h5info(fn,"/signals/raw");
        if ~isequal(sRaw.Dataspace.Size, [T N])
            ok=false; msgs(end+1) = "/signals/raw must be (T,N) matching raw_stack's (T,N).";
        end
    end
end

    report=struct('ok',ok,'messages',msgs);
    if ~ok, error("bct:SchemaInvalid","%s",strjoin(msgs,newline)); end
  end
end
end
