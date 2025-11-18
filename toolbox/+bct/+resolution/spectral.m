function res = spectral(lambda_max)
    %SPECTRAL Domain-agnostic spectral resolution computation
    %
    %   res = bct.resolution.spectral(lambda_max) computes spectral
    %   resolution metrics from maximum eigenvalue.
    %
    %   This is a domain-agnostic function that computes fundamental
    %   spectral quantities from eigenvalue. Use bct.resolution.spatial
    %   or bct.resolution.temporal for domain-specific interpretations.
    %
    %   Inputs:
    %     lambda_max - Maximum eigenvalue (scalar or array)
    %
    %   Returns:
    %     res - Struct with fields:
    %       .lambda_max - Maximum eigenvalue [1/unit^2]
    %       .k_max      - Maximum wavenumber/angular frequency [rad/unit]
    %       .f_max      - Maximum frequency [cycles/unit]
    %       .L_min      - Minimum wavelength/period [unit/cycle]
    %
    %   Mathematical relationships:
    %     k = sqrt(λ)           Angular wavenumber/frequency
    %     f = k/(2π)            Frequency (cycles per unit)
    %     L = 1/f = 2π/k        Wavelength/period (units per cycle)
    %
    %   Example:
    %     % Spatial: lambda_max in [1/mm^2]
    %     res = bct.resolution.spectral(30837);
    %     % res.L_min = 0.0358 mm (wavelength)
    %     
    %     % Temporal: lambda_max in [1/s^2]  
    %     res = bct.resolution.spectral(39478);
    %     % res.L_min = 0.0050 s (period)
    %
    %   See also: bct.resolution.spatial, bct.resolution.temporal
    
    % Handle empty input
    if isempty(lambda_max)
        res = struct('lambda_max', [], 'k_max', [], 'f_max', [], 'L_min', []);
        return;
    end
    
    % Validate input
    if ~isnumeric(lambda_max) || any(lambda_max(:) < 0)
        error('bct:resolution:spectral:InvalidInput', ...
            'lambda_max must be non-negative numeric value');
    end
    
    % Handle scalar zero
    if isscalar(lambda_max) && lambda_max == 0
        res = struct('lambda_max', 0, 'k_max', 0, 'f_max', 0, 'L_min', Inf);
        return;
    end
    
    % Compute spectral quantities
    k_max = sqrt(lambda_max);           % Angular wavenumber/frequency [rad/unit]
    f_max = k_max / (2*pi);            % Frequency [cycles/unit]
    L_min = 1 ./ f_max;                % Wavelength/period [unit/cycle]
    
    % Return as struct
    res = struct(...
        'lambda_max', lambda_max, ...
        'k_max', k_max, ...
        'f_max', f_max, ...
        'L_min', L_min ...
    );
end
