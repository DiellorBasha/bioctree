classdef Operator < handle
    %OPERATOR Wrapper for differential and transform operators
    %
    % Encapsulates operator matrices with metadata and provides a uniform
    % interface for operator application, composition, and inspection.
    %
    % Design principles:
    %   - Operators are tied to a specific Manifold (geometric context)
    %   - Matrix property holds the actual sparse operator matrix
    %   - Metadata describes domain, input/output types, provenance
    %   - Supports functional application via apply() or mtimes (*)
    %
    % Usage:
    %   % Get operator from Manifold
    %   M = bct.Manifold(V, F);
    %   d0 = M.d0();
    %   
    %   % Apply to field
    %   omega0 = rand(M.numVertices(), 1);  % 0-form
    %   omega1 = d0.apply(omega0);          % 1-form
    %   
    %   % Or use matrix multiplication
    %   omega1 = d0 * omega0;
    %
    % See also: bct.Manifold, DiscreteExteriorCalculus

    properties (SetAccess = private)
        Matrix       % Sparse operator matrix [m×n]
        ID           % Operator identifier (e.g., "d0", "gradient.dec")
        Name         % Human-readable name
        Domain       % Domain type: "dec", "fem", "graph"
        InputType    % Input type (e.g., "0-form", "1-form", "scalar_field")
        OutputType   % Output type (e.g., "1-form", "2-form", "vector_field")
        Manifold     % Reference to parent Manifold
    end
    
    properties (Dependent)
        Size         % Operator size [m, n]
        NumNonZeros  % Number of non-zero entries
        IsSparse     % Whether matrix is sparse
    end

    methods
        % ===============================================================
        % CONSTRUCTOR
        % ===============================================================
        
        function obj = Operator(M, matrix, options)
            %OPERATOR Construct operator object
            %
            % Syntax:
            %   op = bct.Operator(M, matrix)
            %   op = bct.Operator(M, matrix, 'ID', id, 'Name', name, ...)
            %
            % Inputs:
            %   M      - bct.Manifold object (geometric context)
            %   matrix - Sparse operator matrix [m×n]
            %
            % Optional Parameters:
            %   ID         - Operator identifier (default: "")
            %   Name       - Human-readable name (default: "")
            %   Domain     - Domain type: "dec", "fem", "graph" (default: "")
            %   InputType  - Input type description (default: "")
            %   OutputType - Output type description (default: "")
            %
            % Examples:
            %   % Create DEC exterior derivative d0
            %   M = bct.Manifold(V, F);
            %   dec = M.DEC();
            %   d0 = bct.Operator(M, dec.d0, ...
            %       'ID', "d0", ...
            %       'Name', "Exterior Derivative (0→1)", ...
            %       'Domain', "dec", ...
            %       'InputType', "0-form", ...
            %       'OutputType', "1-form");
            
            arguments
                M bct.Manifold
                matrix {mustBeNumeric}
                options.ID string = ""
                options.Name string = ""
                options.Domain string = ""
                options.InputType string = ""
                options.OutputType string = ""
            end
            
            % Validate manifold
            if isempty(M) || ~isvalid(M)
                error('bct:Operator:InvalidManifold', ...
                    'Manifold must be a valid bct.Manifold object');
            end
            
            % Store properties
            obj.Manifold = M;
            obj.Matrix = matrix;
            obj.ID = options.ID;
            obj.Name = options.Name;
            obj.Domain = options.Domain;
            obj.InputType = options.InputType;
            obj.OutputType = options.OutputType;
        end
        
        % ===============================================================
        % OPERATOR APPLICATION
        % ===============================================================
        
        function result = apply(obj, input)
            %APPLY Apply operator to input field
            %
            % Syntax:
            %   output = op.apply(input)
            %
            % Inputs:
            %   input - Input field vector [n×1] or [n×k] for k fields
            %
            % Outputs:
            %   output - Result of operator application [m×1] or [m×k]
            %
            % Description:
            %   Applies the operator matrix to the input field(s).
            %   Validates input size against operator dimensions.
            %
            % Examples:
            %   % Apply d0 operator to scalar field
            %   d0 = M.d0();
            %   omega0 = rand(M.numVertices(), 1);
            %   omega1 = d0.apply(omega0);
            %
            % See also: mtimes
            
            % Validate input dimensions
            [m, n] = size(obj.Matrix);
            if size(input, 1) ~= n
                error('bct:Operator:DimensionMismatch', ...
                    'Input size [%d×%d] does not match operator input dimension [%d]', ...
                    size(input, 1), size(input, 2), n);
            end
            
            % Apply operator
            result = obj.Matrix * input;
        end
        
        function result = mtimes(obj, other)
            %MTIMES Overload * for operator application or composition
            %
            % Syntax:
            %   output = op * field        % Apply operator to field
            %   op3 = op1 * op2            % Compose operators
            %
            % Description:
            %   If other is numeric, applies operator to field.
            %   If other is bct.Operator, composes operators (op1 * op2 = op1(op2(·))).
            %
            % Examples:
            %   % Apply operator
            %   omega1 = d0 * omega0;
            %
            %   % Compose operators
            %   laplacian = d1' * d1 + d0' * d0;
            %
            % See also: apply, compose
            
            if isa(other, 'bct.Operator')
                % Operator composition: op1 * op2
                result = obj.compose(other);
            elseif isnumeric(other)
                % Operator application: op * field
                result = obj.apply(other);
            else
                error('bct:Operator:InvalidOperand', ...
                    'Cannot multiply Operator with %s', class(other));
            end
        end
        
        function result = compose(obj, other)
            %COMPOSE Compose two operators
            %
            % Syntax:
            %   op3 = op1.compose(op2)
            %   op3 = op1 * op2
            %
            % Description:
            %   Composes operators such that op3(x) = op1(op2(x)).
            %   Validates manifold compatibility and dimension matching.
            %
            % Examples:
            %   % Compose d0 and d1 (should be zero by exactness)
            %   d0 = M.d0();
            %   d1 = M.d1();
            %   d1d0 = d1 * d0;  % d1 ∘ d0 = 0
            %
            % See also: mtimes
            
            if ~isa(other, 'bct.Operator')
                error('bct:Operator:InvalidOperand', ...
                    'Can only compose with another bct.Operator');
            end
            
            % Check manifold compatibility
            if obj.Manifold ~= other.Manifold
                warning('bct:Operator:ManifoldMismatch', ...
                    'Composing operators from different manifolds');
            end
            
            % Check dimension compatibility
            if size(obj.Matrix, 2) ~= size(other.Matrix, 1)
                error('bct:Operator:DimensionMismatch', ...
                    'Operator dimensions not compatible for composition: [%d×%d] * [%d×%d]', ...
                    size(obj.Matrix, 1), size(obj.Matrix, 2), ...
                    size(other.Matrix, 1), size(other.Matrix, 2));
            end
            
            % Compose matrices
            composedMatrix = obj.Matrix * other.Matrix;
            
            % Create composed operator
            composedID = sprintf("%s∘%s", obj.ID, other.ID);
            composedName = sprintf("%s ∘ %s", obj.Name, other.Name);
            
            result = bct.Operator(obj.Manifold, composedMatrix, ...
                'ID', composedID, ...
                'Name', composedName, ...
                'Domain', obj.Domain, ...
                'InputType', other.InputType, ...
                'OutputType', obj.OutputType);
        end
        
        function result = ctranspose(obj)
            %CTRANSPOSE Overload ' for operator transpose
            %
            % Syntax:
            %   opT = op'
            %
            % Description:
            %   Returns the transpose (adjoint) of the operator.
            %   For differential operators, this represents the codifferential.
            %
            % Examples:
            %   % Codifferential d0*
            %   d0 = M.d0();
            %   d0star = d0';
            %
            %   % Laplacian: Δ = d'd + dd'
            %   d0 = M.d0();
            %   d1 = M.d1();
            %   Delta = d0' * d0 + d1 * d1';
            %
            % See also: compose
            
            transposedMatrix = obj.Matrix';
            transposedID = sprintf("%s'", obj.ID);
            transposedName = sprintf("%s (transpose)", obj.Name);
            
            result = bct.Operator(obj.Manifold, transposedMatrix, ...
                'ID', transposedID, ...
                'Name', transposedName, ...
                'Domain', obj.Domain, ...
                'InputType', obj.OutputType, ...
                'OutputType', obj.InputType);
        end
        
        % ===============================================================
        % DEPENDENT PROPERTIES
        % ===============================================================
        
        function sz = get.Size(obj)
            %SIZE Get operator matrix size
            sz = size(obj.Matrix);
        end
        
        function nnz_val = get.NumNonZeros(obj)
            %NUMNONZEROS Get number of non-zero entries
            nnz_val = nnz(obj.Matrix);
        end
        
        function tf = get.IsSparse(obj)
            %ISSPARSE Check if matrix is sparse
            tf = issparse(obj.Matrix);
        end
        
        % ===============================================================
        % DISPLAY
        % ===============================================================
        
        function disp(obj)
            %DISP Display operator information
            
            if isempty(obj.Name)
                fprintf('  <strong>bct.Operator</strong>\n');
            else
                fprintf('  <strong>bct.Operator:</strong> %s\n', obj.Name);
            end
            
            if obj.ID ~= ""
                fprintf('    ID: %s\n', obj.ID);
            end
            
            if obj.Domain ~= ""
                fprintf('    Domain: %s\n', obj.Domain);
            end
            
            if obj.InputType ~= "" && obj.OutputType ~= ""
                fprintf('    Type: %s → %s\n', obj.InputType, obj.OutputType);
            end
            
            fprintf('    Size: [%d × %d]\n', obj.Size(1), obj.Size(2));
            fprintf('    Non-zeros: %d (%.2f%% sparse)\n', ...
                obj.NumNonZeros, ...
                100 * (1 - obj.NumNonZeros / prod(obj.Size)));
            
            fprintf('    Manifold: %d vertices, %d faces\n', ...
                obj.Manifold.numVertices(), obj.Manifold.numFaces());
        end
    end
end
