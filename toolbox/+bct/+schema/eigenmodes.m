function spec = eigenmodes()
%EIGENMODES Return canonical schema specification for BCT eigenmodes structure
%
% Syntax:
%   spec = bct.schema.eigenmodes()
%
% Description:
%   Defines the authoritative schema for eigenmode structures in BCT.
%   An eigenmode structure contains:
%     - .attributes: Group-level metadata (extends bct.schema.group)
%     - .eigenvalues: Dataset with eigenvalue array (.value, .attributes)
%     - .eigenvectors: Dataset with eigenvector matrix (.value, .attributes)
%
%   This schema is used by bct.manifold.eigenmodes() and related functions
%   to ensure consistency in eigenmode representation across BCT.
%
% Outputs:
%   spec - Structure with fields:
%     .name        - Schema name
%     .version     - Schema version string
%     .description - Human-readable description
%     .attributes  - Group attributes specification
%     .datasets    - Dataset specifications (eigenvalues, eigenvectors)
%     .validation  - Validation function handles
%
% Eigenmode Structure:
%   Eigen = struct(...
%       'attributes', struct(...
%           'path', '/eigenmodes', ...
%           'schema', 'bct.manifold.eigen@1.0.0', ...
%           'package', 'bct.manifold.eigen', ...
%           'numModes', 100, ...
%           'numVertices', 28576, ...
%           'operator', 'Laplace-Beltrami', ...
%           'basis', 'P1-FEM', ...
%           'ordering', 'ascending', ...
%           'massType', 'voronoi', ...
%           'removedDC', false), ...
%       'eigenvalues', struct(...
%           'value', eigenvalues, ... % [k×1] eigenvalues
%           'attributes', attrs), ... % Dataset metadata
%       'eigenvectors', struct(...
%           'value', eigenvectors, ... % [N×k] eigenvectors
%           'attributes', attrs))     % Dataset metadata
%
% Examples:
%   % Get eigenmode schema
%   spec = bct.schema.eigenmodes();
%
%   % Validate eigenmode structure
%   M = bct.Manifold(V, F);
%   Eigen = bct.manifold.eigenmodes(M, 100);
%   isValid = bct.schema.eigenmodes.validate(Eigen);
%
% See also: bct.manifold.eigenmodes, bct.schema.group, bct.schema.dataset

% Schema metadata
spec.name = "bct.eigenmodes";
spec.version = "1.0.0";
spec.description = "Schema for eigenmode structures (Laplace-Beltrami spectral decomposition)";
spec.package = "bct.schema";

%% Group Attributes (extends bct.schema.group)
spec.attributes = struct();

% Base fields (from bct.schema.group)
spec.attributes.base = struct(...
    'path', '/eigenmodes', ...
    'schema', 'bct.manifold.eigen@1.0.0', ...
    'package', 'bct.manifold.eigen');

% Eigenmode-specific required fields
spec.attributes.required = struct();

spec.attributes.required.numModes = struct(...
    'type', 'numeric', ...
    'description', 'Number of eigenmodes computed', ...
    'validate', @(x) isnumeric(x) && isscalar(x) && x > 0);

spec.attributes.required.numVertices = struct(...
    'type', 'numeric', ...
    'description', 'Number of vertices in manifold', ...
    'validate', @(x) isnumeric(x) && isscalar(x) && x > 0);

spec.attributes.required.operator = struct(...
    'type', 'string', ...
    'description', 'Differential operator (e.g., "Laplace-Beltrami")', ...
    'allowedValues', ["Laplace-Beltrami", "Hodge-Laplacian-0", "Hodge-Laplacian-1", "Hodge-Laplacian-2"]);

spec.attributes.required.basis = struct(...
    'type', 'string', ...
    'description', 'Finite element basis (e.g., "P1-FEM")', ...
    'allowedValues', ["P1-FEM", "P0-FEM", "DEC"]);

spec.attributes.required.ordering = struct(...
    'type', 'string', ...
    'description', 'Eigenvalue ordering', ...
    'allowedValues', ["ascending", "descending"]);

% Eigenmode-specific optional fields
spec.attributes.optional = struct();

spec.attributes.optional.massType = struct(...
    'type', 'string', ...
    'description', 'Mass matrix type used', ...
    'allowedValues', ["voronoi", "barycentric", "full"], ...
    'default', "voronoi");

