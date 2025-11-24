classdef TestBct < BaseBctTest
    % TESTBCT Integration tests for bct.bct main class
    %
    % Tests the main Bct orchestration class including:
    % - Factory methods (fromMesh, fromAdjacency, fromEdges)
    % - Automatic dual domain creation (Manifold ↔ Lambda, Time ↔ Omega)
    % - Eigenbasis computation orchestration
    % - Transform initialization
    % - Domain linking and dual relationships
    
    properties
        Bct
    end
    
    %% Constructor and Factory Method Tests
    methods (Test)
        function testEmptyConstructor(testCase)
            % Test creating empty bct object
            B = bct.bct();
            
            testCase.verifyClass(B, 'bct.bct');
            testCase.verifyEmpty(B.Manifold);
            testCase.verifyEmpty(B.Lambda);
            testCase.verifyEmpty(B.Time);
            testCase.verifyEmpty(B.Omega);
            testCase.verifyEmpty(B.Joint);
        end
        
        function testFromMeshBasic(testCase)
            % Test creating bct from mesh using standard test mesh
            mesh = testCase.StandardMesh;
            
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            
            % Verify bct object created
            testCase.verifyClass(B, 'bct.bct');
            
            % Verify Manifold created
            testCase.verifyNotEmpty(B.Manifold);
            testCase.verifyClass(B.Manifold, 'bct.Manifold');
            
            % Verify Lambda created automatically
            testCase.verifyNotEmpty(B.Lambda);
            testCase.verifyClass(B.Lambda, 'bct.Lambda');
        end
        
        function testImportFreesurferMesh(testCase)
            % Test creating bct from Freesurfer mesh file
            path = 'C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage\surf\lh.pial';
            
            % Skip test if file doesn't exist
            if ~isfile(path)
                testCase.assumeFail('Freesurfer test file not found');
            end
            
            % Import mesh using bct.io.import.mesh
            B = bct.io.import.mesh(path);
            
            % Verify bct object created
            testCase.verifyClass(B, 'bct.bct', 'Should create bct object');
            
            % Verify Manifold created with mesh data
            testCase.verifyNotEmpty(B.Manifold, 'Manifold should be created');
            testCase.verifyClass(B.Manifold, 'bct.Manifold');
            
            % Verify mesh data loaded
            testCase.verifyNotEmpty(B.Manifold.Vertices, 'Vertices should be loaded');
            testCase.verifyNotEmpty(B.Manifold.Faces, 'Faces should be loaded');
            testCase.verifyGreaterThan(size(B.Manifold.Vertices, 1), 0, ...
                'Should have vertices');
            testCase.verifyGreaterThan(size(B.Manifold.Faces, 1), 0, ...
                'Should have faces');
            
            % Verify Laplacian computed
            testCase.verifyNotEmpty(B.Manifold.Laplacian, ...
                'Laplacian should be computed');
            testCase.verifyNotEmpty(B.Manifold.MassMatrix, ...
                'MassMatrix should be computed');
            testCase.verifyNotEmpty(B.Manifold.CotangentMatrix, ...
                'CotangentMatrix should be computed');
            
            % Verify Lambda created automatically
            testCase.verifyNotEmpty(B.Lambda, 'Lambda should be created');
            testCase.verifyClass(B.Lambda, 'bct.Lambda');
            
            % Verify dual linking
            testCase.verifyEqual(B.Manifold.dual, B.Lambda, ...
                'Manifold and Lambda should be linked as duals');
        end
        
        function testFromMeshManifoldProperties(testCase)
            % Test that Manifold has correct properties from mesh
            mesh = testCase.StandardMesh;
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            
            % Verify Manifold properties
            testCase.verifyEqual(B.Manifold.Vertices, mesh.V);
            testCase.verifyEqual(B.Manifold.Faces, mesh.F);
            testCase.verifyNotEmpty(B.Manifold.Laplacian);
            testCase.verifyNotEmpty(B.Manifold.MassMatrix);
            testCase.verifyNotEmpty(B.Manifold.CotangentMatrix);
        end
        
        function testManifoldLambdaDualLink(testCase)
            % Test that Manifold and Lambda are linked as duals
            mesh = testCase.StandardMesh;
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            
            % Verify dual relationship is bidirectional
            testCase.verifyEqual(B.Manifold.dual, B.Lambda, ...
                'Manifold.dual should point to Lambda');
            testCase.verifyEqual(B.Lambda.dual, B.Manifold, ...
                'Lambda.dual should point to Manifold');
        end
        
        function testLambdaPlaceholderAxis(testCase)
            % Test that Lambda has placeholder axis before eigenbasis computation
            mesh = testCase.StandardMesh;
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            
            % Lambda should have placeholder eigenvalues
            testCase.verifyNotEmpty(B.Lambda.lambda, ...
                'Lambda should have placeholder eigenvalues');
            testCase.verifyEmpty(B.Lambda.U, ...
                'Lambda should not have eigenvectors before computation');
            
            % Eigenvalues should be placeholder (100 values)
            testCase.verifyEqual(length(B.Lambda.lambda), 100, ...
                'Placeholder should have 100 eigenvalues');
            
            % Should be sorted and non-negative
            testCase.verifyTrue(all(B.Lambda.lambda >= 0), ...
                'Placeholder eigenvalues should be non-negative');
            testCase.verifyTrue(issorted(B.Lambda.lambda), ...
                'Placeholder eigenvalues should be sorted');
        end
        
        function testManifoldDimensionConsistency(testCase)
            % Test dimension consistency of Manifold matrices
            mesh = testCase.StandardMesh;
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            
            N = size(mesh.V, 1);
            
            % Manifold dimensions
            testCase.verifyEqual(B.Manifold.N, N);
            testCase.verifyEqual(size(B.Manifold.Laplacian, 1), N);
            testCase.verifyEqual(size(B.Manifold.MassMatrix, 1), N);
            testCase.verifyEqual(size(B.Manifold.CotangentMatrix, 1), N);
            
            % Note: Lambda.N is 100 (placeholder) until eigenbasis is computed
            % After eigenbasis computation, Lambda.N will equal number of computed modes
        end
    end
    
    %% Eigenbasis Computation Tests
    methods (Test)
        function testComputeEigenbasisBasic(testCase)
            % Test basic eigenbasis computation
            mesh = testCase.StandardMesh;
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            
            % Compute eigenbasis with 50 modes
            k = 50;
            B = B.computeEigenbasis(k);
            
            % Verify eigenvectors and eigenvalues computed
            testCase.verifyNotEmpty(B.Lambda.U, ...
                'Eigenvectors should be computed');
            testCase.verifyNotEmpty(B.Lambda.lambda, ...
                'Eigenvalues should be computed');
            
            % Verify dimensions (may be less than k due to DC filtering)
            k_actual = size(B.Lambda.U, 2);
            testCase.verifyLessThanOrEqual(k_actual, k, ...
                'Should have at most k eigenvectors');
            testCase.verifyEqual(size(B.Lambda.U, 1), B.Manifold.N, ...
                'Eigenvectors should have N rows');
            testCase.verifyEqual(length(B.Lambda.lambda), k_actual, ...
                'Eigenvalue count should match eigenvector count');
        end
        
        function testComputeEigenbasisEigenvalueProperties(testCase)
            % Test eigenvalue properties after computation
            mesh = testCase.StandardMesh;
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            
            B = B.computeEigenbasis(30);
            
            % Eigenvalues should be non-negative and sorted
            testCase.verifyTrue(all(B.Lambda.lambda >= 0), ...
                'Eigenvalues should be non-negative');
            testCase.verifyTrue(issorted(B.Lambda.lambda), ...
                'Eigenvalues should be sorted ascending');
        end
        
        function testComputeEigenbasisEigenvectorOrthogonality(testCase)
            % Test that computed eigenvectors are orthonormal w.r.t. mass matrix
            mesh = testCase.StandardMesh;
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            
            B = B.computeEigenbasis(20);
            
            % Check M-orthonormality: U'*M*U should be identity
            % (eigenvectors are orthonormal with respect to mass matrix)
            k_actual = size(B.Lambda.U, 2);
            M = B.Manifold.MassMatrix;
            I = B.Lambda.U' * M * B.Lambda.U;
            testCase.verifyEqual(I, eye(k_actual), 'AbsTol', 1e-6, ...
                'Eigenvectors should be M-orthonormal');
        end
        
        function testComputeEigenbasisTransformsInitialized(testCase)
            % Test that transforms are initialized after eigenbasis computation
            mesh = testCase.StandardMesh;
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            
            % Before eigenbasis, transforms should be empty or incomplete
            % (depends on implementation)
            
            % Compute eigenbasis
            B = B.computeEigenbasis(50);
            
            % After eigenbasis, transforms should be initialized
            testCase.verifyNotEmpty(B.Manifold.transform, ...
                'Manifold transform should be initialized');
            testCase.verifyNotEmpty(B.Lambda.transform, ...
                'Lambda transform should be initialized');
            
            % Verify transform types
            testCase.verifyClass(B.Manifold.transform, 'bct.factory.transforms.MFT', ...
                'Manifold should have MFT transform');
            testCase.verifyClass(B.Lambda.transform, 'bct.factory.transforms.IMFT', ...
                'Lambda should have IMFT transform');
        end
        
        function testComputeEigenbasisWithoutManifold(testCase)
            % Test that computeEigenbasis errors without Manifold
            B = bct.bct();
            
            testCase.verifyError(@() B.computeEigenbasis(50), ...
                'bct:NoManifold', ...
                'Should error when Manifold not initialized');
        end
        
        function testComputeEigenbasisWithoutLambda(testCase)
            % Test that computeEigenbasis errors without Lambda
            mesh = testCase.StandardMesh;
            B = bct.bct();
            B.Manifold = bct.Manifold(mesh);
            B.Lambda = bct.Lambda.empty();  % Clear Lambda
            
            testCase.verifyError(@() B.computeEigenbasis(50), ...
                'bct:NoLambda', ...
                'Should error when Lambda not initialized');
        end
    end
    
    %% Filterbank Tests
    methods (Test)
        function testFilterbankInitialized(testCase)
            % Test that Filterbank is automatically initialized
            B = bct.bct();
            
            testCase.verifyNotEmpty(B.Filterbank);
            testCase.verifyClass(B.Filterbank, 'bct.filters.FilterBank');
        end
        
        function testFilterbankFromMesh(testCase)
            % Test that Filterbank exists in fromMesh
            mesh = testCase.StandardMesh;
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            
            testCase.verifyNotEmpty(B.Filterbank);
            testCase.verifyClass(B.Filterbank, 'bct.filters.FilterBank');
        end
    end
    
    %% Domain Name Tests
    methods (Test)
        function testManifoldName(testCase)
            % Test that Manifold has correct name
            mesh = testCase.StandardMesh;
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            
            testCase.verifyEqual(B.Manifold.name, "Manifold");
        end
        
        function testLambdaName(testCase)
            % Test that Lambda has correct name
            mesh = testCase.StandardMesh;
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            
            testCase.verifyEqual(B.Lambda.name, "Lambda");
        end
    end
    
    %% Multiple Instance Tests
    methods (Test)
        function testMultipleBctInstances(testCase)
            % Test creating multiple independent bct instances
            mesh = testCase.StandardMesh;
            
            B1 = bct.bct.fromMesh(mesh.V, mesh.F);
            B2 = bct.bct.fromMesh(mesh.V, mesh.F);
            
            % Should be different handle objects (bct is a handle class)
            testCase.verifyFalse(B1 == B2, 'Should be different bct handles');
            testCase.verifyFalse(B1.Manifold == B2.Manifold, 'Should be different Manifold handles');
            testCase.verifyFalse(B1.Lambda == B2.Lambda, 'Should be different Lambda handles');
            
            % But should have same structure
            testCase.verifyEqual(B1.Manifold.N, B2.Manifold.N);
            testCase.verifyEqual(size(B1.Manifold.Vertices), size(B2.Manifold.Vertices));
        end
    end
    
    %% Standard Workflow Tests
    methods (Test)
        function testStandardWorkflowComplete(testCase)
            % Test complete standard workflow: mesh → eigenbasis → signal → filter → result
            mesh = testCase.StandardMesh;
            
            % Step 1: Create Bct object with Manifold from mesh
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            testCase.verifyNotEmpty(B.Manifold, 'Manifold should be created');
            testCase.verifyNotEmpty(B.Lambda, 'Lambda should be auto-created');
            
            % Step 2: Compute eigenbasis
            numModes = 50;
            B = B.computeEigenbasis(numModes);
            testCase.verifyNotEmpty(B.Lambda.U, 'Eigenvectors should be computed');
            testCase.verifyNotEmpty(B.Lambda.lambda, 'Eigenvalues should be computed');
            
            % Verify transforms initialized
            testCase.verifyNotEmpty(B.Manifold.transform, ...
                'Manifold transform should be initialized');
            testCase.verifyNotEmpty(B.Lambda.transform, ...
                'Lambda transform should be initialized');
            
            % Step 3: Define a Signal on the Manifold
            N = B.Manifold.N;
            signal_data = randn(N, 1);  % Random signal
            sig = bct.Signal(B.Manifold, signal_data, 'test_signal');
            
            testCase.verifyClass(sig, 'bct.Signal', 'Should create Signal object');
            testCase.verifyEqual(size(sig.Data), [N, 1], 'Signal data should match Manifold size');
            
            % Step 4: Create a Filter
            designer = bct.filters.FilterDesigner(B);
            k_actual = size(B.Lambda.U, 2);
            center_idx = ceil(k_actual / 2);
            sigma_val = k_actual / 10;
            
            filt = designer.create(B.Lambda, 'gaussian', ...
                'center', center_idx, 'sigma', sigma_val, 'label', 'lowpass');
            
            testCase.verifyClass(filt, 'bct.filters.Filter', 'Should create Filter object');
            testCase.verifyEqual(filt.Domain, B.Lambda, 'Filter should be on Lambda domain');
            
            % Step 5: Apply filter to signal using Bct orchestration
            % Bct orchestrates: Manifold → Lambda (MFT) → filter → Manifold (IMFT)
            filtered_sig = B.applyFilter(filt, sig);
            
            testCase.verifyClass(filtered_sig, 'bct.Signal', ...
                'Should return Signal object');
            testCase.verifyEqual(size(filtered_sig.Data), size(signal_data), ...
                'Filtered signal should have same size as input');
            
            % Verify filtering worked (output should be different from input)
            testCase.verifyNotEqual(filtered_sig.Data, signal_data, ...
                'Filtered signal should differ from input');
        end
        
        function testWorkflowWithImpulse(testCase)
            % Test workflow with delta (impulse) signal
            mesh = testCase.StandardMesh;
            
            % Create Bct and compute eigenbasis
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            B = B.computeEigenbasis(30);
            
            % Create impulse signal at vertex 100
            delta = bct.Signal.createDelta(B.Manifold, 100);
            
            testCase.verifyEqual(size(delta.Data, 1), B.Manifold.N, ...
                'Delta should have N elements');
            testCase.verifyEqual(sum(delta.Data), 1, ...
                'Delta should have sum of 1');
            testCase.verifyEqual(delta.Data(100), 1, ...
                'Delta should be 1 at specified vertex');
            
            % Create lowpass filter
            designer = bct.filters.FilterDesigner(B);
            filt = designer.create(B.Lambda, 'gaussian', ...
                'center', 5, 'sigma', 2);
            
            % Filter the impulse (impulse response) using Bct orchestration
            impulse_response = B.applyFilter(filt, delta);
            
            testCase.verifyNotEmpty(impulse_response.Data, ...
                'Impulse response should be computed');
            testCase.verifyEqual(size(impulse_response.Data, 1), B.Manifold.N, ...
                'Impulse response should have N vertices');
            
            % Impulse response should be smoother than delta
            % (more spread out, not concentrated at single vertex)
            num_nonzero = sum(abs(impulse_response.Data) > 1e-10);
            testCase.verifyGreaterThan(num_nonzero, 1, ...
                'Impulse response should spread to multiple vertices');
        end
        
        function testWorkflowFilterDesignerShortcut(testCase)
            % Test using FilterDesigner shortcut methods (lambda, omega, etc.)
            mesh = testCase.StandardMesh;
            
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            B = B.computeEigenbasis(25);
            
            % Use lambda() shortcut instead of create(B.Lambda, ...)
            designer = bct.filters.FilterDesigner(B);
            filt = designer.lambda('gaussian', 'center', 10, 'sigma', 3);
            
            testCase.verifyClass(filt, 'bct.filters.Filter');
            testCase.verifyEqual(filt.Domain, B.Lambda, ...
                'lambda() should create filter on Lambda domain');
            
            % Apply to signal using Bct orchestration
            sig = bct.Signal(B.Manifold, randn(B.Manifold.N, 1), 'test');
            filtered = B.applyFilter(filt, sig);
            
            testCase.verifyNotEmpty(filtered.Data);
            testCase.verifyEqual(filtered.Domain, B.Manifold);
        end
        
        function testWorkflowWithoutEigenbasis(testCase)
            % Test that filtering fails gracefully without eigenbasis
            mesh = testCase.StandardMesh;
            
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            % DO NOT compute eigenbasis
            
            sig = bct.Signal(B.Manifold, randn(B.Manifold.N, 1), 'test');
            
            % FilterDesigner can create filter, but application should fail
            designer = bct.filters.FilterDesigner(B);
            filt = designer.lambda('gaussian', 'center', 10, 'sigma', 2);
            
            % Should error because transforms not initialized
            testCase.verifyError(...
                @() B.applyFilter(filt, sig), ...
                'bct:NoTransform', ...
                'Should error when transforms not initialized');
        end
        
        function testWorkflowFilterbankIntegration(testCase)
            % Test that filters can be added to Filterbank
            mesh = testCase.StandardMesh;
            
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            B = B.computeEigenbasis(30);
            
            designer = bct.filters.FilterDesigner(B);
            
            % Create multiple filters
            filt1 = designer.lambda('gaussian', 'center', 5, 'sigma', 2, ...
                'label', 'low');
            filt2 = designer.lambda('gaussian', 'center', 15, 'sigma', 3, ...
                'label', 'mid');
            filt3 = designer.lambda('gaussian', 'center', 25, 'sigma', 2, ...
                'label', 'high');
            
            % Add to filterbank
            B.Filterbank.add(filt1);
            B.Filterbank.add(filt2);
            B.Filterbank.add(filt3);
            
            % Verify filterbank has all filters
            testCase.verifyGreaterThanOrEqual(B.Filterbank.length(), 3, ...
                'Filterbank should contain at least 3 filters');
            
            % Retrieve filter by label
            retrieved = B.Filterbank.get('low');
            testCase.verifyEqual(retrieved, filt1, ...
                'Should retrieve correct filter by label');
        end
    end
    
    %% Joint Domain Tests
    methods (Test)
        function testJointDomainAutomaticCreation(testCase)
            % Test that setting Time automatically creates Joint Manifold_Time domain
            mesh = testCase.StandardMesh;
            
            % Step 1: Create Bct with Manifold
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            testCase.verifyNotEmpty(B.Manifold, 'Manifold should be created');
            testCase.verifyEmpty(B.Time, 'Time should be empty initially');
            testCase.verifyEmpty(B.Joint, 'Joint should be empty initially');
            
            % Step 2: Add Time object
            t = linspace(0, 1, 50)';
            fs = 50;
            B.Time = bct.Time(t, fs);
            
            % Step 3: Verify Omega created automatically
            testCase.verifyNotEmpty(B.Omega, 'Omega should be auto-created');
            testCase.verifyClass(B.Omega, 'bct.Omega');
            
            % Step 4: Verify Time <-> Omega dual linking
            testCase.verifyEqual(B.Time.dual, B.Omega, ...
                'Time.dual should point to Omega');
            testCase.verifyEqual(B.Omega.dual, B.Time, ...
                'Omega.dual should point to Time');
            
            % Step 5: Verify Joint Manifold_Time created automatically
            testCase.verifyNotEmpty(B.Joint, ...
                'Joint should be auto-created when Time is set');
            testCase.verifyClass(B.Joint, 'bct.Joint');
            
            % Step 6: Verify Joint domain composition
            % Joint should combine Manifold and Time
            testCase.verifyEqual(B.Joint.A, B.Manifold, ...
                'Joint.A should be Manifold');
            testCase.verifyEqual(B.Joint.B, B.Time, ...
                'Joint.B should be Time');
            
            % Step 7: Verify Joint dimensions
            dims = B.Joint.N;
            testCase.verifyEqual(sz(1), B.Manifold.N, ...
                'Joint first dimension should match Manifold.N');
            testCase.verifyEqual(sz(2), B.Time.N, ...
                'Joint second dimension should match Time.N');
        end
        
        function testJointDomainDualCreation(testCase)
            % Test that Joint domain has dual Lambda_Omega
            mesh = testCase.StandardMesh;
            
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            t = linspace(0, 1, 30)';
            B.Time = bct.Time(t, 30);
            
            % Joint should be created
            testCase.verifyNotEmpty(B.Joint);
            
            % Joint should have dual
            testCase.verifyNotEmpty(B.Joint.dual, ...
                'Joint should have dual Lambda_Omega');
            
            % Dual should be Joint(Lambda, Omega)
            dualJoint = B.Joint.dual;
            testCase.verifyClass(dualJoint, 'bct.Joint');
            testCase.verifyEqual(dualJoint.A, B.Lambda, ...
                'Dual Joint.A should be Lambda');
            testCase.verifyEqual(dualJoint.B, B.Omega, ...
                'Dual Joint.B should be Omega');
            
            % Bidirectional dual linking
            testCase.verifyEqual(dualJoint.dual, B.Joint, ...
                'Dual relationship should be bidirectional');
        end
        
        function testJointDomainNames(testCase)
            % Test that Joint domains have correct names
            mesh = testCase.StandardMesh;
            
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            B.Time = bct.Time(linspace(0, 1, 40)', 40);
            
            % Joint Manifold_Time name
            testCase.verifyTrue(contains(string(B.Joint.name), "Manifold"), ...
                'Joint name should contain Manifold');
            testCase.verifyTrue(contains(string(B.Joint.name), "Time"), ...
                'Joint name should contain Time');
            
            % Dual Joint Lambda_Omega name
            dualName = string(B.Joint.dual.name);
            testCase.verifyTrue(contains(dualName, "Lambda"), ...
                'Dual Joint name should contain Lambda');
            testCase.verifyTrue(contains(dualName, "Omega"), ...
                'Dual Joint name should contain Omega');
        end
        
        function testJointWithoutManifold(testCase)
            % Test that Time can be set without Manifold (no Joint created)
            B = bct.bct();  % Empty Bct
            
            B.Time = bct.Time(linspace(0, 1, 20)', 20);
            
            % Omega should be created
            testCase.verifyNotEmpty(B.Omega);
            testCase.verifyEqual(B.Time.dual, B.Omega);
            
            % But Joint should NOT be created (no Manifold)
            testCase.verifyEmpty(B.Joint, ...
                'Joint should not be created without Manifold');
        end
        
        function testManualJointCreation(testCase)
            % Test manual Joint creation using createJoint
            mesh = testCase.StandardMesh;
            
            B = bct.bct.fromMesh(mesh.V, mesh.F);
            B = B.computeEigenbasis(30);
            B.Time = bct.Time(linspace(0, 1, 25)', 25);
            
            % Joint already auto-created, but test manual creation with different domains
            % Create Lambda_Time joint manually
            B_lambda_time = B.createJoint('Lambda', 'Time');
            
            testCase.verifyNotEmpty(B_lambda_time.Joint);
            testCase.verifyEqual(B_lambda_time.Joint.A, B.Lambda);
            testCase.verifyEqual(B_lambda_time.Joint.B, B.Time);
        end
    end
end
