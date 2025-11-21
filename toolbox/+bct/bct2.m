classdef bct2 < handle
    %BCT2  Minimal container for new domain architecture.

    properties
        Manifold    % manifold domain
        Lambda      % spectral domain
        Time        % temporal domain
        Omega       % temporal spectral domain
    end

    methods
        % ---------------------------------------------------------------
        function obj = bct2(meshStruct, eigenStruct, timeVector, fs)

            % ---- Manifold (geometry) ----
            obj.Manifold = bct.Manifold(meshStruct);

            % ---- Lambda (spectral) ----
            obj.Lambda = bct.Lambda(eigenStruct);

            % Link duals
            obj.Manifold.setDual(obj.Lambda);

            % ---- Time domain ----
            obj.Time = bct.Time(timeVector, fs);

            % ---- Omega domain ----
            obj.Omega = bct.Omega(obj.Time);

            % Link duals
            obj.Time.setDual(obj.Omega);

            % ---- Initialize transforms ----
            obj.initializeAllTransforms();
        end

        % ---------------------------------------------------------------
        function initializeAllTransforms(obj)
            % Initialize transform objects for each dual pair
            obj.Manifold.initializeTransform();
            obj.Lambda.initializeTransform();
            obj.Time.initializeTransform();
            obj.Omega.initializeTransform();
        end

        % ---------------------------------------------------------------
        function showSummary(obj)
            fprintf("\n=== BCT2 Summary ===\n");
            fprintf("Manifold: %s\n", obj.Manifold.name);
            fprintf("Lambda:   %s\n", obj.Lambda.name);
            fprintf("Time:     %s\n", obj.Time.name);
            fprintf("Omega:    %s\n", obj.Omega.name);

            fprintf("\nDual mapping:\n");
            fprintf("  Manifold.dual -> %s\n", obj.Manifold.dual.name);
            fprintf("  Lambda.dual   -> %s\n", obj.Lambda.dual.name);
            fprintf("  Time.dual     -> %s\n", obj.Time.dual.name);
            fprintf("  Omega.dual    -> %s\n", obj.Omega.dual.name);
        end
    end
end
