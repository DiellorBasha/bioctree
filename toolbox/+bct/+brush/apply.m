function w = apply(brushName, domain, params)
%BCT.BRUSH.APPLY  Apply a brush by name
%
%   w = bct.brush.apply(brushName, domain, params)
%
%   Inputs
%   ------
%   brushName : string or char - brush identifier
%   domain    : bct.Manifold
%   params    : struct with brush-specific parameters
%
%   Output
%   ------
%   w         : N×1 or N×T weighted selection field (double)
%
%   Note: Now uses bct.runtime.brushes for dispatch (preferred).
%         Falls back to legacy registry if runtime fails.
%
%   See also: bct.runtime.brushes.resolve, bct.registry.brushes

    arguments
        brushName (1,:) char
        domain
        params struct
    end

    % Primary path: Use runtime dispatch
    try
        context = struct('manifold', domain, 'params', params);
        spec = bct.runtime.brushes.resolve(brushName, context);
        
        % Execute brush with resolved parameters
        w = spec.Evaluate(domain, spec.DefaultParamsResolved);
        return;
        
    catch ME
        % If runtime fails, try legacy path
        if ~contains(ME.identifier, 'bct:runtime:brushes')
            % Re-throw if not a runtime error
            rethrow(ME);
        end
        
        % Log fallback (only in verbose mode)
        if ~isempty(getenv('BCT_VERBOSE'))
            warning('bct:brush:apply:FallingBackToLegacy', ...
                'Runtime dispatch failed: %s. Using legacy registry.', ME.message);
        end
    end

    % Legacy path: Use old registry (backward compatibility)
    R = bct.brush.registry();

    if ~isfield(R, brushName)
        error('bct:brush:UnknownBrush', ...
              'Unknown brush: %s', brushName);
    end

    alg = R.(brushName).Algorithm;
    w = alg(domain, params);

end
