classdef CoordinateMode
    %COORDINATEMODE  Enumeration of coordinate display modes
    %
    %   Each domain chooses from these modes depending on its nature.
    %
    %   Time domain      -> Time
    %   Omega domain     -> Omega, Frequency
    %   Space domain     -> Space, Position
    %   Lambda domain    -> Lambda, Wavenumber, Wavelength
    %
    %   Joint domain     -> combinations (LambdaTime, SpaceTime, etc)
    %
    %   NOTE: Domains will use only the modes relevant to them.
    
    enumeration
        % ----- Temporal -----
        Time
        Omega
        Frequency
        
        % ----- Spatial -----
        Space
        Position
        
        % ----- Spectral (spatial) -----
        Lambda
        Wavenumber
        Wavelength
        
        % ----- Joint modes (optional, expandable) -----
        SpaceTime
        LambdaTime
        SpaceOmega
        LambdaOmega
    end
end
