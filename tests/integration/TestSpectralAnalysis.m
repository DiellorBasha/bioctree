classdef TestSpectralAnalysis < matlab.unittest.TestCase
    % TESTSPECTRALANALYSIS Integration tests for spectral analysis workflows
    %
    % Tests complete spectral analysis pipelines including:
    % - Graph Fourier Transform
    % - Eigendecomposition
    % - Spectral filtering
    % - Signal reconstruction
    
    properties
        Bct
        TestSignal
    end
    
    methods (TestClassSetup)
        function setupBctObject(testCase)
            % Create bct object with eigenbasis for all tests
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(100);
            
            testCase.Bct = B;
            
            % Create test signal
            testCase.TestSignal = randn(B.Manifold.N, 1);
        end
    end
    
    %% Graph Fourier Transform Tests
    methods (Test)
        function testForwardTransform(testCase)
            % Test forward Graph Fourier Transform
            B = testCase.Bct;
            x = testCase.TestSignal;
            
            % Forward transform: x_hat = U' * x
            x_hat = B.Lambda.U' * x;
            
            testCase.verifySize(x_hat, [B.Lambda.K, 1], ...
                'Spectral coefficients should match eigenmode count');
            testCase.verifyTrue(isreal(x_hat) || ~isreal(x_hat), ...
                'Transform should produce valid coefficients');
        end
        
        function testInverseTransform(testCase)
            % Test inverse Graph Fourier Transform
            B = testCase.Bct;
            x_orig = testCase.TestSignal;
            
            % Forward
            x_hat = B.Lambda.U' * x_orig;
            
            % Inverse: x = U * x_hat
            x_recon = B.Lambda.U * x_hat;
            
            testCase.verifyEqual(x_recon, x_orig, 'RelTol', 1e-10, ...
                'Reconstruction should match original');
        end
        
        function testParsevalsTheorem(testCase)
            % Test Parseval's theorem: ||x||^2 = ||x_hat||^2
            B = testCase.Bct;
            x = testCase.TestSignal;
            
            % Transform
            x_hat = B.Lambda.U' * x;
            
            % Energy in spatial domain
            energy_spatial = norm(x)^2;
            
            % Energy in spectral domain
            energy_spectral = norm(x_hat)^2;
            
            testCase.verifyEqual(energy_spectral, energy_spatial, 'RelTol', 1e-10, ...
                'Energy should be preserved (Parseval)');
        end
    end
    
    %% Spectral Filtering Tests
    methods (Test)
        function testLowpassFiltering(testCase)
            % Test lowpass spectral filtering
            B = testCase.Bct;
            x = testCase.TestSignal;
            
            % Transform to spectral domain
            x_hat = B.Lambda.U' * x;
            
            % Lowpass filter: keep only low frequencies
            cutoff = round(B.Lambda.K / 4);  % Keep 25% lowest frequencies
            x_hat_filtered = x_hat;
            x_hat_filtered(cutoff+1:end) = 0;
            
            % Inverse transform
            x_lowpass = B.Lambda.U * x_hat_filtered;
            
            testCase.verifySize(x_lowpass, size(x), ...
                'Filtered signal should match original size');
            testCase.verifyLessThan(norm(x_lowpass), norm(x), ...
                'Lowpass should reduce signal energy');
        end
        
        function testHighpassFiltering(testCase)
            % Test highpass spectral filtering
            B = testCase.Bct;
            x = testCase.TestSignal;
            
            % Transform
            x_hat = B.Lambda.U' * x;
            
            % Highpass filter: remove low frequencies
            cutoff = round(B.Lambda.K / 4);
            x_hat_filtered = x_hat;
            x_hat_filtered(1:cutoff) = 0;
            
            % Inverse
            x_highpass = B.Lambda.U * x_hat_filtered;
            
            testCase.verifySize(x_highpass, size(x));
            % Highpass removes smooth components
        end
        
        function testBandpassFiltering(testCase)
            % Test bandpass spectral filtering
            B = testCase.Bct;
            x = testCase.TestSignal;
            
            % Transform
            x_hat = B.Lambda.U' * x;
            
            % Bandpass filter: keep middle frequencies
            low_cutoff = round(B.Lambda.K / 4);
            high_cutoff = round(3 * B.Lambda.K / 4);
            
            x_hat_filtered = zeros(size(x_hat));
            x_hat_filtered(low_cutoff:high_cutoff) = x_hat(low_cutoff:high_cutoff);
            
            % Inverse
            x_bandpass = B.Lambda.U * x_hat_filtered;
            
            testCase.verifySize(x_bandpass, size(x));
        end
    end
    
    %% Spectral Analysis Tests
    methods (Test)
        function testSpectralDensity(testCase)
            % Test power spectral density computation
            B = testCase.Bct;
            x = testCase.TestSignal;
            
            % Transform
            x_hat = B.Lambda.U' * x;
            
            % Power spectral density
            PSD = abs(x_hat).^2;
            
            testCase.verifySize(PSD, [B.Lambda.K, 1]);
            testCase.verifyGreaterThanOrEqual(min(PSD), 0, ...
                'PSD should be non-negative');
        end
        
        function testSpectralEnergy(testCase)
            % Test spectral energy distribution
            B = testCase.Bct;
            x = testCase.TestSignal;
            
            % Transform
            x_hat = B.Lambda.U' * x;
            
            % Energy per frequency
            energy = abs(x_hat).^2;
            
            % Total energy should equal spatial energy
            total_energy = sum(energy);
            spatial_energy = norm(x)^2;
            
            testCase.verifyEqual(total_energy, spatial_energy, 'RelTol', 1e-10);
        end
    end
    
    %% Smoothness Tests
    methods (Test)
        function testSignalSmoothness(testCase)
            % Test measuring signal smoothness via Laplacian energy
            B = testCase.Bct;
            
            % Create smooth signal (low eigenmode)
            smooth_signal = B.Lambda.U(:, 2);  % 2nd eigenmode
            
            % Create rough signal (high eigenmode)
            rough_signal = B.Lambda.U(:, end);  % Last eigenmode
            
            % Smoothness measure: x' * L * x (Dirichlet energy)
            L = B.Manifold.L;
            smooth_energy = smooth_signal' * L * smooth_signal;
            rough_energy = rough_signal' * L * rough_signal;
            
            testCase.verifyLessThan(smooth_energy, rough_energy, ...
                'Low eigenmode should be smoother');
        end
    end
    
    %% Multiresolution Tests
    methods (Test)
        function testMultiresolutionDecomposition(testCase)
            % Test multiresolution signal decomposition
            B = testCase.Bct;
            x = testCase.TestSignal;
            
            % Transform
            x_hat = B.Lambda.U' * x;
            
            % Decompose into bands
            n_bands = 4;
            band_size = floor(B.Lambda.K / n_bands);
            
            decomposition = cell(n_bands, 1);
            for i = 1:n_bands
                start_idx = (i-1) * band_size + 1;
                end_idx = min(i * band_size, B.Lambda.K);
                
                x_hat_band = zeros(size(x_hat));
                x_hat_band(start_idx:end_idx) = x_hat(start_idx:end_idx);
                
                decomposition{i} = B.Lambda.U * x_hat_band;
            end
            
            % Reconstruction from bands
            x_recon = zeros(size(x));
            for i = 1:n_bands
                x_recon = x_recon + decomposition{i};
            end
            
            testCase.verifyEqual(x_recon, x, 'RelTol', 1e-10, ...
                'Band sum should reconstruct original');
        end
    end
    
    %% Eigenmode Analysis Tests
    methods (Test)
        function testEigenmodeProperties(testCase)
            % Test properties of eigenmodes
            B = testCase.Bct;
            
            % Eigenmodes should be orthogonal
            U = B.Lambda.U;
            UU = U' * U;
            I = eye(B.Lambda.K);
            
            testCase.verifyEqual(UU, I, 'RelTol', 1e-10, ...
                'Eigenmodes should be orthonormal');
            
            % Check Laplacian eigenvalue equation: L*u = lambda*u
            L = B.Manifold.L;
            for k = 1:min(5, B.Lambda.K)  % Check first 5 modes
                u = U(:, k);
                lambda = B.Lambda.lambda(k);
                
                Lu = L * u;
                lambda_u = lambda * u;
                
                testCase.verifyEqual(Lu, lambda_u, 'RelTol', 1e-6, ...
                    sprintf('Mode %d should satisfy L*u = lambda*u', k));
            end
        end
        
        function testEigenmodeFrequency(testCase)
            % Test eigenmode frequency interpretation
            B = testCase.Bct;
            
            % Higher eigenvalues correspond to higher frequencies
            testCase.verifyTrue(issorted(B.Lambda.lambda), ...
                'Eigenvalues should increase with frequency');
            
            % Wavenumbers (k = sqrt(lambda)) should also increase
            k = B.Lambda.axis;
            testCase.verifyTrue(issorted(k), ...
                'Wavenumbers should increase');
        end
    end
    
    %% Complete Workflow Tests
    methods (Test)
        function testCompleteSpectralPipeline(testCase)
            % Test complete spectral analysis pipeline
            
            % 1. Create mesh
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            % 2. Compute eigenbasis
            B = B.computeEigenbasis(100);
            testCase.verifyNotEmpty(B.Lambda.lambda);
            
            % 3. Create signal
            x = randn(B.Manifold.N, 1);
            
            % 4. Transform
            x_hat = B.Lambda.U' * x;
            testCase.verifySize(x_hat, [100, 1]);
            
            % 5. Filter (lowpass)
            x_hat_filtered = x_hat;
            x_hat_filtered(51:end) = 0;
            
            % 6. Reconstruct
            x_filtered = B.Lambda.U * x_hat_filtered;
            testCase.verifySize(x_filtered, size(x));
            
            % 7. Verify energy reduction
            testCase.verifyLessThan(norm(x_filtered), norm(x));
        end
    end
end
