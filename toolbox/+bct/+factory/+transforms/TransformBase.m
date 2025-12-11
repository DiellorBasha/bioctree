classdef (Abstract) TransformBase < handle
    %TRANSFORMBASE  Abstract base class for BCT transform operators.
    %
    % All transforms define:
    %   forward  - function handle for domain → dual
    %   inverse  - function handle for dual → domain
    %   metadata - struct with transform-specific info

    properties
        forward     % function handle
        inverse     % function handle
        metadata = struct();
    end

    methods
        function obj = TransformBase()
            % Base constructor does nothing; subclasses fill in fields.
        end
    end
end
