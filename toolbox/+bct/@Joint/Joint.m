classdef Joint < bct.Domain
    %JOINT  Joint domain constructed from two canonical BCT domains
    %
    % A Joint domain combines two domains (e.g., Lambda × Omega, Manifold × Time)
    % to represent signals or filters in joint coordinates. Joint domains follow
    % the dual relationship architecture: if constituent domains have duals, the
    % Joint domain also has a dual constructed from those duals.
    %
    % Dual Relationships:
    %   Manifold_Time ↔ Lambda_Omega   (spatiotemporal ↔ spectral-frequency)
    %   Lambda_Time   ↔ Manifold_Omega (spectral-temporal ↔ spatial-frequency)
    %   Manifold_Omega ↔ Lambda_Time   (spatial-frequency ↔ spectral-temporal)
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
    %   transformType- 'Separable' or 'NonSeparable' (default: 'Separable')
    %   dual         - Dual Joint domain (automatically created from constituent duals)
    %   transform    - Transform to/from dual domain (type determined by transformType)
    %
    % Transform Types:
    %   'Separable': Composes 1D transforms from constituent domains
    %                Forward: Apply A transform → B transform
    %                Inverse: Apply B inverse → A inverse
    %                Created automatically if both domains have transforms
    %
    %   'NonSeparable': Uses full 2D joint basis matrix Φ
    %                   Forward: X_hat = reshape(Φ' * X(:), sizeOut)
    %                   Inverse: X = reshape(Φ * X_hat(:), sizeIn)
    %                   Requires explicit basis matrix and size specification
    %                   Use setTransformType('NonSeparable', Phi, sizeOut)
    %
    % Example:
    %   % Create Lambda-Omega joint domain for space-time frequency analysis
    %   J_spectral = bct.Joint(B.Lambda, B.Omega);
    %   % Dual automatically created: J_spectral.dual = Manifold_Time
    %   
    %   % Create Manifold-Time joint domain for spatiotemporal signals
    %   J_spatial = bct.Joint(B.Manifold, B.Time);
    %   % Dual automatically created: J_spatial.dual = Lambda_Omega
    %
    %   % Access dual domain
    %   J_dual = J_spectral.dual;  % Manifold_Time joint domain
    %
    % See also: bct.Domain, bct.Manifold, bct.Lambda, bct.Time, bct.Omega

    properties
        Domain          % joint domain name (e.g., "Lambda_Omega")
        A               % first domain object
        B               % second domain object
        A_axis          % canonical axis of first domain [M×1]
        B_axis          % canonical axis of second domain [N×1]
        A_grid          % meshgrid of A [M×N]
        B_grid          % meshgrid of B [M×N]
        A_name          % name of first domain
        B_name          % name of second domain
        A_units         % units of first domain
        B_units         % units of second domain
        transformType   % 'Separable' or 'NonSeparable' (default: 'Separable')
        % Note: dual and transform inherited from bct.Domain base class
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
            
            % Set default transform type
            obj.transformType = 'Separable';
            
            % Create separable joint transform if both domains have transforms
            if ~isempty(domainA.transform) && ~isempty(domainB.transform)
                obj.transform = bct.factory.transforms.JointSeparable(domainA, domainB);
            end
            
            % Note: dual property is inherited from bct.Domain
            % It will be set externally by BCT.createJoint() or via createDual()
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
        function obj = setTransformType(obj, transformType, varargin)
            %SETTRANSFORMTYPE Set the transform type and create appropriate transform
            %
            %   obj = setTransformType(obj, 'Separable')
            %   obj = setTransformType(obj, 'NonSeparable', Phi, sizeOut)
            %
            % Inputs:
            %   transformType - 'Separable' or 'NonSeparable'
            %
            %   For 'Separable':
            %     No additional arguments needed. Creates JointSeparable
            %     transform from constituent domain transforms.
            %
            %   For 'NonSeparable':
            %     Phi     - Full joint basis matrix [prod(sizeOut) × prod(sizeIn)]
            %     sizeOut - Output dimensions [N_modes, T_modes] (optional)
            %               If not provided, uses sizeIn (square transform)
            %
            % Example:
            %   % Use separable transform (default)
            %   B.Joint.setTransformType('Separable');
            %
            %   % Use non-separable transform with custom basis
            %   Phi = createWavePacketBasis(B.Manifold, B.Time);
            %   B.Joint.setTransformType('NonSeparable', Phi, [64, 128]);
            
            % Validate transform type
            validTypes = {'Separable', 'NonSeparable'};
            if ~ismember(transformType, validTypes)
                error('bct:Joint:InvalidTransformType', ...
                    'transformType must be ''Separable'' or ''NonSeparable''');
            end
            
            % Set transform type
            obj.transformType = transformType;
            
            % Create appropriate transform
            switch transformType
                case 'Separable'
                    % Check that constituent domains have transforms
                    if isempty(obj.A.transform)
                        error('bct:Joint:NoTransform', ...
                            'Domain A (%s) does not have a transform', obj.A_name);
                    end
                    if isempty(obj.B.transform)
                        error('bct:Joint:NoTransform', ...
                            'Domain B (%s) does not have a transform', obj.B_name);
                    end
                    
                    % Create separable transform
                    obj.transform = bct.factory.transforms.JointSeparable(obj.A, obj.B);
                    
                case 'NonSeparable'
                    % Check required arguments
                    if nargin < 3
                        error('bct:Joint:MissingArguments', ...
                            'NonSeparable transform requires Phi matrix');
                    end
                    
                    Phi = varargin{1};
                    sizeIn = obj.size();  % [M, N]
                    
                    % Get output size (default to input size if not provided)
                    if nargin >= 4
                        sizeOut = varargin{2};
                    else
                        sizeOut = sizeIn;
                    end
                    
                    % Create non-separable transform
                    obj.transform = bct.factory.transforms.JointNonSeparable(...
                        obj.A, obj.B, Phi, sizeIn, sizeOut);
            end
        end
        
        % ---------------------------------------------------------------
        function dualJoint = createDual(obj)
            % Create dual Joint domain from constituent domain duals
            %
            % The dual of a Joint domain is constructed from the duals of its
            % constituent domains:
            %   - Manifold_Time ↔ Lambda_Omega
            %   - Lambda_Time ↔ Manifold_Omega (if defined)
            %
            % Syntax:
            %   dualJoint = obj.createDual()
            %
            % Outputs:
            %   dualJoint - Joint domain constructed from A.dual and B.dual
            %
            % Example:
            %   % Create Lambda_Omega joint domain
            %   J_spectral = bct.Joint(B.Lambda, B.Omega);
            %   
            %   % Create its dual Manifold_Time domain
            %   J_spatial = J_spectral.createDual();
            %   % J_spatial.A = B.Manifold (dual of Lambda)
            %   % J_spatial.B = B.Time (dual of Omega)
            
            % Check if constituent domains have duals
            if isempty(obj.A.dual)
                error('bct:Joint:NoDual', ...
                    'First domain (%s) does not have a dual domain defined', obj.A_name);
            end
            if isempty(obj.B.dual)
                error('bct:Joint:NoDual', ...
                    'Second domain (%s) does not have a dual domain defined', obj.B_name);
            end
            
            % Create dual Joint domain from constituent duals
            dualJoint = bct.Joint(obj.A.dual, obj.B.dual);
            
            % Set bidirectional dual relationship
            dualJoint.dual = obj;
            obj.dual = dualJoint;
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
            
            % Show dual domain if it exists
            if ~isempty(obj.dual)
                fprintf('    Dual domain: %s\n', obj.dual.Domain);
            else
                fprintf('    Dual domain: <not set>\n');
            end
            
            % Show transform type and status
            fprintf('    Transform type: %s\n', obj.transformType);
            if ~isempty(obj.transform)
                fprintf('    Transform: %s\n', class(obj.transform));
            else
                fprintf('    Transform: <not implemented>\n');
            end
            
            fprintf('\n');
        end
    end
end
