function validate(k)
%BCT.KERNEL.VALIDATE  Validate kernel definition struct

required = {'Name','NumParams','ParamNames','DefaultParams','ParamRanges','Function'};
for i = 1:numel(required)
    if ~isfield(k, required{i})
        error('bct:kernel:InvalidKernel', ...
            'Kernel is missing required field: %s', required{i});
    end
end

if k.NumParams ~= numel(k.ParamNames)
    error('bct:kernel:InvalidKernel', ...
        'NumParams does not match ParamNames.');
end
end
