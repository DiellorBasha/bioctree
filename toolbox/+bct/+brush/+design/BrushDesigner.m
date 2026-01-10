classdef BrushDesigner < handle
    %BCT.BRUSH.DESIGN.BRUSHDESIGNER  Interactive brush design with parameter manipulation
    %
    %   BrushDesigner provides an interactive workflow for designing brushes:
    %   1. Create designer with category, type, and initial parameters
    %   2. Evaluate kernel on Lambda axis to preview spectral coverage
    %   3. Adjust parameters interactively
    %   4. Finalize to generate brush weights
    %
    % Properties:
    %   Category       - 'patch', 'trajectory', or 'time'
    %   BrushType      - Brush type name
    %   Manifold       - bct.Manifold object
    %   Time           - bct.Time object (for time category)
    %   Parameters     - Current parameter values
    %   KernelHandle   - Function handle for spectral kernel (if applicable)
    %   Lambda         - Lambda domain (from manifold.dual)
    %
    % Methods:
    %   BrushDesigner(category, type, manifold, params, time)  - Constructor
    %   setParameter(name, value)                               - Update parameter
    %   evaluateKernel()                                        - Evaluate kernel on Lambda
    %   evaluateKernel(lambda_values)                          - Evaluate at specific points
    %   plotKernelResponse()                                    - Visualize kernel
    %   finalize()                                              - Generate brush weights
    %
    % Example - Patch brush with spectral kernel:
    %   designer = bct.brush.design.BrushDesigner('patch', 'spectral', ...
    %       B.Manifold, struct('source', 100, 'kernel', 'gaussian', 'sigma', 15));
    %   
    %   % Preview kernel response
    %   H = designer.evaluateKernel();
    %   designer.plotKernelResponse();
    %   
    %   % Adjust sigma
    %   designer.setParameter('sigma', 20);
    %   designer.plotKernelResponse();
    %   
    %   % Finalize to get brush weights
    %   w = designer.finalize();
    %
    % Example - Time brush with time-varying parameters:
    %   designer = bct.brush.design.BrushDesigner('time', 'spectral', ...
    %       B.Manifold, struct('source', 100, 'kernel', 'heat', 'tau', 0.15), B.Time);
    %   
    %   % Evaluate kernel at current tau
    %   H = designer.evaluateKernel();
    %   
    %   % Change tau and re-evaluate
    %   designer.setParameter('tau', 0.25);
    %   H_new = designer.evaluateKernel();
    %   
    %   % Finalize
    %   w = designer.finalize();
    %
    % See also: bct.brush.design.brush, bct.filters.FilterDesigner
    
    properties
        Category        % 'patch', 'trajectory', 'time'
        BrushType       % Brush type name
        Manifold        % bct.Manifold
        Time            % bct.Time (optional)
        Parameters      % struct of current parameters
        KernelHandle    % function handle for kernel (if spectral)
        Lambda          % Lambda domain from manifold.dual
    end
    
    methods
        function obj = BrushDesigner(category, brushType, manifold, params, time)
            %BRUSHDESIGNER Constructor
            %
            %   designer = BrushDesigner(category, type, manifold, params)
            %   designer = BrushDesigner(category, type, manifold, params, time)
            
            arguments
                category (1,:) char
                brushType (1,:) char
                manifold (1,1) bct.Manifold
                params struct
                time = []
            end
            
            % Validate and store properties
            obj.Category = lower(category);
            obj.BrushType = lower(brushType);
            obj.Manifold = manifold;
            obj.Parameters = params;
            obj.Time = time;
            
            % Get Lambda domain for kernel evaluation
            obj.Lambda = manifold.dual;
            if isempty(obj.Lambda) || isempty(obj.Lambda.lambda)
                warning('BrushDesigner:NoLambda', ...
                    'Manifold dual (Lambda) not initialized. Kernel evaluation not available.');
            end
            
            % Extract kernel handle if this is a spectral brush
            obj.extractKernelHandle();
        end
        
        function setParameter(obj, name, value)
            %SETPARAMETER Update a parameter value
            %
            %   designer.setParameter('sigma', 20)
            %   designer.setParameter('tau', 0.2)
            
            obj.Parameters.(name) = value;
            
            % If kernel-related parameter changed, update kernel handle
            if ismember(name, {'kernel', 'tau', 'sigma', 'center', 'bandwidth'})
                obj.extractKernelHandle();
            end
        end
        
        function setParameters(obj, paramStruct)
            %SETPARAMETERS Update multiple parameters at once
            %
            %   designer.setParameters(struct('sigma', 20, 'bandwidth', 60))
            
            fields = fieldnames(paramStruct);
            for i = 1:length(fields)
                obj.Parameters.(fields{i}) = paramStruct.(fields{i});
            end
            
            % Update kernel handle
            obj.extractKernelHandle();
        end
        
        function H = evaluateKernel(obj, lambda_values)
            %EVALUATEKERNEL Evaluate spectral kernel on Lambda axis
            %
            %   H = designer.evaluateKernel()           % Use Lambda.lambda
            %   H = designer.evaluateKernel(lambda_vec) % Use custom values
            %
            % Returns:
            %   H - Kernel response at eigenvalues
            
            if isempty(obj.KernelHandle)
                error('BrushDesigner:NoKernel', ...
                    'Kernel handle not available. Only spectral brushes support kernel evaluation.');
            end
            
            if nargin < 2
                % Use Lambda axis
                if isempty(obj.Lambda) || isempty(obj.Lambda.lambda)
                    error('BrushDesigner:NoLambda', ...
                        'Lambda domain not initialized');
                end
                lambda_values = obj.Lambda.lambda;
            end
            
            % Evaluate kernel
            H = obj.KernelHandle(lambda_values);
        end
        
        function plotKernelResponse(obj)
            %PLOTKERNELRESPONSE Visualize kernel response on Lambda axis
            %
            %   designer.plotKernelResponse()
            
            if isempty(obj.KernelHandle)
                error('BrushDesigner:NoKernel', ...
                    'Kernel evaluation not available for non-spectral brushes');
            end
            
            % Evaluate kernel
            lambda = obj.Lambda.lambda;
            H = obj.evaluateKernel(lambda);
            
            % Plot
            figure('Name', 'Brush Kernel Response');
            
            subplot(2,1,1);
            plot(lambda, H, 'b-', 'LineWidth', 2);
            grid on;
            xlabel('Eigenvalue \lambda');
            ylabel('Kernel Response H(\lambda)');
            title(sprintf('%s %s - Kernel Response', obj.Category, obj.BrushType));
            
            % Add parameter info
            param_str = obj.getParameterString();
            text(0.02, 0.98, param_str, 'Units', 'normalized', ...
                'VerticalAlignment', 'top', 'FontSize', 9, ...
                'BackgroundColor', 'w', 'EdgeColor', 'k');
            
            subplot(2,1,2);
            semilogy(lambda, H, 'b-', 'LineWidth', 2);
            grid on;
            xlabel('Eigenvalue \lambda');
            ylabel('Kernel Response (log scale)');
            title('Log Scale View');
            
            % Highlight cutoff threshold
            hold on;
            threshold = 0.01;
            yline(threshold, 'r--', sprintf('%.1f%% threshold', threshold*100));
        end
        
        function w = finalize(obj)
            %FINALIZE Generate final brush weights
            %
            %   w = designer.finalize()
            %
            % Returns:
            %   w - Brush weights [N×1] or [N×T]
            
            % Call the underlying brush design function
            if strcmp(obj.Category, 'time')
                if isempty(obj.Time)
                    error('BrushDesigner:MissingTime', ...
                        'Time domain required for time category');
                end
                w = bct.brush.design.brush(obj.Category, obj.BrushType, ...
                    obj.Manifold, obj.Parameters, obj.Time);
            else
                w = bct.brush.design.brush(obj.Category, obj.BrushType, ...
                    obj.Manifold, obj.Parameters);
            end
        end
        
        function preview(obj, varargin)
            %PREVIEW Generate and visualize brush weights
            %
            %   designer.preview()              % Static brush
            %   designer.preview('TimeIndex', 50)  % Time brush at t=50
            
            p = inputParser;
            p.addParameter('TimeIndex', 1, @isnumeric);
            p.parse(varargin{:});
            
            % Generate weights
            w = obj.finalize();
            
            % Extract time slice if needed
            if strcmp(obj.Category, 'time')
                t_idx = p.Results.TimeIndex;
                w_plot = w(:, t_idx);
                title_suffix = sprintf(' (t=%d)', t_idx);
            else
                w_plot = w;
                title_suffix = '';
            end
            
            % Plot
            figure('Name', 'Brush Preview');
            obj.Manifold.plot('data', full(w_plot), 'shading', 'interp');
            colormap(jet); colorbar;
            title(sprintf('%s %s%s', obj.Category, obj.BrushType, title_suffix));
            axis equal tight off;
            view([0 90]);
        end
    end
    
    methods (Access = private)
        function extractKernelHandle(obj)
            %EXTRACTKERNELHANDLE Get kernel function handle for spectral brushes
            
            obj.KernelHandle = [];
            
            % Only applicable for spectral brushes
            if ~strcmp(obj.BrushType, 'spectral')
                return;
            end
            
            % Check if kernel parameter exists
            if ~isfield(obj.Parameters, 'kernel')
                return;
            end
            
            if isempty(obj.Lambda) || isempty(obj.Lambda.lambda)
                return;
            end
            
            % Build kernel parameters
            kernel_name = obj.Parameters.kernel;
            kernel_params = struct();
            
            % Extract kernel-specific parameters
            param_map = struct(...
                'tau', 'tau', ...
                'sigma', 'sigma', ...
                'center', 'mu', ...
                'bandwidth', 'bandwidth');
            
            param_fields = fieldnames(param_map);
            for i = 1:length(param_fields)
                pname = param_fields{i};
                if isfield(obj.Parameters, pname)
                    % Handle function handles (time-varying params)
                    pval = obj.Parameters.(pname);
                    if isa(pval, 'function_handle')
                        % Evaluate at t=1 for preview
                        if strcmp(obj.Category, 'time') && ~isempty(obj.Time)
                            pval = pval(1, obj.Time.N);
                        else
                            pval = pval(1, 100);  % Default
                        end
                    end
                    kernel_params.(param_map.(pname)) = pval;
                end
            end
            
            % Special handling for heat kernel (needs lambda_max)
            if strcmp(kernel_name, 'heat')
                lambda_max = max(obj.Lambda.lambda);
                lambda_norm = obj.Lambda.lambda / lambda_max;
                obj.KernelHandle = @(x) exp(-kernel_params.tau * (x / lambda_max));
                return;
            end
            
            % Create kernel using registry
            try
                g = bct.filter.design.kernel(kernel_name, kernel_params, obj.Lambda.lambda);
                obj.KernelHandle = g;
            catch
                warning('BrushDesigner:KernelError', ...
                    'Could not create kernel handle for %s', kernel_name);
            end
        end
        
        function str = getParameterString(obj)
            %GETPARAMETERSTRING Format parameters for display
            
            fields = fieldnames(obj.Parameters);
            lines = {};
            for i = 1:length(fields)
                fname = fields{i};
                fval = obj.Parameters.(fname);
                if isnumeric(fval) && isscalar(fval)
                    lines{end+1} = sprintf('%s: %.3g', fname, fval); %#ok<AGROW>
                elseif ischar(fval) || isstring(fval)
                    lines{end+1} = sprintf('%s: %s', fname, fval); %#ok<AGROW>
                end
            end
            str = strjoin(lines, '\n');
        end
    end
end
