classdef test_dec_integration < BaseBctTest
    % TEST_DEC_INTEGRATION Integration tests for DEC operators via new operator system
    %
    % Tests DEC operators through the new registry/runtime system:
    % - Operator discovery and binding
    % - Gradient, divergence, curl operations
    % - Mathematical consistency (d²=0, curl(grad)=0)
    
    methods (Test)
        function testDECOperatorsAvailable(testCase)
            % Test that DEC operators are available when DECLab present
            
            % Skip if DECLab not available
            if exist('DiscreteExteriorCalculus', 'class') ~= 8
                testCase.verifyTrue(true, 'DECLab not available, skipping');
                return;
            end
            
            % Load test mesh
            mesh = testCase.loadTestMesh();
            M = bct.Manifold(mesh);
            ctx = bct.runtime.context(M);
            ops = bct.runtime.operators.dictionary(ctx);
            
            % Verify DEC operators present
            testCase.verifyTrue(isKey(ops, "gradient.dec"));
            testCase.verifyTrue(isKey(ops, "divergence.dec"));
            testCase.verifyTrue(isKey(ops, "curl.dec"));
        end
        
        function testGradientOperation(testCase)
            % Test gradient operator execution
            
            % Skip if DECLab not available
            if exist('DiscreteExteriorCalculus', 'class') ~= 8
                testCase.verifyTrue(true, 'DECLab not available, skipping');
                return;
            end
            
            % Setup
            mesh = testCase.loadTestMesh();
            M = bct.Manifold(mesh);
            ctx = bct.runtime.context(M);
            ops = bct.runtime.operators.dictionary(ctx);
            
            % Create test scalar field
            nV = size(M.Vertices, 1);
            f0 = randn(nV, 1);
            
            % Execute gradient
            gradFn = ops("gradient.dec");
            gradF = gradFn(f0);
            
            % Verify output dimensions
            nF = size(M.Faces, 1);
            testCase.verifySize(gradF, [nF, 3]);
        end
        
        function testDivergenceOperation(testCase)
            % Test divergence operator execution
            
            % Skip if DECLab not available
            if exist('DiscreteExteriorCalculus', 'class') ~= 8
                testCase.verifyTrue(true, 'DECLab not available, skipping');
                return;
            end
            
            % Setup
            mesh = testCase.loadTestMesh();
            M = bct.Manifold(mesh);
            ctx = bct.runtime.context(M);
            ops = bct.runtime.operators.dictionary(ctx);
            
            % Create test vector field
            nF = size(M.Faces, 1);
            U = randn(nF, 3);
            
            % Execute divergence
            divFn = ops("divergence.dec");
            divU = divFn(U);
            
            % Verify output dimensions
            nV = size(M.Vertices, 1);
            testCase.verifySize(divU, [nV, 1]);
        end
        
        function testCurlOfGradientIsZero(testCase)
            % Test mathematical identity: curl(grad(f)) = 0
            
            % Skip if DECLab not available
            if exist('DiscreteExteriorCalculus', 'class') ~= 8
                testCase.verifyTrue(true, 'DECLab not available, skipping');
                return;
            end
            
            % Setup
            mesh = testCase.loadTestMesh();
            M = bct.Manifold(mesh);
            ctx = bct.runtime.context(M);
            ops = bct.runtime.operators.dictionary(ctx);
            
            % Create test scalar field
            nV = size(M.Vertices, 1);
            f0 = randn(nV, 1);
            
            % Compute curl(grad(f))
            gradFn = ops("gradient.dec");
            curlFn = ops("curl.dec");
            
            gradF = gradFn(f0);
            curlGradF = curlFn(gradF);
            
            % Verify curl(grad) ≈ 0
            maxError = max(abs(curlGradF));
            testCase.verifyLessThan(maxError, 1e-10, ...
                'curl(grad(f)) should be numerically zero');
        end
        
        function testExteriorDerivativeSquaredIsZero(testCase)
            % Test mathematical identity: d² = 0 (d∘d = 0)
            
            % Skip if DECLab not available
            if exist('DiscreteExteriorCalculus', 'class') ~= 8
                testCase.verifyTrue(true, 'DECLab not available, skipping');
                return;
            end
            
            % Setup
            mesh = testCase.loadTestMesh();
            M = bct.Manifold(mesh);
            dec = M.DEC();
            
            % Get exterior derivatives
            d0 = dec.d0;  % 0-forms → 1-forms
            d1 = dec.d1;  % 1-forms → 2-forms
            
            % Compute d1 ∘ d0
            d0d0 = d1 * d0;
            
            % Verify d² = 0
            maxError = full(max(abs(d0d0(:))));
            testCase.verifyLessThan(maxError, 1e-10, ...
                'd² = 0 (boundary of boundary is zero)');
        end
    end
end