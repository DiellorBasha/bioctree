classdef TestGraphOps < matlab.unittest.TestCase
    % TESTGRAPHOPS Unit tests for graph operations in Bioctree toolbox
    %
    % This test class validates the mathematical correctness of graph
    % differential operators including gradient, divergence, and total
    % variation computations.
    %
    % Run tests with:
    %   results = runtests('TestGraphOps');
    %   table(results)
    %
    % Test Categories:
    %   - Mathematical properties (adjoint relationships)
    %   - Numerical accuracy (known solutions)
    %   - Edge cases (isolated vertices, empty graphs)
    
    properties (TestParameter)
        % Test parameters for different graph configurations
        GraphSize = {10, 50, 100};
        WeightType = {'uniform', 'geodesic', 'cotangent'};
    end
    
    methods (TestMethodSetup)
        function setupPath(~)
            % Ensure toolbox is in path
            addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
        end
    end
    
    methods (Test)
        
        function testGradientDivergenceAdjoint(testCase, GraphSize)
            % Test adjoint relationship: <∇G x, y> = <x, -div_G y>
            
            % Create simple test graph
            G = createTestGraph(GraphSize);
            
            % Generate test signals
            rng(42);  % Reproducible results
            x = randn(G.N, 1);
            
            % Compute gradient of x
            gradX = graphGradient(G, x);
            
            % Generate edge field y
            Ne = size(gradX, 1);
            y = randn(Ne, 1);
            
            % Compute divergence of y
            divY = graphDivergence(G, y);
            
            % Test adjoint relationship
            lhs = gradX' * y;  % <∇G x, y>
            rhs = x' * (-divY);  % <x, -div_G y>
            
            testCase.verifyEqual(lhs, rhs, 'RelTol', 1e-10, ...
                'Gradient-divergence adjoint relationship failed');
        end
        
        function testLaplacianConsistency(testCase)
            % Test that div_G(∇G x) ≈ -L * x for smooth functions
            
            % Create test graph
            G = createTestGraph(50);
            
            % Generate smooth test signal (low-frequency eigenfunction)
            if isfield(G, 'U') && size(G.U, 2) >= 5
                % Use graph eigenvector
                x = G.U(:, 2);  % Second eigenvector (smooth)
            else
                % Compute eigenvector manually
                [U, ~] = eigs(G.L, 5, 'smallestreal');
                x = U(:, 2);
            end
            
            % Compute div(grad(x))
            gradX = graphGradient(G, x);
            divGradX = graphDivergence(G, gradX);
            
            % Compare with -L*x
            laplacianX = -G.L * x;
            
            % Compute relative error
            relError = norm(divGradX - laplacianX) / norm(laplacianX);
            
            testCase.verifyLessThan(relError, 1e-8, ...
                'div(grad(x)) should equal -L*x for smooth functions');
        end
        
        function testTotalVariationProperties(testCase)
            % Test properties of total variation operator
            
            G = createTestGraph(30);
            
            % Test TV of constant signal should be zero
            x_const = ones(G.N, 1);
            tv_const = graphTotalVariation(G, x_const);
            
            testCase.verifyEqual(tv_const, zeros(G.N, 1), 'AbsTol', 1e-12, ...
                'TV of constant signal should be zero');
            
            % Test TV is non-negative
            rng(123);
            x_random = randn(G.N, 1);
            tv_random = graphTotalVariation(G, x_random);
            
            testCase.verifyGreaterThanOrEqual(tv_random, zeros(G.N, 1), ...
                'Total variation should be non-negative');
            
            % Test TV scaling: TV(α*x) = |α| * TV(x)
            alpha = -2.5;
            tv_scaled = graphTotalVariation(G, alpha * x_random);
            tv_expected = abs(alpha) * tv_random;
            
            testCase.verifyEqual(tv_scaled, tv_expected, 'RelTol', 1e-12, ...
                'TV should scale linearly with signal amplitude');
        end
        
        function testMultipleTimePoints(testCase)
            % Test operators work correctly with multiple time points
            
            G = createTestGraph(25);
            T = 10;
            
            % Generate multi-time signal
            rng(456);
            X = randn(G.N, T);
            
            % Test gradient
            gradX = graphGradient(G, X);
            testCase.verifySize(gradX, [NaN, T], ...
                'Gradient should preserve number of time points');
            
            % Test that column-wise processing gives same result
            for t = 1:T
                gradX_t = graphGradient(G, X(:, t));
                testCase.verifyEqual(gradX(:, t), gradX_t, 'AbsTol', 1e-14, ...
                    'Column-wise gradient should match matrix processing');
            end
            
            % Test divergence
            divGradX = graphDivergence(G, gradX);
            testCase.verifySize(divGradX, [G.N, T], ...
                'Divergence should return to vertex domain');
        end
        
        function testEdgeCases(testCase)
            % Test handling of edge cases
            
            % Single vertex graph
            G_single = struct('W', sparse(1, 1), 'N', 1);
            G_single = ensureLaplacian(G_single);
            
            x_single = 1;
            grad_single = graphGradient(G_single, x_single);
            testCase.verifyEmpty(grad_single, ...
                'Single vertex should have empty gradient');
            
            % Disconnected graph
            W_disconnected = blkdiag(sparse([0 1; 1 0]), sparse([0 1; 1 0]));
            G_disconnected = struct('W', W_disconnected, 'N', 4);
            G_disconnected = ensureLaplacian(G_disconnected);
            
            x_disconnected = [1; 2; 3; 4];
            grad_disconnected = graphGradient(G_disconnected, x_disconnected);
            
            % Should work without errors
            testCase.verifySize(grad_disconnected, [2, 1], ...
                'Disconnected graph should still compute gradients');
        end
        
        function testNumericalStability(testCase)
            % Test numerical stability with ill-conditioned cases
            
            % Graph with very small weights
            G = createTestGraph(20);
            G.W = G.W * 1e-10;  % Very small weights
            G = ensureLaplacian(G);
            
            x = randn(G.N, 1);
            
            % Should not produce NaN or Inf
            grad = graphGradient(G, x);
            testCase.verifyTrue(all(isfinite(grad)), ...
                'Gradient should be finite even with small weights');
            
            tv = graphTotalVariation(G, x);
            testCase.verifyTrue(all(isfinite(tv)), ...
                'TV should be finite even with small weights');
        end
        
    end
    
end

function G = createTestGraph(N)
    % Create test graph for unit testing
    
    % Generate random geometric graph
    rng(42);  % Reproducible
    coords = randn(N, 2);
    
    % Connect vertices within distance threshold
    threshold = 1.5;
    D = pdist2(coords, coords);
    W = sparse(D < threshold);
    W = W - diag(diag(W));  % Remove self-loops
    W = (W + W') / 2;  % Ensure symmetry
    
    % Create graph structure
    G = struct();
    G.W = W;
    G.N = N;
    G.coords = coords;
    
    % Compute Laplacian
    G = ensureLaplacian(G);
    
end