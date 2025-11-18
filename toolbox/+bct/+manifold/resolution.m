function R = resolution(x, inputType, scope)
%SPATIAL_RESOLUTION Convert between lambda, frequency and wavelength.
%
%   R = bct.util.spatial_resolution(x, inputType)
%   R = bct.util.spatial_resolution(M, 'manifold', scope)
%
%   INPUTS
%   ------
%   Case 1: numeric input
%       x         : numeric array (scalar or vector)
%       inputType : 'lambda', 'wavelength', or 'freq'
%
%           'lambda'     : x is Laplacian eigenvalue(s) [1/m^2]
%           'wavelength' : x is wavelength(s) [m]
%           'freq'       : x is spatial frequency [cycles/m]
%
%   Case 2: Manifold input (optional, if you want it)
%       x         : bct.manifold.Manifold object
%       inputType : 'manifold'
%       scope     : 'basis' (default) or 'full'
%           'basis' : uses max(M.Eigenvalues) as lambda_max
%           'full'  : uses M.MaxResolutionFull.lambda_max_full
%
%   OUTPUT
%   ------
%   R : struct with fields
%       .lambda      : eigenvalue(s) [1/m^2]
%       .k           : angular wavenumber(s) [rad/m]
%       .freq        : spatial frequency [cycles/m]
%       .wavelength  : wavelength [m]
%
%   NOTES
%   -----
%   - Units assume your manifold coordinates are in meters.
%     If they are in mm, then freq is cycles/mm and wavelength is in mm.
%   - For the 'manifold' case, R corresponds to a *single* value
%     (lambda_max from the chosen scope).

    if nargin < 2
        error('bct.util.spatial_resolution: need at least x and inputType.');
    end

    if nargin < 3
        scope = 'basis';   % default for 'manifold' case
    end

    % ---- Case 2: Manifold input -----------------------------------------
    if ~isnumeric(x) && ~islogical(x)
        % Assume it's a Manifold-like object
        if ~strcmpi(inputType, 'manifold')
            error('If x is a Manifold, inputType must be ''manifold''.');
        end

        M = x;
        % Decide which lambda_max to use
        switch lower(scope)
            case 'basis'
                if isempty(M.Eigenvalues)
                    error('Manifold.Eigenvalues is empty.');
                end
                lambda = max(M.Eigenvalues(:));  % 1/m^2

            case 'full'
                if isempty(M.MaxResolutionFull) || ...
                   ~isfield(M.MaxResolutionFull,'lambda_max_full')
                    error(['MaxResolutionFull.lambda_max_full not set. ' ...
                           'Call Manifold.computeMaxResolutionFull(L) first.']);
                end
                lambda = M.MaxResolutionFull.lambda_max_full;  % 1/m^2

            otherwise
                error('Unknown scope "%s". Use "basis" or "full".', scope);
        end

    else
        % ---- Case 1: numeric input --------------------------------------
        x = x(:);  % column

        switch lower(inputType)
            case 'lambda'
                lambda = x;                   % 1/m^2

            case 'wavelength'
                L = x;                        % meters
                k = 2*pi ./ L;                % rad/m
                lambda = k.^2;                % 1/m^2

            case 'freq'
                f = x;                        % cycles/m
                k = 2*pi .* f;                % rad/m
                lambda = k.^2;                % 1/m^2

            otherwise
                error('Unknown inputType "%s". Use "lambda", "wavelength", "freq", or "manifold".', inputType);
        end
    end

    % ---- Convert lambda -> full set of quantities -----------------------
    lambda = lambda(:);                  % ensure column
    k       = sqrt(lambda);              % rad/m
    freq    = k / (2*pi);                % cycles/m
    wavelength = 1 ./ freq;              % meters

    % ---- Build output struct --------------------------------------------
    R = struct( ...
        'lambda',     lambda, ...
        'k',          k, ...
        'freq',       freq, ...
        'wavelength', wavelength ...
    );
end
