classdef (Abstract) Operator
    %BCT.OPERATOR.OPERATOR
    %   Abstract base class for all signal operators.
    %
    %   Operators:
    %     - are stateless
    %     - transform Signal -> Signal
    %     - may depend on Domains
    %     - never hold UI state

    properties (SetAccess = protected)
        Name string
        InputDomainClass string   % e.g., "bct.Manifold", "bct.Lambda"
        OutputDomainClass string
    end

    methods (Abstract)
        out = apply(obj, in)
    end

    methods
        function tf = isCompatible(obj, signal)
            tf = isa(signal, 'bct.Signal') && ...
                 isa(signal.Domain, obj.InputDomainClass);
        end
    end
end