spec.attributes.optional.removedDC = struct(...
    'type', 'logical', ...
    'description', 'Whether DC component was removed', ...
    'default', false);

spec.attributes.optional.tolerance = struct(...
    'type', 'numeric', ...
    'description', 'Eigensolver convergence tolerance', ...
    'default', []);

%% Dataset Specifications

% Eigenvalues dataset
spec.datasets.eigenvalues = struct();
spec.datasets.eigenvalues.name = 'eigenvalues';
spec.datasets.eigenvalues.path = '/eigenmodes/eigenvalues';
spec.datasets.eigenvalues.description = 'Eigenvalues of the Laplace-Beltrami operator (sorted ascending)';
spec.datasets.eigenvalues.shape = @(k) [k, 1];  % [k×1] where k = numModes
spec.datasets.eigenvalues.dtype = 'double';
spec.datasets.eigenvalues.support = 'none';
spec.datasets.eigenvalues.units = '1/m^2';  % For Laplacian eigenvalues (spectral units)
spec.datasets.eigenvalues.validate = @validateEigenvalues;

% Eigenvectors dataset
spec.datasets.eigenvectors = struct();
spec.datasets.eigenvectors.name = 'eigenvectors';
spec.datasets.eigenvectors.path = '/eigenmodes/eigenvectors';
spec.datasets.eigenvectors.description = 'Eigenvectors of the Laplace-Beltrami operator (M-orthonormal columns)';
spec.datasets.eigenvectors.shape = @(N, k) [N, k];  % [N×k] where N = numVertices, k = numModes
spec.datasets.eigenvectors.dtype = 'double';
spec.datasets.eigenvectors.support = 'vertex';
spec.datasets.eigenvectors.units = '1';  % Dimensionless (normalized)
spec.datasets.eigenvectors.validate = @validateEigenvectors;

%% Structure Specification
spec.structure = struct();
spec.structure.required = ["attributes", "eigenvalues", "eigenvectors"];
spec.structure.description = 'Eigenmode structure must have attributes, eigenvalues, and eigenvectors fields';

%% Validation
spec.validate = @validateEigenmodes;

%% Helper Functions
spec.make = @makeEigenmodes;

%% Documentation
spec.documentation = struct(...
    'purpose', 'Enforce uniform eigenmode structure across BCT', ...
    'usage', 'All eigenmode computations should return this structure', ...
    'examples', struct(...
        'compute', 'Eigen = bct.manifold.eigenmodes(M, 100)', ...
        'validate', 'bct.schema.eigenmodes.validate(Eigen)', ...
        'access', 'eigenvalues = Eigen.eigenvalues.value; eigenvectors = Eigen.eigenvectors.value'));

end

%% =================================================================
%% VALIDATION FUNCTIONS
%% =================================================================

function validateEigenvalues(data)
    %VALIDATEEIGENVALUES Validate eigenvalue array
    %
    % Requirements:
    %   - Must be numeric vector
    %   - Must be real-valued
    %   - Should be sorted ascending (warning if not)
    
    if ~isnumeric(data) || ~isvector(data)
        error('bct:schema:eigenmodes:InvalidEigenvalues', ...
            'Eigenvalues must be a numeric vector');
    end
    
    if ~isreal(data)
        error('bct:schema:eigenmodes:ComplexEigenvalues', ...
            'Eigenvalues must be real-valued');
    end
    
    % Check if sorted (warning only)
    if ~issorted(data)
        warning('bct:schema:eigenmodes:UnsortedEigenvalues', ...
            'Eigenvalues are not sorted in ascending order');
    end
end

function validateEigenvectors(data)
    %VALIDATEEIGENVECTORS Validate eigenvector matrix
    %
    % Requirements:
    %   - Must be numeric matrix
    %   - Must be real-valued (for Laplacian)
    %   - Should have unit-norm columns (warning if not)
    
    if ~isnumeric(data) || ~ismatrix(data)
        error('bct:schema:eigenmodes:InvalidEigenvectors', ...
            'Eigenvectors must be a numeric matrix');
    end
    
    if ~isreal(data)
        warning('bct:schema:eigenmodes:ComplexEigenvectors', ...
            'Eigenvectors are complex-valued (expected for non-Hermitian operators)');
    end
    
    % Check column norms (warning only, as they should be M-orthonormal not L2-orthonormal)
    colNorms = sqrt(sum(data.^2, 1));
    if any(abs(colNorms - 1) > 1e-6)
        % Note: This is L2 norm, actual check should be with mass matrix
        % U' * M * U = I, but we don't have M here
        warning('bct:schema:eigenmodes:NonUnitNorm', ...
            'Eigenvector columns do not have unit L2 norm (expected for M-orthonormality)');
    end
