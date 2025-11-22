classdef Joint < bct.Domain
    %JOINT  Joint domain constructed from two canonical BCT domains
    %
    % A Joint domain combines two domains (e.g., Lambda × Omega, Manifold × Time)
    % to represent signals or filters in joint coordinates.
    %
    % Properties:
    %   Domain       - String describing the joint domain (e.g., "Lambda_Omega")
    %   A            - First domain object (e.g., Lambda)
    %   B            - Second domain object (e.g., Omega)
    %   A_axis       - Canonical axis of first domain [M×1]
    %   B_axis       - Canonical axis of second domain [N×1]
    %   A_grid       - Meshgrid of A coordinates [M×N]
    %   B_grid       - Meshgrid of B coordinates [M×N]
    %   A_name       - Name of first domain
    %   B_name       - Name of second domain
    %   A_units      - Units of first domain
    %   B_units      - Units of second domain
    %
    % Example:
    %   % Create Lambda-Omega joint domain for space-time frequency analysis
    %   J = bct.Joint(B.Lambda, B.Omega);
    %   
    %   % Create Manifold-Time joint domain for spatiotemporal signals
    %   J = bct.Joint(B.Manifold, B.Time);

    properties
        Domain      % joint domain name (e.g., "Lambda_Omega")
        A           % first domain object
        B           % second domain object
        A_axis      % canonical axis of first domain [M×1]
        B_axis      % canonical axis of second domain [N×1]
        A_grid      % meshgrid of A [M×N]
        B_grid      % meshgrid of B [M×N]
        A_name      % name of first domain
        B_name      % name of second domain
        A_units     % units of first domain
        B_units     % units of second domain
    end

    methods
        % ---------------------------------------------------------------
        function obj = Joint(domainA, domainB)
            % JOINT Constructor for Joint domain
            %
            % Syntax:
            %   obj = bct.Joint(domainA, domainB)
            %
            % Inputs:
            %   domainA - First BCT domain (Lambda, Manifold, Time, or Omega)
            %   domainB - Second BCT domain (Lambda, Manifold, Time, or Omega)
            %
            % Outputs:
            %   obj - Joint domain object with combined coordinates
            
            % Validate inputs
            if ~isa(domainA, 'bct.Domain')
                error('bct:Joint:InvalidDomain', 'First argument must be a bct.Domain object');
            end
            if ~isa(domainB, 'bct.Domain')
                error('bct:Joint:InvalidDomain', 'Second argument must be a bct.Domain object');
            end
            
            % Extract domain names and units BEFORE calling superclass
            A_name_temp = domainA.name;
            B_name_temp = domainB.name;
            A_units_temp = domainA.units;
            B_units_temp = domainB.units;
            
            % Create joint domain name
            jointName = sprintf("%s_%s", A_name_temp, B_name_temp);
            jointUnits = sprintf("%s × %s", A_units_temp, B_units_temp);
            
            % Call parent constructor FIRST (before setting object properties)
            obj@bct.Domain(jointName, jointUnits);
            
            % Now set object properties
            obj.A_name = A_name_temp;
            obj.B_name = B_name_temp;
            obj.A_units = A_units_temp;
            obj.B_units = B_units_temp;
            
            % Store domain references
            obj.A = domainA;
            obj.B = domainB;
            
            % Extract axes from domains
            obj.A_axis = domainA.axis;
            obj.B_axis = domainB.axis;
            
            % Validate axes are vectors
            if ~isvector(obj.A_axis) || ~isvector(obj.B_axis)
                error('bct:Joint:InvalidAxis', 'Domain axes must be vectors');
            end
            
            % Ensure column vectors
            obj.A_axis = obj.A_axis(:);
            obj.B_axis = obj.B_axis(:);
            
            % Create meshgrids for joint coordinates
            [obj.A_grid, obj.B_grid] = meshgrid(obj.A_axis, obj.B_axis);
            % Note: meshgrid returns [length(B) × length(A)] arrays
            % Transpose to get [length(A) × length(B)] for consistency
            obj.A_grid = obj.A_grid';
            obj.B_grid = obj.B_grid';
            
            % Set joint axis as linearized grids (for compatibility)
            obj.axis = [obj.A_grid(:), obj.B_grid(:)];
            
            % Set resolution and coordinate modes
            obj.resolutionMode = bct.enum.ResolutionMode.Full;
            obj.displayCoordinateMode = bct.enum.CoordinateMode.Vertex; % Generic
            
            % Store domain names as metadata
            obj.Domain = jointName;
            obj.metadata.A_name = obj.A_name;
            obj.metadata.B_name = obj.B_name;
            obj.metadata.A_units = obj.A_units;
            obj.metadata.B_units = obj.B_units;
            obj.metadata.shape = [length(obj.A_axis), length(obj.B_axis)];
        end

        % ---------------------------------------------------------------
        function obj = buildAxis(obj, varargin)
            % Rebuild joint axis from constituent domain axes
            
            % Update axes from constituent domains (in case they changed)
            obj.A_axis = obj.A.axis(:);
            obj.B_axis = obj.B.axis(:);
            obj.A_units = obj.A.units;
            obj.B_units = obj.B.units;
            
            % Recreate meshgrids
            [obj.A_grid, obj.B_grid] = meshgrid(obj.A_axis, obj.B_axis);
            obj.A_grid = obj.A_grid';
            obj.B_grid = obj.B_grid';
            
            % Update joint axis
            obj.axis = [obj.A_grid(:), obj.B_grid(:)];
            
            % Update units
            obj.units = sprintf("%s × %s", obj.A_units, obj.B_units);
            
            % Update metadata
            obj.metadata.shape = [length(obj.A_axis), length(obj.B_axis)];
        end

        % ---------------------------------------------------------------
        function obj = updateResolution(obj)
            % Update resolution (delegates to constituent domains)
            % Future: implement joint resolution control
            warning('bct:Joint:NotImplemented', ...
                'Joint domain resolution control not yet implemented');
        end

        % ---------------------------------------------------------------
        function obj = updateCoordinateMode(obj)
            % Update coordinate mode by rebuilding from constituent domains
            % The constituent domains handle their own coordinate modes
            obj = obj.buildAxis();
        end
        
        % ---------------------------------------------------------------
        function sz = size(obj)
            % Get size of joint domain grid
            % Returns [M, N] where M = length(A_axis), N = length(B_axis)
            sz = [length(obj.A_axis), length(obj.B_axis)];
        end
        
        % ---------------------------------------------------------------
        function n = numel(obj)
            % Get total number of elements in joint domain
            sz = obj.size();
            n = prod(sz);
        end
        
        % ---------------------------------------------------------------
        function [M, N] = gridSize(obj)
            % Get grid dimensions
            % Returns M (A dimension) and N (B dimension)
            M = length(obj.A_axis);
            N = length(obj.B_axis);
        end
        
        % ---------------------------------------------------------------
        function X = reshape2D(obj, x)
            % Reshape 1D vector to 2D grid [M×N]
            %
            % Syntax:
            %   X = obj.reshape2D(x)
            %
            % Inputs:
            %   x - Vector of length M*N
            %
            % Outputs:
            %   X - Matrix of size [M×N]
            
            sz = obj.size();
            if length(x) ~= prod(sz)
                error('bct:Joint:DimensionMismatch', ...
                    'Input vector length (%d) must match grid size (%d)', ...
                    length(x), prod(sz));
            end
            X = reshape(x, sz);
        end
        
        % ---------------------------------------------------------------
        function x = flatten(obj, X)
            % Flatten 2D grid to 1D vector
            %
            % Syntax:
            %   x = obj.flatten(X)
            %
            % Inputs:
            %   X - Matrix of size [M×N]
            %
            % Outputs:
            %   x - Vector of length M*N
            
            sz = obj.size();
            if ~isequal(size(X), sz)
                error('bct:Joint:DimensionMismatch', ...
                    'Input matrix size must be [%d×%d]', sz(1), sz(2));
            end
            x = X(:);
        end
        
        % ---------------------------------------------------------------
        function tf = isDual(obj, otherJoint)
            % Check if this joint domain is dual to another
            % Two joint domains are dual if their constituent domains are dual
            %
            % Example:
            %   J1 = bct.Joint(B.Lambda, B.Omega);
            %   J2 = bct.Joint(B.Manifold, B.Time);
            %   tf = J1.isDual(J2);  % true if Lambda↔Manifold and Omega↔Time
            
            if ~isa(otherJoint, 'bct.Joint')
                tf = false;
                return;
            end
            
            % Check if constituent domains are dual
            A_dual = (obj.A.dual == otherJoint.A) || (obj.A.dual == otherJoint.B);
            B_dual = (obj.B.dual == otherJoint.A) || (obj.B.dual == otherJoint.B);
            
            tf = A_dual && B_dual;
        end
    end
    
    % ---------------------------------------------------------------
    % Display methods
    % ---------------------------------------------------------------
    methods
        function disp(obj)
            % Custom display for Joint domain
            fprintf('  <a href="matlab:helpPopup bct.Joint">bct.Joint</a> domain: %s\n', obj.Domain);
            fprintf('\n');
            fprintf('    First domain (A):  %s [%s]\n', obj.A_name, obj.A_units);
            fprintf('      A_axis: [%d×1] from %.4g to %.4g\n', ...
                length(obj.A_axis), min(obj.A_axis), max(obj.A_axis));
            fprintf('\n');
            fprintf('    Second domain (B): %s [%s]\n', obj.B_name, obj.B_units);
            fprintf('      B_axis: [%d×1] from %.4g to %.4g\n', ...
                length(obj.B_axis), min(obj.B_axis), max(obj.B_axis));
            fprintf('\n');
            fprintf('    Joint grid size: [%d×%d] = %d points\n', ...
                length(obj.A_axis), length(obj.B_axis), obj.numel());
            fprintf('    Joint units: %s\n', obj.units);
            fprintf('\n');
        end
    end
end
