classdef Quantity < uint8
    %QUANTITY Enumeration for resolution quantity representations
    %
    %   Spatial quantities:
    %     Quantity.wavelength  - Wavelength [units]
    %     Quantity.lambda      - Eigenvalue [1/units^2]
    %     Quantity.k           - Angular wavenumber [rad/units]
    %     Quantity.freq        - Spatial frequency [cycles/units]
    %
    %   Temporal quantities:
    %     Quantity.period      - Period [units]
    %     Quantity.omega       - Angular frequency [rad/units]
    %     Quantity.frequency   - Temporal frequency [Hz or cycles/units]
    %
    %   See also: bct.resolution.spatial, bct.resolution.temporal
    
    enumeration
        % Spatial quantities
        wavelength  (1)  % Wavelength L [units]
        lambda      (2)  % Eigenvalue λ [1/units^2]
        k           (3)  % Angular wavenumber k [rad/units]
        freq        (4)  % Spatial frequency f [cycles/units]
        
        % Temporal quantities
        period      (5)  % Period T [units]
        omega       (6)  % Angular frequency ω [rad/units]
        frequency   (7)  % Temporal frequency f [Hz or cycles/units]
    end
    
    methods
        function str = toString(obj)
            %TOSTRING Convert quantity to string representation
            str = char(obj);
        end
        
        function sym = symbol(obj)
            %SYMBOL Get mathematical symbol for quantity
            switch obj
                case bct.resolution.Quantity.wavelength
                    sym = 'L';
                case bct.resolution.Quantity.lambda
                    sym = 'λ';
                case bct.resolution.Quantity.k
                    sym = 'k';
                case bct.resolution.Quantity.freq
                    sym = 'f';
                case bct.resolution.Quantity.period
                    sym = 'T';
                case bct.resolution.Quantity.omega
                    sym = 'ω';
                case bct.resolution.Quantity.frequency
                    sym = 'f';
            end
        end
    end
end
