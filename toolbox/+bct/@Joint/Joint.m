classdef Joint < bct.Domain
    %JOINT  Joint domain constructed from two canonical BCT domains
    %
    % A Joint domain combines two domains (e.g., Lambda × Omega, Manifold × Time)
    % to represent signals or filters in joint coordinates. Joint domains follow
    % the dual relationship architecture: if constituent domains have duals, the
    % Joint domain also has a dual constructed from those duals.
    %
    % ARCHITECTURE:
    %   - Stores component domains BY REFERENCE (no duplication)
    %   - Derives all properties dynamically from components
    %   - Automatically constructs dual Joint from component duals
    %   - Supports both separable and non-separable transforms
    %
    % Dual Relationships:
    %   Manifold_Time ↔ Lambda_Omega   (spatiotemporal ↔ spectral-frequency)
    %   Lambda_Time   ↔ Manifold_Omega (spectral-temporal ↔ spatial-frequency)
    %   Manifold_Omega ↔ Lambda_Time   (spatial-frequency ↔ spectral-temporal)
    %
    % Properties:
    %   components   - Cell array {Domain1, Domain2} storing references
    %   separable    - Logical: true = separable, false = non-separable
    %   Domain       - String describing joint domain (e.g., "Lambda_Omega")
    %   N            - [N1, N2] resolution of component domains
    %   axis         - Cell array {axis1, axis2} preserving structure
    %   units        - Combined units string (e.g., "lambda-omega")
    %   dual         - Dual Joint domain (auto-created from component duals)
    %   transform    - JointSeparable or JointNonSeparable object
    %
    % Derived Properties (computed on demand):
    %   A            - First component domain (components{1})
    %   B            - Second component domain (components{2})
    %   A_axis       - First domain axis (components{1}.axis)
    %   B_axis       - Second domain axis (components{2}.axis)
    %   A_grid       - Meshgrid of first domain coordinates
    %   B_grid       - Meshgrid of second domain coordinates
    %
    % Example:
    %   % Create Lambda-Omega joint domain
    %   J_spectral = bct.Joint(B.Lambda, B.Omega);
    %   % Dual automatically created: J_spectral.dual = Manifold_Time
    %   
    %   % Access component domains by reference
    %   k_axis = J_spectral.components{1}.axis;  % Lambda axis
    %   omega_axis = J_spectral.components{2}.axis;  % Omega axis
    %
    % See also: bct.Domain, bct.Manifold, bct.Lambda, bct.Time, bct.Omega

    properties (SetAccess = private)
        components      % cell array: {Domain1, Domain2}
        separable       % logical: true = separable, false = non-separable
        TransformType   % string: 'Separable' or 'NonSeparable'
        Domain          % joint domain name (e.g., "Lambda_Omega")
        % Note: N, axis, units, dual, transform inherited from bct.Domain base class
    end

    methods
        % ---------------------------------------------------------------
        function obj = Joint(domainA, domainB, varargin)
            % JOINT Constructor for Joint domain
            %
            % Syntax:
            %   obj = bct.Joint(domainA, domainB)
            %   obj = bct.Joint(domainA, domainB, 'Separable')
            %   obj = bct.Joint(domainA, domainB, 'NonSeparable', Phi)
            %
            % Inputs:
            %   domainA   - First BCT domain (Lambda, Manifold, Time, or Omega)
            %   domainB   - Second BCT domain (Lambda, Manifold, Time, or Omega)
            %   type      - (Optional) 'Separable' (default) or 'NonSeparable'
            %   Phi       - (Optional) Basis matrix for non-separable transform
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
            
            % Parse optional arguments
            p = inputParser;
            addOptional(p, 'TransformType', 'Separable', @(x) ismember(x, {'Separable', 'NonSeparable'}));
            addOptional(p, 'Phi', [], @ismatrix);
            addOptional(p, 'CreateDual', true, @islogical);  % Flag to prevent infinite recursion
            parse(p, varargin{:});
            
            % Extract domain names and units
            A_name = domainA.name;
            B_name = domainB.name;
            A_units = domainA.units;
            B_units = domainB.units;
            
            % Create joint domain name and units
            jointName = sprintf("%s_%s", A_name, B_name);
            jointUnits = sprintf("%s-%s", A_units, B_units);
            
            % Call parent constructor
            obj@bct.Domain(jointName, jointUnits);
            
            % Store component domains BY REFERENCE (no copying)
            obj.components = {domainA, domainB};
            
            % Set separability
            obj.separable = strcmp(p.Results.TransformType, 'Separable');
            
            % Store transform type
            obj.TransformType = p.Results.TransformType;
            
            % Store domain name
            obj.Domain = jointName;
            
            % Construct joint axis as cell array {axis1, axis2}
            % This preserves structure better than flattening
            obj.axis = {domainA.axis(:), domainB.axis(:)};
            
            % Set resolution and coordinate modes
            obj.resolutionMode = bct.enum.ResolutionMode.Full;
            obj.displayCoordinateMode = bct.enum.CoordinateMode.Vertex;
            
            % Store metadata
            obj.metadata.A_name = A_name;
            obj.metadata.B_name = B_name;
            obj.metadata.A_units = A_units;
            obj.metadata.B_units = B_units;
            obj.metadata.shape = [domainA.N, domainB.N];
            
            % Automatically create dual Joint domain if both components have duals
            % Only if CreateDual flag is true (prevents infinite recursion)
            if p.Results.CreateDual && ~isempty(domainA.dual) && ~isempty(domainB.dual)
                % Create dual Joint (e.g., Manifold_Time → Lambda_Omega)
                % Pass CreateDual=false to prevent recursive dual creation
                dualJoint = bct.Joint(domainA.dual, domainB.dual, ...
                    p.Results.TransformType, p.Results.Phi, 'CreateDual', false);
                
                % Set bidirectional dual relationship
                obj.dual = dualJoint;
                dualJoint.dual = obj;
            end
            
            % Create transform if separable and both domains have transforms
            if obj.separable
                if ~isempty(domainA.transform) && ~isempty(domainB.transform)
                    obj.transform = bct.factory.transforms.JointSeparable(domainA, domainB);
                end
            else
                % Non-separable transform requires explicit basis matrix
                if ~isempty(p.Results.Phi)
                    sizeIn = [domainA.N, domainB.N];
                    sizeOut = sizeIn;  % Default to square transform
                    obj.transform = bct.factory.transforms.JointNonSeparable(...
                        domainA, domainB, p.Results.Phi, sizeIn, sizeOut);
                end
            end
        end
        
        % ---------------------------------------------------------------
        % Convenience methods for accessing component domains
        % ---------------------------------------------------------------
        
        function domain = A(obj)
            % Get first component domain
            domain = obj.components{1};
        end
        
        function domain = B(obj)
            % Get second component domain
            domain = obj.components{2};
        end
        
        function ax = A_axis(obj)
            % Get first domain axis (for backward compatibility)
            % New code should use obj.axis{1}
            ax = obj.axis{1};
        end
        
        function ax = B_axis(obj)
            % Get second domain axis (for backward compatibility)
            % New code should use obj.axis{2}
            ax = obj.axis{2};
        end
        
        function name = A_name(obj)
            % Get first domain name (for backward compatibility)
            name = obj.components{1}.name;
        end
        
        function name = B_name(obj)
            % Get second domain name (for backward compatibility)
            name = obj.components{2}.name;
        end
        
        function units_str = A_units(obj)
            % Get first domain units (for backward compatibility)
            units_str = obj.components{1}.units;
        end
        
        function units_str = B_units(obj)
            % Get second domain units (for backward compatibility)
            units_str = obj.components{2}.units;
        end
        
        function grid = A_grid(obj)
            % Get meshgrid of first domain coordinates
            % Computed on demand from axis
            [grid, ~] = meshgrid(obj.axis{1}, obj.axis{2});
            grid = grid';  % Transpose for [N1×N2] orientation
        end
        
        function grid = B_grid(obj)
            % Get meshgrid of second domain coordinates
            % Computed on demand from axis
            [~, grid] = meshgrid(obj.axis{1}, obj.axis{2});
            grid = grid';  % Transpose for [N1×N2] orientation
        end

        % ---------------------------------------------------------------
        function obj = buildAxis(obj, varargin)
            % Rebuild joint axis from constituent domain axes
            % Updates axis cell array to reflect current component domain axes
            
            % Update axis from components (in case they changed)
            obj.axis = {obj.components{1}.axis(:), obj.components{2}.axis(:)};
            
            % Update units from components
            obj.units = sprintf("%s-%s", obj.components{1}.units, obj.components{2}.units);
            
            % Update metadata
            obj.metadata.shape = [obj.components{1}.N, obj.components{2}.N];
            obj.metadata.A_name = obj.components{1}.name;
            obj.metadata.B_name = obj.components{2}.name;
            obj.metadata.A_units = obj.components{1}.units;
            obj.metadata.B_units = obj.components{2}.units;
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
        function n = numel(obj)
            % Get total number of elements in joint domain
            % N property returns [M, N], so prod gives total elements
            dims = obj.N;
            n = prod(dims);
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
            % Reshape 1D vector to 2D joint grid
            %
            % Syntax:
            %   X = obj.reshape2D(x)
            %
            % Inputs:
            %   x - Vector of length M*N
            %
            % Outputs:
            %   X - Matrix of size [M×N]
            
            dims = obj.N;
            if length(x) ~= prod(dims)
                error('bct:Joint:DimensionMismatch', ...
                    'Input vector length (%d) must match grid size (%d)', ...
                    length(x), prod(dims));
            end
            X = reshape(x, dims);
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
            
            dims = obj.N;
            if ~isequal(size(X), dims)
                error('bct:Joint:DimensionMismatch', ...
                    'Input matrix size must be [%d×%d]', dims(1), dims(2));
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
            
            % Set transform type and separability flag
            obj.TransformType = transformType;
            obj.separable = strcmp(transformType, 'Separable');
            
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
            fprintf('    First domain (A):  %s [%s]\n', obj.A_name(), obj.A_units());
            fprintf('      A_axis: [%d×1] from %.4g to %.4g\n', ...
                length(obj.A_axis()), min(obj.A_axis()), max(obj.A_axis()));
            fprintf('\n');
            fprintf('    Second domain (B): %s [%s]\n', obj.B_name(), obj.B_units());
            fprintf('      B_axis: [%d×1] from %.4g to %.4g\n', ...
                length(obj.B_axis()), min(obj.B_axis()), max(obj.B_axis()));
            fprintf('\n');
            fprintf('    Joint grid size: [%d×%d] = %d points\n', ...
                length(obj.A_axis()), length(obj.B_axis()), obj.numel());
            fprintf('    Joint units: %s\n', obj.units);
            
            % Show dual domain if it exists
            if ~isempty(obj.dual)
                fprintf('    Dual domain: %s\n', obj.dual.Domain);
            else
                fprintf('    Dual domain: <not set>\n');
            end
            
            % Show transform type and status
            if obj.separable
                fprintf('    Transform type: Separable\n');
            else
                fprintf('    Transform type: Non-separable\n');
            end
            if ~isempty(obj.transform)
                fprintf('    Transform: %s\n', class(obj.transform));
            else
                fprintf('    Transform: <not implemented>\n');
            end
            
            fprintf('\n');
        end
    end
end
