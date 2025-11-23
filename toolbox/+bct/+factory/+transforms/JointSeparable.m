classdef JointSeparable < bct.factory.transforms.TransformBase
    %JOINTSEPARABLE  Separable spatiotemporal transform for Joint domains
    %
    %   Composes 1D transforms from component domains to create a separable
    %   2D transform between Joint domains and their duals.
    %
    %   Example: (Manifold × Time) ↔ (Lambda × Omega)
    %
    %   Forward:  Apply spatial transform, then temporal transform
    %             Xhat(k,f) = FFT_time(GFT_space(X(v,t)))
    %
    %   Inverse:  Apply temporal inverse, then spatial inverse  
    %             X(v,t) = IGFT_space(IFFT_time(Xhat(k,f)))
    %
    %   This implements a separable transform where the spatial and temporal
    %   transforms are applied independently along their respective dimensions.
    %
    % Properties:
    %   Domain1 - First component domain (e.g., Manifold)
    %   Domain2 - Second component domain (e.g., Time)
    %
    % See also: bct.factory.transforms.TransformBase, bct.Joint

    properties
        Domain1        % First component domain (e.g., B.Manifold)
        Domain2        % Second component domain (e.g., B.Time)
    end

    methods
        function obj = JointSeparable(domain1, domain2)
            %JOINTSEPARABLE Construct separable joint transform
            %
            %   obj = JointSeparable(domain1, domain2)
            %
            % Inputs:
            %   domain1 - First domain with .transform property (e.g., Manifold)
            %   domain2 - Second domain with .transform property (e.g., Time)
            
            % Call base class constructor
            obj@bct.factory.transforms.TransformBase();

            % Validate inputs
            if ~isprop(domain1, 'transform') || isempty(domain1.transform)
                error('JointSeparable:NoTransform', ...
                    'Domain1 must have a valid transform property');
            end
            if ~isprop(domain2, 'transform') || isempty(domain2.transform)
                error('JointSeparable:NoTransform', ...
                    'Domain2 must have a valid transform property');
            end

            obj.Domain1 = domain1;
            obj.Domain2 = domain2;

            % Extract 1D transform handles from component domains
            spatialFwd  = domain1.transform.forward;
            spatialInv  = domain1.transform.inverse;
            temporalFwd = domain2.transform.forward;
            temporalInv = domain2.transform.inverse;

            % Define joint forward transform
            % Apply spatial transform to each time slice (column),
            % then temporal transform to each spatial mode (row)
            obj.forward = @(X) local_forward(X, spatialFwd, temporalFwd);

            % Define joint inverse transform
            % Apply temporal inverse to each row,
            % then spatial inverse to each column
            obj.inverse = @(Xhat) local_inverse(Xhat, spatialInv, temporalInv);

            % Store metadata
            obj.metadata.type        = 'Joint Separable Transform';
            obj.metadata.spatialType = class(domain1.transform);
            obj.metadata.timeType    = class(domain2.transform);
            obj.metadata.domain1Name = class(domain1);
            obj.metadata.domain2Name = class(domain2);
        end
    end
end


%% Local helper functions

function X_hat = local_forward(X, spatialFwd, temporalFwd)
    %LOCAL_FORWARD Apply separable forward transform
    %
    %   X_hat = local_forward(X, spatialFwd, temporalFwd)
    %
    % Input:
    %   X          - [N×T] signal on joint domain (N spatial, T temporal)
    %   spatialFwd - Function handle for spatial forward transform
    %   temporalFwd- Function handle for temporal forward transform
    %
    % Output:
    %   X_hat      - [N×T] transformed signal on dual joint domain
    
    [N, T] = size(X);
    
    % Step 1: Apply spatial transform to each time slice (column)
    %         X(v,t) → X_lambda(k,t) for each t
    X_lambda = zeros(N, T);
    for t = 1:T
        X_lambda(:, t) = spatialFwd(X(:, t));
    end
    
    % Step 2: Apply temporal transform to each spatial mode (row)
    %         X_lambda(k,t) → X_hat(k,f) for each k
    X_hat = zeros(N, T);
    for k = 1:N
        % Extract row, apply temporal transform, restore as row
        X_hat(k, :) = temporalFwd(X_lambda(k, :).').';
    end
end


function X = local_inverse(X_hat, spatialInv, temporalInv)
    %LOCAL_INVERSE Apply separable inverse transform
    %
    %   X = local_inverse(X_hat, spatialInv, temporalInv)
    %
    % Input:
    %   X_hat      - [N×T] signal on dual joint domain
    %   spatialInv - Function handle for spatial inverse transform
    %   temporalInv- Function handle for temporal inverse transform
    %
    % Output:
    %   X          - [N×T] reconstructed signal on original joint domain
    
    [N, T] = size(X_hat);
    
    % Step 1: Apply temporal inverse to each row
    %         X_hat(k,f) → X_lambda(k,t) for each k
    X_lambda = zeros(N, T);
    for k = 1:N
        % Extract row, apply temporal inverse, restore as row
        X_lambda(k, :) = temporalInv(X_hat(k, :).').';
    end
    
    % Step 2: Apply spatial inverse to each time slice (column)
    %         X_lambda(k,t) → X(v,t) for each t
    X = zeros(N, T);
    for t = 1:T
        X(:, t) = spatialInv(X_lambda(:, t));
    end
end
