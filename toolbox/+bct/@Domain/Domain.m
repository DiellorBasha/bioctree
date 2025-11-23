classdef (Abstract) Domain < handle
    %DOMAIN  Abstract base class for a BCT domain (Space, Time, Lambda, Omega, Joint)
    %
    % Properties implemented in all subclasses:
    %   name                 - String ("Space", "Lambda", "Time", "Omega", "Joint")
    %   units                - Display units ("mm", "s", "Hz", "1/mm^2")
    %   axis                 - Numeric coordinate array (time points, eigenvalues, etc.)
    %   N                    - Dimension of domain (number of points/modes/vertices)
    %   resolutionMode       - Enum: Full or Instrument
    %   displayCoordinateMode - Enum: lambda, wavenumber, wavelength, etc.
    %   dual                 - Reference to the dual domain
    %   metadata             - Struct for arbitrary additional information
    %
    % Each domain must implement:
    %   buildAxis           - Construct or refresh the axis based on resolution/mode
    %   updateResolution    - Update domain resolution (full/instrument)
    %   updateCoordinateMode - Convert/recompute axis for current coordinate mode

    properties
        name                string
        units               string
        axis                % numeric vector
        resolutionMode      % bct.enum.Resolution.Full / Instrument
        displayCoordinateMode   % bct.enum.Coordinate (lambda/wavelength/etc.)
        dual                % handle to dual domain
        metadata            struct = struct()
        transform           % transform object created by Transform factory
    end
    
    properties (Dependent)
        N                   % Dimension of domain (length of axis for single domains)
    end

    methods
        function n = get.N(obj)
            %GET.N Get dimension of domain
            % For Manifold: returns number of vertices
            % For single domains: returns length of axis
            % For Joint domains: overridden to return total elements
            if isempty(obj.axis)
                % Check if this is a Manifold with Vertices
                if isa(obj, 'bct.Manifold') && ~isempty(obj.Vertices)
                    n = size(obj.Vertices, 1);
                else
                    n = 0;
                end
            elseif ismatrix(obj.axis) && size(obj.axis, 2) == 2
                % Joint domain with 2-column axis [A_coords, B_coords]
                % This will be overridden in Joint class
                n = size(obj.axis, 1);
            else
                % Single domain: axis is a vector
                n = length(obj.axis);
            end
        end
        
        function obj = Domain(name, units)
            % Base constructor. Subclasses will call this.
            if nargin > 0
                obj.name  = string(name);
                obj.units = string(units);
            end
        end

        function setDual(obj, dualDomain)
            % Prevent recursive looping if dual already set
            if isempty(obj.dual)
                obj.dual = dualDomain;

                % Set the reverse dual only if needed
                if isempty(dualDomain.dual) || dualDomain.dual ~= obj
                    dualDomain.setDual(obj);
                end
            end
        end

        function obj = initializeTransform(obj)
            % Create forward/inverse transform handles based on Domain ↔ Dual
            if isempty(obj.dual)
                warning("Domain '%s' has no dual domain assigned.", obj.name);
                return;
            end

            % Determine which transform to use based on domain type
            switch obj.name
                case "Manifold"
                    % Manifold ↔ Lambda: Use Mesh Fourier Transform
                    % Check if Lambda has eigenvectors computed
                    if ~isempty(obj.dual.U)
                        obj.transform = bct.factory.transforms.MFT(obj);
                    else
                        % Eigenvectors not yet computed - transform will be set later
                        obj.transform = [];
                    end
                    
                case "Lambda"
                    % Lambda ↔ Manifold: Use Inverse Mesh Fourier Transform
                    % Check if eigenvectors are available
                    if ~isempty(obj.U)
                        obj.transform = bct.factory.transforms.IMFT(obj);  % Pass Lambda itself, not dual
                    else
                        % Eigenvectors not yet computed - transform will be set later
                        obj.transform = [];
                    end
                    
                case "Time"
                    % Time ↔ Omega: Use FFT
                    obj.transform = bct.factory.transforms.FFT(obj);
                    
                case "Omega"
                    % Omega ↔ Time: Use IFFT
                    obj.transform = bct.factory.transforms.IFFT(obj.dual);
                    
                otherwise
                    warning("No transform defined for domain type '%s'", obj.name);
            end
        end
    end

    % ---- Abstract methods subclasses MUST implement ----
    methods (Abstract)
        obj = buildAxis(obj, varargin)
        obj = updateResolution(obj)
        obj = updateCoordinateMode(obj)
    end
end
