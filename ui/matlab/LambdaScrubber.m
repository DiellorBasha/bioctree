classdef LambdaScrubber < BaseScrubber
    % LambdaScrubber - Scrubber configured for spatial eigenmode domain
    %
    % LambdaScrubber is a thin wrapper around BaseScrubber that configures
    % the axis for spatial eigenmode operations. It sets:
    %   - Axis range from Lambda domain object
    %   - Label: "Eigenmode"
    %   - Scientific notation for eigenvalues
    %   - Eigenmode index snapping
    %
    % Usage:
    %   % From Lambda domain object
    %   lambdaScrubber = LambdaScrubber(lambdaObj);
    %
    %   % Manual configuration
    %   lambdaScrubber = LambdaScrubber();
    %   lambdaScrubber.configureFromLambda(eigenvalues);
    %
    % See also: BaseScrubber, TimeScrubber, OmegaScrubber
    
    methods
        function obj = LambdaScrubber(lambdaObj)
            % Construct LambdaScrubber from Lambda domain object
            %
            % Input:
            %   lambdaObj - (optional) bct.Lambda object
            
            obj@BaseScrubber();
            
            if nargin > 0 && ~isempty(lambdaObj)
                obj.configureFromLambda(lambdaObj);
            end
        end
        
        function configureFromLambda(obj, lambdaObj)
            % Configure scrubber from Lambda domain object or eigenvalues
            %
            % Usage:
            %   configureFromLambda(lambdaObj)      % From bct.Lambda object
            %   configureFromLambda(eigenvalues)    % From eigenvalue array
            
            if isobject(lambdaObj) && isa(lambdaObj, 'bct.Lambda')
                % Extract eigenvalues from Lambda object
                eigenvalues = lambdaObj.lambda;
            else
                % Direct eigenvalue specification
                eigenvalues = lambdaObj;
            end
            
            % Axis range: min to max eigenvalue
            lambdaMin = min(eigenvalues);
            lambdaMax = max(eigenvalues);
            
            % Create tick formatter (scientific notation for large values)
            tickFormatter = @(lam) obj.formatEigenvalue(lam);
            
            % Create snap function (snap to nearest eigenvalue)
            snapFunction = @(lam) obj.snapToEigenvalue(lam, eigenvalues);
            
            % Configure axis
            obj.setAxis(lambdaMin, lambdaMax, 'Eigenmode', 'lambda', ...
                       tickFormatter, snapFunction);
        end
    end
    
    methods (Static, Access = private)
        function str = formatEigenvalue(lam)
            % Format eigenvalue for display
            
            if abs(lam) >= 1000
                % Use scientific notation for large values
                str = sprintf('%.2e', lam);
            elseif abs(lam) >= 10
                % Standard notation for medium values
                str = sprintf('%.1f', lam);
            else
                % Higher precision for small values
                str = sprintf('%.3f', lam);
            end
        end
        
        function snapped = snapToEigenvalue(lam, eigenvalues)
            % Snap to nearest eigenvalue in array
            
            [~, idx] = min(abs(eigenvalues - lam));
            snapped = eigenvalues(idx);
        end
    end
end
