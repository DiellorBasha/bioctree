classdef ColormapDefinition
    % ColormapDefinition
    %
    % Immutable definition of a colormap with semantic constraints.
    % A colormap is a function + metadata, not just an Nx3 matrix.

    properties (SetAccess = immutable)
        Name (1,1) string
        Category (1,1) bct.color.enum.ColormapCategory
        Domain (:,2) double  % Nx2: each row is [min, max] for one dimension
        Generator function_handle
        IsDiscrete (1,1) logical = false
        IsDiverging (1,1) logical = false
        ValidDataTypes cell = {'double','single'}
    end

    methods
        function obj = ColormapDefinition(varargin)
            % Constructor: accepts struct or name-value pairs
            
            % Handle struct input from colormapTable
            if nargin == 1 && isstruct(varargin{1})
                s = varargin{1};
                obj.Name = string(s.Name);
                obj.Category = s.Category;
                obj.Domain = s.Domain;
                obj.Generator = s.Generator;
                obj.IsDiscrete = s.IsDiscrete;
                obj.IsDiverging = s.IsDiverging;
                if isfield(s, 'ValidDataTypes')
                    obj.ValidDataTypes = s.ValidDataTypes;
                end
                return;
            end

            % Name-value constructor
            p = inputParser;
            p.addParameter('Name', "", @(x)isstring(x) || ischar(x));
            p.addParameter('Category', [], @(x)isa(x,'bct.color.enum.ColormapCategory'));
            p.addParameter('Domain', [0 1], @(x)isnumeric(x) && size(x,2)==2);
            p.addParameter('Generator', [], @(x)isa(x,'function_handle'));
            p.addParameter('IsDiscrete', false, @islogical);
            p.addParameter('IsDiverging', false, @islogical);
            p.addParameter('ValidDataTypes', {'double','single'}, @iscell);

            p.parse(varargin{:});
            r = p.Results;

            assert(~isempty(r.Name), 'ColormapDefinition:NameRequired');
            assert(~isempty(r.Category), 'ColormapDefinition:CategoryRequired');
            assert(~isempty(r.Generator), 'ColormapDefinition:GeneratorRequired');

            obj.Name = string(r.Name);
            obj.Category = r.Category;
            obj.Domain = r.Domain;
            obj.Generator = r.Generator;
            obj.IsDiscrete = r.IsDiscrete;
            obj.IsDiverging = r.IsDiverging;
            obj.ValidDataTypes = r.ValidDataTypes;
        end

        function C = sample(obj, N)
            % SAMPLE Generate Nx3 colormap matrix
            if nargin < 2
                N = 256;
            end
            C = obj.Generator(N);
            validateattributes(C, {'double','single'}, {'ncols',3});
        end
        
        function ndim = dimensionality(obj)
            % DIMENSIONALITY Get number of input dimensions
            % 1D: scalar field colormaps (Domain is 1x2)
            % 2D: vector field colormaps (Domain is 2x2)
            ndim = size(obj.Domain, 1);
        end
    end
end
