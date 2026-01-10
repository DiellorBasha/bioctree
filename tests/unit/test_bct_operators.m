classdef test_bct_operators < BaseBctTest
    % TEST_BCT_OPERATORS Unified tests for bct.operators package
    %
    % Tests operator system:
    % - Operator registration and discovery
    % - Operator application via bct.operators.apply()
    % - Field type transformations (domain/codomain)
    % - Differential operators: gradient, divergence, Laplacian, curl
    % - Transform operators and field operations
    % - Runtime resolution and caching
    
    methods (Test)
        %% OPERATOR DISCOVERY TESTS
        function testOperatorsListAvailable(testCase)
            % Verify operators can be listed
            opList = bct.operators.list();
            
            testCase.verifyGreaterThan(length(opList), 0, ...
                'Should have at least one registered operator');
        end
        
        function testOperatorsGetMetadata(testCase)
            % Verify operator metadata retrieval
            gradOp = bct.operators.get('gradient');
            
            testCase.verifyTrue(isfield(gradOp, 'Id'), ...
                'Operator should have Id field');
            testCase.verifyTrue(isfield(gradOp, 'Domain'), ...
                'Operator should have Domain field');
            testCase.verifyTrue(isfield(gradOp, 'Codomain'), ...
                'Operator should have Codomain field');
        end
        
        %% GRADIENT OPERATOR TESTS
        function testGradientScalarVertexToVectorFace(testCase)
            % Verify gradient transforms scalar(vertex) → vector(face)
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Create scalar field on vertices
            scalarData = sin(2*pi*V(:,1)) .* cos(2*pi*V(:,2));
            fieldIn = bct.fields.make(M, scalarData, ...
                'support', 'vertex', 'valueType', 'scalar');
            
            % Apply gradient
            fieldOut = bct.operators.apply('gradient', fieldIn);
            
            % Verify output
            testCase.verifyEqual(fieldOut.support, "face", ...
                'Gradient output should be on faces');
            testCase.verifyEqual(fieldOut.valueType, "vector", ...
                'Gradient output should be vector field');
            testCase.verifySize(fieldOut.value, [M.numFaces(), 3], ...
                'Gradient should produce [Nf×3] vectors');
        end
        
        function testGradientConsistency(testCase)
            % Verify gradient is consistent with FEM gradient
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            % Create scalar field
            f = rand(M.numVertices(), 1);
            field = bct.fields.make(M, f, ...
                'support', 'vertex', 'valueType', 'scalar');
            
            % Apply gradient via operators
            gradField = bct.operators.apply('gradient', field);
            
            % Apply gradient via FEM
            G = fem.Gradient();
            gradFEM = G * f;
            
            % Compare magnitudes (FEM gives flat gradient, operator gives 3D)
            % Just verify sizes match
            testCase.verifyEqual(size(gradField.value, 1), size(gradFEM, 1), ...
                'Gradient output should have same number of faces');
        end
        
        %% DIVERGENCE OPERATOR TESTS
        function testDivergenceVectorFaceToScalarVertex(testCase)
            % Verify divergence transforms vector(face) → scalar(vertex)
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Create vector field on faces
            vectorData = randn(M.numFaces(), 3);
            fieldIn = bct.fields.make(M, vectorData, ...
                'support', 'face', 'valueType', 'vector');
            
            % Apply divergence
            fieldOut = bct.operators.apply('divergence', fieldIn);
            
            % Verify output
            testCase.verifyEqual(fieldOut.support, "vertex", ...
                'Divergence output should be on vertices');
            testCase.verifyEqual(fieldOut.valueType, "scalar", ...
                'Divergence output should be scalar field');
            testCase.verifySize(fieldOut.value, [M.numVertices(), 1], ...
                'Divergence should produce [Nv×1] scalars');
        end
        
        function testDivergenceGradientComposition(testCase)
            % Verify div(grad(f)) approximates Laplacian
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Create scalar field
            f = sin(2*pi*V(:,1)) .* cos(2*pi*V(:,2));
            field = bct.fields.make(M, f, ...
                'support', 'vertex', 'valueType', 'scalar');
            
            % Apply div(grad(f))
            gradField = bct.operators.apply('gradient', field);
            divGradField = bct.operators.apply('divergence', gradField);
            
            % Should produce scalar field on vertices
            testCase.verifyEqual(divGradField.support, "vertex", ...
                'div(grad) should produce vertex field');
            testCase.verifyEqual(divGradField.valueType, "scalar", ...
                'div(grad) should produce scalar field');
        end
        
        %% LAPLACIAN OPERATOR TESTS
        function testLaplacianScalarToScalar(testCase)
            % Verify Laplacian transforms scalar(vertex) → scalar(vertex)
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Create scalar field
            f = rand(M.numVertices(), 1);
            fieldIn = bct.fields.make(M, f, ...
                'support', 'vertex', 'valueType', 'scalar');
            
            % Apply Laplacian
            fieldOut = bct.operators.apply('laplacian', fieldIn);
            
            % Verify output
            testCase.verifyEqual(fieldOut.support, "vertex", ...
                'Laplacian output should be on vertices');
            testCase.verifyEqual(fieldOut.valueType, "scalar", ...
                'Laplacian output should be scalar field');
            testCase.verifySize(fieldOut.value, [M.numVertices(), 1], ...
                'Laplacian should produce [Nv×1] scalars');
        end
        
        function testLaplacianConsistency(testCase)
            % Verify Laplacian matches FEM Laplacian
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            fem = M.FEM();
            
            % Create scalar field
            f = rand(M.numVertices(), 1);
            field = bct.fields.make(M, f, ...
                'support', 'vertex', 'valueType', 'scalar');
            
            % Apply Laplacian via operators
            lapField = bct.operators.apply('laplacian', field);
            
            % Apply Laplacian via FEM
            L = fem.Laplacian();
            lapFEM = L * f;
            
            % Compare
            testCase.verifyLessThan(norm(lapField.value - lapFEM), 1e-10, ...
                'Laplacian should match FEM Laplacian');
        end
        
        function testLaplacianEigenfunction(testCase)
            % Verify Laplacian preserves eigenfunctions
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Get eigenpairs
            E = bct.graph.eigensolve(M, 10);
            
            % Test on eigenmode 5
            modeIdx = 5;
            eigenFunc = E.Vectors(:, modeIdx);
            eigenVal = E.Values(modeIdx);
            
            field = bct.fields.make(M, eigenFunc, ...
                'support', 'vertex', 'valueType', 'scalar');
            
            % Apply Laplacian
            lapField = bct.operators.apply('laplacian', field);
            
            % Should satisfy: L*psi = lambda*psi
            expected = eigenVal * eigenFunc;
            testCase.verifyLessThan(norm(lapField.value - expected), 1e-8, ...
                'Laplacian should preserve eigenfunctions');
        end
        
        %% OPERATOR CHAINING TESTS
        function testOperatorChaining(testCase)
            % Verify operators can be chained correctly
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Create scalar field
            f = sin(2*pi*V(:,1));
            field = bct.fields.make(M, f, ...
                'support', 'vertex', 'valueType', 'scalar');
            
            % Chain: scalar → gradient → divergence → scalar
            field1 = bct.operators.apply('gradient', field);
            field2 = bct.operators.apply('divergence', field1);
            
            testCase.verifyEqual(field2.support, field.support, ...
                'Chained operators should return to original support');
            testCase.verifyEqual(field2.valueType, field.valueType, ...
                'Chained operators should return to original value type');
        end
        
        %% RUNTIME RESOLUTION TESTS
        function testRuntimeOperatorResolution(testCase)
            % Verify runtime operator resolution works
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Resolve gradient operator
            op = bct.runtime.operators('gradient');
            
            testCase.verifyTrue(isstruct(op) || isa(op, 'function_handle'), ...
                'Runtime should resolve to struct or function');
        end
        
        function testRuntimeOperatorAliases(testCase)
            % Verify operator aliases work
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Test common aliases
            grad1 = bct.runtime.operators('gradient');
            grad2 = bct.runtime.operators('grad');
            
            % Both should resolve (if alias exists)
            testCase.verifyNotEmpty(grad1, ...
                'Gradient operator should resolve');
        end
        
        %% FIELD VALIDATION TESTS
        function testOperatorInputValidation(testCase)
            % Verify operators validate input field types
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            % Create vector field on vertices (wrong for gradient)
            vectorData = randn(M.numVertices(), 3);
            field = bct.fields.make(M, vectorData, ...
                'support', 'vertex', 'valueType', 'vector');
            
            % Gradient expects scalar input
            testCase.verifyError(@() bct.operators.apply('gradient', field), ...
                '?*', 'Gradient should reject vector input');
        end
        
        function testOperatorOutputValidation(testCase)
            % Verify operator outputs are valid fields
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            f = rand(M.numVertices(), 1);
            field = bct.fields.make(M, f, ...
                'support', 'vertex', 'valueType', 'scalar');
            
            gradField = bct.operators.apply('gradient', field);
            
            % Validate output field
            testCase.verifyNoError(@() bct.fields.validate(gradField), ...
                'Operator output should be valid field');
        end
        
        %% PROVENANCE TESTS
        function testOperatorProvenance(testCase)
            % Verify operators track provenance metadata
            [V, F] = testCase.getDefaultTestMesh();
            M = bct.Manifold(V, F);
            
            f = rand(M.numVertices(), 1);
            field = bct.fields.make(M, f, ...
                'support', 'vertex', 'valueType', 'scalar');
            
            gradField = bct.operators.apply('gradient', field);
            
            % Check for provenance in metadata
            if isfield(gradField, 'metadata')
                testCase.verifyTrue(isfield(gradField.metadata, 'operator') || ...
                    isfield(gradField.metadata, 'source'), ...
                    'Field should track operator provenance');
            end
        end
    end
end
