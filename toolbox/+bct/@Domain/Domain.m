classdef (Abstract) Domain < handle
    %DOMAIN  Abstract base class for a BCT domain (Space, Time, Lambda, Omega, Joint)
    %
    % Properties implemented in all subclasses:
    %   name                 - String ("Space", "Lambda", "Time", "Omega", "Joint")
    %   units                - Display units ("mm", "s", "Hz", "1/mm^2")
    %   axis                 - Numeric coordinate array (time points, eigenvalues, etc.)
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

    methods
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

            % Use Transform factory
            obj.transform = bct.Transform.Transform(obj);
        end
    end

    % ---- Abstract methods subclasses MUST implement ----
    methods (Abstract)
        obj = buildAxis(obj, varargin)
        obj = updateResolution(obj)
        obj = updateCoordinateMode(obj)
    end
end
