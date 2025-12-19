classdef KernelModel < handle
    % Axis-aware kernel state engine

    properties (SetObservable)
        Axis double
        KernelType char
        Parameters struct
        KernelFunction function_handle
    end

    properties (Access = private)
        Registry struct
        IsInitializing logical = false
    end

    methods
        function obj = KernelModel(axis)

            if nargin < 1
                axis = linspace(-5,5,600);
            end

            obj.IsInitializing = true;

            % Initialize registry FIRST
            obj.Registry = KernelRegistry.getRegistry();

            % Initialize kernel type FIRST
            obj.KernelType = 'Heat';

            % Initialize axis LAST
            obj.Axis = axis;

            % Initialize parameters + kernel
            obj.resetParameters();
            obj.updateKernel();

            obj.IsInitializing = false;
        end

        % ----------------------------------------------------------
        function set.Axis(obj, axis)
            obj.Axis = axis;

            if obj.IsInitializing
                return;
            end

            obj.resetParameters();
            obj.updateKernel();
        end

        % ----------------------------------------------------------
        function set.KernelType(obj, type)
            obj.KernelType = type;

            if obj.IsInitializing
                return;
            end

            obj.resetParameters();
            obj.updateKernel();
        end

        % ----------------------------------------------------------
        function set.Parameters(obj, p)
            obj.Parameters = p;

            if obj.IsInitializing
                return;
            end

            obj.updateKernel();
        end
    end

    methods (Access = private)

        function resetParameters(obj)

            if isempty(obj.KernelType)
                return;
            end

            if ~isfield(obj.Registry, obj.KernelType)
                error('KernelModel:UnknownKernel', ...
                      'Unknown kernel type: %s', obj.KernelType);
            end

            k = obj.Registry.(obj.KernelType);
            obj.Parameters = k.DefaultParams(obj.Axis);
        end
    end
    
    methods (Access = public)
        function updateKernel(obj)

            if isempty(obj.KernelType) || isempty(obj.Parameters)
                return;
            end

            k = obj.Registry.(obj.KernelType);
            obj.KernelFunction = k.Function(obj.Parameters);
        end
    end
end
