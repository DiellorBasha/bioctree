function w = apply(brushName, domain, params)
%BCT.BRUSH.APPLY  Apply a brush by name
%
%   w = bct.brush.apply(brushName, domain, params)
%
%   Inputs
%   ------
%   brushName : string or char
%   domain    : bct.Manifold (for now)
%   params    : struct with brush-specific parameters
%
%   Output
%   ------
%   w         : N×1 weighted selection field (double)

    arguments
        brushName (1,:) char
        domain
        params struct
    end

    R = bct.brush.registry();

    if ~isfield(R, brushName)
        error('bct:brush:UnknownBrush', ...
              'Unknown brush: %s', brushName);
    end

    alg = R.(brushName).Algorithm;

    w = alg(domain, params);

end