end

function isValid = validateEigenmodes(Eigen, varargin)
    %VALIDATEEIGENMODES Validate complete eigenmode structure
    %
    % Inputs:
    %   Eigen - Eigenmode structure to validate
    %
    % Name-Value Arguments:
    %   Strict - true (default) to throw errors, false to return report
    %
    % Outputs:
    %   isValid - true if valid, false otherwise
    
    p = inputParser;
    p.addRequired('Eigen');
    p.addParameter('Strict', true, @islogical);
    p.parse(Eigen, varargin{:});
    
    strict = p.Results.Strict;
    
    try
        % Get schema
        spec = bct.schema.eigenmodes();
        
        %% Check required fields
        if ~isstruct(Eigen)
            error('bct:schema:eigenmodes:NotStruct', 'Eigenmode must be a struct');
        end
        
        requiredFields = spec.structure.required;
        for i = 1:numel(requiredFields)
            field = requiredFields(i);
            if ~isfield(Eigen, field)
                error('bct:schema:eigenmodes:MissingField', ...
                    'Required field missing: %s', field);
            end
        end
        
        %% Validate group attributes (base + eigenmode-specific)
        attrs = Eigen.attributes;
        
        % Validate base group fields
        bct.schema.group.validate(attrs);
        
        % Validate eigenmode-specific required fields
        requiredAttrs = fieldnames(spec.attributes.required);
        for i = 1:numel(requiredAttrs)
            fieldName = requiredAttrs{i};
            if ~isfield(attrs, fieldName)
                error('bct:schema:eigenmodes:MissingAttribute', ...
                    'Required attribute missing: %s', fieldName);
            end
            
            % Validate field
            fieldSpec = spec.attributes.required.(fieldName);
            value = attrs.(fieldName);
            
            % Type check
            if isfield(fieldSpec, 'type')
                switch fieldSpec.type
                    case 'numeric'
                        if ~isnumeric(value)
                            error('bct:schema:eigenmodes:InvalidType', ...
                                'Attribute %s must be numeric', fieldName);
                        end
                    case 'string'
                        if ~isstring(value) && ~ischar(value)
                            error('bct:schema:eigenmodes:InvalidType', ...
                                'Attribute %s must be string', fieldName);
                        end
                    case 'logical'
                        if ~islogical(value)
                            error('bct:schema:eigenmodes:InvalidType', ...
                                'Attribute %s must be logical', fieldName);
                        end
                end
            end
            
            % Allowed values check
            if isfield(fieldSpec, 'allowedValues')
                if isstring(value) || ischar(value)
                    value = string(value);
                end
                if ~ismember(value, fieldSpec.allowedValues)
                    error('bct:schema:eigenmodes:InvalidValue', ...
                        'Attribute %s has invalid value "%s"', fieldName, string(value));
                end
            end
            
            % Custom validation
            if isfield(fieldSpec, 'validate') && isa(fieldSpec.validate, 'function_handle')
                fieldSpec.validate(value);
            end
        end
        
        %% Validate datasets
        % Eigenvalues
        bct.schema.dataset.validate(Eigen.eigenvalues);
        spec.datasets.eigenvalues.validate(Eigen.eigenvalues.value);
        
        % Eigenvectors
        bct.schema.dataset.validate(Eigen.eigenvectors);
        spec.datasets.eigenvectors.validate(Eigen.eigenvectors.value);
        
        %% Cross-validate dimensions
        k_attrs = double(attrs.numModes);
        N_attrs = double(attrs.numVertices);
        
        k_data = size(Eigen.eigenvalues.value, 1);
        [N_data, k_data2] = size(Eigen.eigenvectors.value);
        
        if k_attrs ~= k_data
            error('bct:schema:eigenmodes:DimensionMismatch', ...
                'numModes (%d) does not match eigenvalues size (%d)', k_attrs, k_data);
        end
        
        if N_attrs ~= N_data
            error('bct:schema:eigenmodes:DimensionMismatch', ...
                'numVertices (%d) does not match eigenvectors size (%d)', N_attrs, N_data);
        end
        
        if k_data ~= k_data2
            error('bct:schema:eigenmodes:DimensionMismatch', ...
                'Eigenvalues (%d) and eigenvectors (%d) have inconsistent mode counts', ...
                k_data, k_data2);
        end
        
        %% Validation passed
        isValid = true;
        
    catch ME
        if strict
            rethrow(ME);
        end
        warning('bct:schema:eigenmodes:ValidationFailed', ...
            'Eigenmode validation failed: %s', ME.message);
        isValid = false;
    end
