classdef TestSpatiotemporalOps < matlab.unittest.TestCase
    % TESTSPATIOTEMPORALOPS Integration tests for spatiotemporal operations
    %
    % Tests complete workflows involving:
    % - Signal generation on manifolds
    % - Temporal evolution
    % - Diffusion processes
    % - Wave propagation
    % - Spatiotemporal statistics
    
    properties
        Bct
    end
    
    methods (TestClassSetup)
        function setupBctObject(testCase)
            % Create full bct object for spatiotemporal testing
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(100);
            
            t = linspace(0, 2, 200)';  % 2 seconds, 200 samples
            B.Time = bct.Time(t, 100);  % 100 Hz sampling
            B = B.createJoint('Lambda', 'Omega');
            
            testCase.Bct = B;
        end
    end
    
    %% Signal Generation Tests
    methods (Test)
        function testSpatialSignalGeneration(testCase)
            % Test generating purely spatial signals
            B = testCase.Bct;
            
            % Generate signal from low-frequency eigenmodes
            coeffs = randn(10, 1);  % First 10 modes
            x = B.Lambda.U(:, 1:10) * coeffs;
            
            testCase.verifySize(x, [B.Manifold.N, 1]);
            testCase.verifyTrue(isreal(x), 'Spatial signal should be real');
        end
        
        function testTemporalSignalGeneration(testCase)
            % Test generating purely temporal signals
            B = testCase.Bct;
            
            % Generate oscillation at specific frequency
            f0 = 10;  % Hz
            t_signal = sin(2*pi*f0 * B.Time.t);
            
            testCase.verifySize(t_signal, [B.Time.N, 1]);
            testCase.verifyTrue(isreal(t_signal));
        end
        
        function testSpatiotemporalSignalGeneration(testCase)
            % Test generating full spatiotemporal signals
            B = testCase.Bct;
            
            % Spatial pattern
            spatial_pattern = B.Lambda.U(:, 5);
            
            % Temporal evolution
            temporal_pattern = sin(2*pi*15 * B.Time.t);
            
            % Spatiotemporal signal
            X = spatial_pattern * temporal_pattern';
            
            testCase.verifySize(X, [B.Manifold.N, B.Time.N]);
        end
    end
    
    %% Diffusion Process Tests
    methods (Test)
        function testHeatDiffusion(testCase)
            % Test heat diffusion on manifold
            B = testCase.Bct;
            
            % Initial condition: point source
            x0 = zeros(B.Manifold.N, 1);
            x0(1) = 1;  % Heat at first vertex
            
            % Diffusion parameter
            alpha = 0.1;
            dt = B.Time.dt;
            
            % Simulate diffusion
            X = zeros(B.Manifold.N, B.Time.N);
            X(:, 1) = x0;
            
            L = B.Manifold.L;
            I = speye(B.Manifold.N);
            
            % Implicit Euler: (I + alpha*dt*L)*x_{n+1} = x_n
            A = I + alpha*dt*L;
            
            for t_idx = 2:min(50, B.Time.N)  % First 50 timesteps
                X(:, t_idx) = A \ X(:, t_idx-1);
            end
            
            % Verify diffusion spreads
            testCase.verifyGreaterThan(nnz(X(:, 10) > 0.01), 1, ...
                'Heat should spread from source');
            
            % Verify total mass conservation (for normalized Laplacian)
            if strcmp(B.Manifold.lap_type, 'normalized')
                testCase.verifyEqual(sum(X(:, 1)), sum(X(:, 10)), 'RelTol', 0.1, ...
                    'Mass should be approximately conserved');
            end
        end
        
        function testDiffusionDecay(testCase)
            % Test exponential decay of diffusion modes
            B = testCase.Bct;
            
            % Initial condition: eigenmode k
            k = 10;
            x0 = B.Lambda.U(:, k);
            
            % Diffusion coefficient
            alpha = 0.1;
            lambda_k = B.Lambda.lambda(k);
            
            % Analytical solution: x(t) = exp(-alpha*lambda_k*t) * x0
            t_test = 0.5;  % seconds
            x_analytical = exp(-alpha*lambda_k*t_test) * x0;
            
            % Numerical solution (one step for simplicity)
            L = B.Manifold.L;
            I = speye(B.Manifold.N);
            A = I + alpha*t_test*L;
            x_numerical = A \ x0;
            
            % Should be close (for small timestep)
            testCase.verifyEqual(x_numerical, x_analytical, 'RelTol', 0.5, ...
                'Numerical diffusion should approximate analytical');
        end
    end
    
    %% Wave Propagation Tests
    methods (Test)
        function testWavePropagation(testCase)
            % Test wave propagation on manifold
            B = testCase.Bct;
            
            if B.Lambda.K >= 20
                % Create traveling wave
                k_spatial = 10;
                f_temporal = 15;  % Hz
                omega_temporal = 2*pi*f_temporal;
                
                % Wave: psi(x,t) = u_k(x) * exp(i*omega*t)
                spatial_mode = B.Lambda.U(:, k_spatial);
                
                X = zeros(B.Manifold.N, B.Time.N);
                for t_idx = 1:B.Time.N
                    t = B.Time.t(t_idx);
                    X(:, t_idx) = real(spatial_mode * exp(1i*omega_temporal*t));
                end
                
                % Verify wave properties
                % 1. Spatial pattern should remain constant mode
                testCase.verifySize(X, [B.Manifold.N, B.Time.N]);
                
                % 2. Temporal oscillation should be at correct frequency
                vertex_signal = X(1, :);
                vertex_fft = fft(vertex_signal);
                [~, peak_idx] = max(abs(vertex_fft(1:B.Time.N/2)));
                
                freq_resolution = B.Time.fs / B.Time.N;
                detected_freq = (peak_idx - 1) * freq_resolution;
                
                testCase.verifyEqual(detected_freq, f_temporal, 'RelTol', 0.1, ...
                    'Wave should oscillate at correct frequency');
            end
        end
    end
    
    %% Temporal Covariance Tests
    methods (Test)
        function testTemporalCovariance(testCase)
            % Test computing temporal covariance
            B = testCase.Bct;
            
            % Generate spatiotemporal signal
            X = randn(B.Manifold.N, B.Time.N);
            
            % Temporal covariance: C_t = (1/T) * X * X'
            C_temporal = (X * X') / B.Time.N;
            
            testCase.verifySize(C_temporal, [B.Manifold.N, B.Manifold.N]);
            testCase.verifyEqual(C_temporal, C_temporal', 'RelTol', 1e-10, ...
                'Covariance should be symmetric');
        end
        
        function testSpatialCovariance(testCase)
            % Test computing spatial covariance
            B = testCase.Bct;
            
            % Generate signal
            X = randn(B.Manifold.N, B.Time.N);
            
            % Spatial covariance: C_s = (1/N) * X' * X
            C_spatial = (X' * X) / B.Manifold.N;
            
            testCase.verifySize(C_spatial, [B.Time.N, B.Time.N]);
            testCase.verifyEqual(C_spatial, C_spatial', 'RelTol', 1e-10);
        end
    end
    
    %% Connectivity Analysis Tests
    methods (Test)
        function testFunctionalConnectivity(testCase)
            % Test computing functional connectivity
            B = testCase.Bct;
            
            % Generate correlated signals
            % Two nearby vertices should have correlated activity
            X = randn(B.Manifold.N, B.Time.N);
            
            % Correlation matrix
            R = corrcoef(X');
            
            testCase.verifySize(R, [B.Manifold.N, B.Manifold.N]);
            
            % Diagonal should be 1
            testCase.verifyEqual(diag(R), ones(B.Manifold.N, 1), 'RelTol', 1e-10);
            
            % Should be symmetric
            testCase.verifyEqual(R, R', 'RelTol', 1e-10);
        end
    end
    
    %% Temporal Smoothing Tests
    methods (Test)
        function testTemporalMovingAverage(testCase)
            % Test temporal smoothing with moving average
            B = testCase.Bct;
            
            % Create noisy signal
            X_clean = sin(2*pi*10 * B.Time.t)';
            X_clean = repmat(X_clean, B.Manifold.N, 1);
            X_noisy = X_clean + 0.5*randn(size(X_clean));
            
            % Moving average filter
            window = 5;
            X_smoothed = movmean(X_noisy, window, 2);
            
            testCase.verifySize(X_smoothed, size(X_noisy));
            
            % Smoothed should be closer to clean
            error_noisy = norm(X_noisy - X_clean, 'fro');
            error_smoothed = norm(X_smoothed - X_clean, 'fro');
            
            testCase.verifyLessThan(error_smoothed, error_noisy, ...
                'Smoothing should reduce noise');
        end
    end
    
    %% Spatial Smoothing Tests
    methods (Test)
        function testSpatialGaussianSmoothing(testCase)
            % Test spatial smoothing via graph diffusion
            B = testCase.Bct;
            
            % Create spatially noisy signal
            X = randn(B.Manifold.N, 10);  % 10 time points
            
            % Smooth spatially using heat kernel
            sigma = 0.5;
            L = B.Manifold.L;
            I = speye(B.Manifold.N);
            
            % Heat kernel: exp(-sigma*L)
            % Approximation: (I + sigma*L)^{-1}
            H = I + sigma*L;
            X_smoothed = H \ X;
            
            testCase.verifySize(X_smoothed, size(X));
            
            % Smoothed should have less high-frequency content
            X_hat = B.Lambda.U' * X;
            X_hat_smoothed = B.Lambda.U' * X_smoothed;
            
            high_freq_orig = norm(X_hat(end-9:end, :), 'fro');
            high_freq_smooth = norm(X_hat_smoothed(end-9:end, :), 'fro');
            
            testCase.verifyLessThan(high_freq_smooth, high_freq_orig, ...
                'Smoothing should reduce high frequencies');
        end
    end
    
    %% Complete Workflow Tests
    methods (Test)
        function testCompleteSpatiotemporalPipeline(testCase)
            % Test complete spatiotemporal analysis pipeline
            
            % 1. Setup
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            B = B.createJoint('Lambda', 'Omega');
            
            % 2. Generate spatiotemporal signal
            spatial_mode = B.Lambda.U(:, 5);
            temporal_osc = sin(2*pi*20 * B.Time.t);
            X = spatial_mode * temporal_osc';
            
            % 3. Add noise
            X_noisy = X + 0.1*randn(size(X));
            
            % 4. Spatial smoothing
            sigma_spatial = 0.1;
            L = B.Manifold.L;
            I = speye(B.Manifold.N);
            H_spatial = I + sigma_spatial*L;
            X_smooth_space = H_spatial \ X_noisy;
            
            % 5. Temporal smoothing
            X_smooth_both = movmean(X_smooth_space, 3, 2);
            
            % 6. Verify improvement
            error_orig = norm(X_noisy - X, 'fro');
            error_smooth = norm(X_smooth_both - X, 'fro');
            
            testCase.verifyLessThan(error_smooth, error_orig, ...
                'Spatiotemporal smoothing should reduce error');
            
            % 7. Transform to joint domain
            X_hat_spatial = B.Lambda.U' * X_smooth_both;
            X_hat = fft(X_hat_spatial, [], 2);
            
            testCase.verifyNotEmpty(X_hat, 'Joint transform successful');
        end
    end
end
