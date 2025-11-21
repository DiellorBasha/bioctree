classdef CoordinateMode
    %COORDINATEMODE  Display modes for domain axes.
    %
    % Each domain selects the subset of modes it supports.
    %
    % Manifold:
    %   Vertex, Geodesic
    %
    % Lambda:
    %   Lambda, Wavenumber, Wavelength
    %
    % Time:
    %   Time, Index
    %
    % Omega:
    %   Omega, Frequency

    enumeration
        % ===== Manifold & Graph Domains =====
        Vertex          % index (1:N)
        Geodesic        % geodesic distance or intrinsic coord
        
        % ===== Time Domain =====
        Time            % seconds
        Index           % sample index (1:T)

        % ===== Omega Domain (dual of Time) =====
        Omega           % rad/s
        Frequency       % Hz

        % ===== Lambda Domain (dual of Manifold) =====
        Lambda          % eigenvalue (1/mm^2)
        Wavenumber      % sqrt(lambda)
        Wavelength      % 1/sqrt(lambda)
    end

end