end

function Eigen = makeEigenmodes(eigenvalues, eigenvectors, varargin)
    %MAKEEIGENMODES Create schema-compliant eigenmode structure
    %
    % Syntax:
    %   Eigen = bct.schema.eigenmodes.make(eigenvalues, eigenvectors, 'operator', ...)
    %
    % Inputs:
    %   eigenvalues  - [k×1] eigenvalues
    %   eigenvectors - [N×k] eigenvectors
    %
    % Required Name-Value Arguments:
    %   operator - Operator name (e.g., 'Laplace-Beltrami')
    %
    % Optional Name-Value Arguments:
    %   basis      - Basis type (default: 'P1-FEM')
    %   ordering   - Eigenvalue ordering (default: 'ascending')
    %   massType   - Mass matrix type (default: 'voronoi')
    %   removedDC  - DC removed flag (default: false)
    %
    % Examples:
    %   Eigen = bct.schema.eigenmodes.make(eigenvalues, eigenvectors, ...
    %       'operator', 'Laplace-Beltrami', ...
    %       'massType', 'voronoi');
    
    p = inputParser;
    p.addRequired('eigenvalues', @(x) isnumeric(x) && isvector(x));
    p.addRequired('eigenvectors', @(x) isnumeric(x) && ismatrix(x));
    p.addParameter('operator', 'Laplace-Beltrami', @(x) ischar(x) || isstring(x));
    p.addParameter('basis', 'P1-FEM', @(x) ischar(x) || isstring(x));
    p.addParameter('ordering', 'ascending', @(x) ischar(x) || isstring(x));
    p.addParameter('massType', 'voronoi', @(x) ischar(x) || isstring(x));
    p.addParameter('removedDC', false, @islogical);
    p.parse(eigenvalues, eigenvectors, varargin{:});
    
    eigenvalues = eigenvalues(:);  % Ensure column vector
    [N, k] = size(eigenvectors);
    
    if length(eigenvalues) ~= k
        error('bct:schema:eigenmodes:DimensionMismatch', ...
            'Eigenvalue count (%d) must match eigenvector columns (%d)', length(eigenvalues), k);
    end
    
    % Create group attributes
    Eigen.attributes = bct.schema.group.make(...
        'path', '/eigenmodes', ...
        'schema', 'bct.manifold.eigen@1.0.0', ...
        'package', 'bct.manifold.eigen');
    
    % Add eigenmode-specific attributes
    Eigen.attributes.numModes = k;
    Eigen.attributes.numVertices = N;
    Eigen.attributes.operator = string(p.Results.operator);
    Eigen.attributes.basis = string(p.Results.basis);
    Eigen.attributes.ordering = string(p.Results.ordering);
    Eigen.attributes.massType = string(p.Results.massType);
    Eigen.attributes.removedDC = p.Results.removedDC;
    
    % Create eigenvalues dataset
    Eigen.eigenvalues = bct.schema.dataset.make(eigenvalues, ...
        'name', 'eigenvalues', ...
        'path', '/eigenmodes/eigenvalues', ...
        'description', 'Eigenvalues of the Laplace-Beltrami operator (sorted ascending)', ...
        'units', '1/m^2', ...
        'support', 'none', ...
        'computedBy', 'bct.manifold.eigenmodes');
    
    % Create eigenvectors dataset
    Eigen.eigenvectors = bct.schema.dataset.make(eigenvectors, ...
        'name', 'eigenvectors', ...
        'path', '/eigenmodes/eigenvectors', ...
        'description', 'Eigenvectors of the Laplace-Beltrami operator (M-orthonormal columns)', ...
        'units', '1', ...
        'support', 'vertex', ...
        'computedBy', 'bct.manifold.eigenmodes');
    
    % Validate
    bct.schema.eigenmodes.validate(Eigen);
end
