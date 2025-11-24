classdef TestJointFiltering < matlab.unittest.TestCase
    % TESTJOINTFILTERING Integration tests for joint spatiotemporal filtering
    %
    % Tests complete joint filtering workflows including:
    % - Joint domain transforms
    % - Spatiotemporal filter design
    % - Filter application
    % - Signal reconstruction
    
    properties
        Bct
        TestSignal
        FilterDesigner
    end
    
    methods (TestClassSetup)
        function setupBctObject(testCase)
            % Create full bct object for joint filtering
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            % Add time domain
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            
            % Create joint domain
            B = B.createJoint('Lambda', 'Omega');
            
            testCase.Bct = B;
            testCase.FilterDesigner = bct.filters.FilterDesigner(B);
            
            % Create spatiotemporal test signal
            testCase.TestSignal = randn(B.Manifold.N, B.Time.N);
        end
    end
    
    %% Joint Transform Tests
    methods (Test)
        function testJointForwardTransform(testCase)
            % Test joint spatiotemporal Fourier transform
            B = testCase.Bct;
            X = testCase.TestSignal;
            
            % Joint transform: X_hat = U' * X * V
            % where U = spatial eigenbasis, V = temporal Fourier basis
            X_hat_spatial = B.Lambda.U' * X;  % Transform spatial
            
            % Then transform temporal (FFT along time)
            X_hat = fft(X_hat_spatial, [], 2);
            
            testCase.verifySize(X_hat, [B.Lambda.K, B.Time.N], ...
                'Joint coefficients should match domain sizes');
        end
        
        function testJointInverseTransform(testCase)
            % Test reconstruction from joint domain
            B = testCase.Bct;
            X_orig = testCase.TestSignal;
            
            % Forward transform
            X_hat_spatial = B.Lambda.U' * X_orig;
            X_hat = fft(X_hat_spatial, [], 2);
            
            % Inverse transform
            X_recon_spatial = ifft(X_hat, [], 2, 'symmetric');
            X_recon = B.Lambda.U * X_recon_spatial;
            
            testCase.verifyEqual(X_recon, X_orig, 'RelTol', 1e-10, ...
                'Joint reconstruction should match original');
        end
    end
    
    %% Joint Filter Design Tests
    methods (Test)
        function testGaussianJointFilter(testCase)
            % Test Gaussian joint filter design
            FD = testCase.FilterDesigner;
            
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5);
            
            testCase.verifyNotEmpty(F, 'Filter should be created');
            
            % Evaluate filter
            H = F.evaluate();
            
            B = testCase.Bct;
            testCase.verifyEqual(size(H), B.Joint.N, ...
                'Filter response should match joint grid');
        end
        
        function testGaborJointFilter(testCase)
            % Test Gabor (modulated Gaussian) filter
            FD = testCase.FilterDesigner;
            
            F = FD.joint('gabor', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5);
            
            H = F.evaluate();
            
            testCase.verifyNotEmpty(H, 'Gabor response should exist');
        end
        
        function testSeparableFilter(testCase)
            % Test separable joint filter (product of spatial and temporal)
            FD = testCase.FilterDesigner;
            B = testCase.Bct;
            
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5);
            
            H = F.evaluate();
            
            % For separable filter: H(k, omega) = H_spatial(k) * H_temporal(omega)
            % Check separability
            [U, S, V] = svd(H);
            singular_values = diag(S);
            
            % Separable filter should have rank 1
            testCase.verifyLessThan(singular_values(2) / singular_values(1), 0.1, ...
                'Separable filter should have dominant singular value');
        end
    end
    
    %% Joint Filtering Application Tests
    methods (Test)
        function testApplyJointFilter(testCase)
            % Test applying joint filter to spatiotemporal signal
            FD = testCase.FilterDesigner;
            B = testCase.Bct;
            X = testCase.TestSignal;
            
            % Design filter
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20, 'sigma_y', 5);
            
            % Get filter response
            H = F.evaluate();
            
            % Transform signal to joint domain
            X_hat_spatial = B.Lambda.U' * X;
            X_hat = fft(X_hat_spatial, [], 2);
            
            % Apply filter element-wise
            X_hat_filtered = X_hat .* H;
            
            % Inverse transform
            X_filtered_spatial = ifft(X_hat_filtered, [], 2, 'symmetric');
            X_filtered = B.Lambda.U * X_filtered_spatial;
            
            testCase.verifySize(X_filtered, size(X), ...
                'Filtered signal should match original size');
            testCase.verifyLessThan(norm(X_filtered, 'fro'), norm(X, 'fro'), ...
                'Filtering should reduce signal energy');
        end
        
        function testMultibandFiltering(testCase)
            % Test multiband filtering with multiple filters
            FD = testCase.FilterDesigner;
            B = testCase.Bct;
            X = testCase.TestSignal;
            
            % Create filter bank
            centers_freq = [10, 20, 30, 40];
            n_filters = length(centers_freq);
            
            filtered_bands = cell(n_filters, 1);
            
            for i = 1:n_filters
                % Design filter
                F = FD.joint('gaussian', ...
                    'center_x', 0.5, 'sigma_x', 0.1, ...
                    'center_y', centers_freq(i), 'sigma_y', 3);
                
                H = F.evaluate();
                
                % Apply filter
                X_hat_spatial = B.Lambda.U' * X;
                X_hat = fft(X_hat_spatial, [], 2);
                X_hat_filtered = X_hat .* H;
                X_filtered_spatial = ifft(X_hat_filtered, [], 2, 'symmetric');
                
                filtered_bands{i} = B.Lambda.U * X_filtered_spatial;
            end
            
            % Verify each band
            for i = 1:n_filters
                testCase.verifySize(filtered_bands{i}, size(X));
            end
        end
    end
    
    %% Spatiotemporal Pattern Tests
    methods (Test)
        function testTravelingWaveDetection(testCase)
            % Test detecting traveling wave patterns
            B = testCase.Bct;
            FD = testCase.FilterDesigner;
            
            % Create synthetic traveling wave
            % Spatial frequency k0, temporal frequency f0
            k0 = 0.5;
            f0 = 20;  % Hz
            omega0 = 2*pi*f0;
            
            % Generate wave: spatial mode × temporal oscillation
            if B.Lambda.K > 5
                spatial_mode = B.Lambda.U(:, 5);
                temporal_osc = sin(omega0 * B.Time.t);
                
                X_wave = spatial_mode * temporal_osc';
                
                % Design matched filter
                F = FD.joint('gaussian', ...
                    'center_x', k0, 'sigma_x', 0.1, ...
                    'center_y', omega0, 'sigma_y', 2*pi*2);
                
                H = F.evaluate();
                
                % Transform and filter
                X_hat_spatial = B.Lambda.U' * X_wave;
                X_hat = fft(X_hat_spatial, [], 2);
                X_hat_filtered = X_hat .* H;
                
                % Check energy concentration
                total_energy = sum(abs(X_hat(:)).^2);
                filtered_energy = sum(abs(X_hat_filtered(:)).^2);
                
                testCase.verifyGreaterThan(filtered_energy / total_energy, 0.01, ...
                    'Filter should preserve wave energy');
            end
        end
        
        function testStandingWaveFiltering(testCase)
            % Test filtering standing wave patterns
            B = testCase.Bct;
            FD = testCase.FilterDesigner;
            
            % Create standing wave (spatial pattern × temporal cosine)
            if B.Lambda.K > 3
                spatial_pattern = B.Lambda.U(:, 3);
                temporal_pattern = cos(2*pi*15 * B.Time.t);  % 15 Hz
                
                X_standing = spatial_pattern * temporal_pattern';
                
                % Filter around standing wave frequency
                F = FD.joint('gaussian', ...
                    'center_x', B.Lambda.axis(3), 'sigma_x', 0.05, ...
                    'center_y', 2*pi*15, 'sigma_y', 2*pi*3);
                
                H = F.evaluate();
                
                % Apply filter
                X_hat_spatial = B.Lambda.U' * X_standing;
                X_hat = fft(X_hat_spatial, [], 2);
                X_hat_filtered = X_hat .* H;
                X_filtered_spatial = ifft(X_hat_filtered, [], 2, 'symmetric');
                X_filtered = B.Lambda.U * X_filtered_spatial;
                
                % Filtered output should be similar to input
                correlation = corrcoef(X_standing(:), X_filtered(:));
                testCase.verifyGreaterThan(abs(correlation(1,2)), 0.5, ...
                    'Filtered standing wave should correlate with original');
            end
        end
    end
    
    %% Frequency-Wavenumber Analysis Tests
    methods (Test)
        function testFrequencyWavenumberSpectrum(testCase)
            % Test joint frequency-wavenumber spectrum computation
            B = testCase.Bct;
            X = testCase.TestSignal;
            
            % Compute joint spectrum
            X_hat_spatial = B.Lambda.U' * X;
            X_hat = fft(X_hat_spatial, [], 2);
            
            % Power spectrum
            P = abs(X_hat).^2;
            
            testCase.verifyEqual(size(P), [B.Lambda.K, B.Time.N], ...
                'Spectrum should match joint grid');
            testCase.verifyGreaterThanOrEqual(min(P(:)), 0, ...
                'Power should be non-negative');
        end
        
        function testDispersionRelation(testCase)
            % Test extracting dispersion relation (omega vs k)
            B = testCase.Bct;
            
            % Create wave with known dispersion
            % omega = c * k (linear dispersion)
            c = 2;  % wave speed
            
            if B.Lambda.K > 10
                k_idx = 10;
                k = B.Lambda.axis(k_idx);
                omega = c * k;
                f = omega / (2*pi);
                
                % Generate wave
                spatial_mode = B.Lambda.U(:, k_idx);
                temporal_osc = sin(omega * B.Time.t);
                X_wave = spatial_mode * temporal_osc';
                
                % Transform
                X_hat_spatial = B.Lambda.U' * X_wave;
                X_hat = fft(X_hat_spatial, [], 2);
                P = abs(X_hat).^2;
                
                % Find peak in spectrum
                [max_val, max_idx] = max(P(:));
                [k_peak_idx, omega_peak_idx] = ind2sub(size(P), max_idx);
                
                testCase.verifyEqual(k_peak_idx, k_idx, ...
                    'Peak wavenumber should match input');
            end
        end
    end
    
    %% Complete Workflow Tests
    methods (Test)
        function testCompleteJointPipeline(testCase)
            % Test complete joint filtering pipeline
            
            % 1. Create full bct object
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            B = B.createJoint('Lambda', 'Omega');
            
            % 2. Create spatiotemporal signal
            X = randn(B.Manifold.N, B.Time.N);
            
            % 3. Design joint filter
            FD = bct.filters.FilterDesigner(B);
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20*2*pi, 'sigma_y', 5*2*pi);
            
            % 4. Evaluate filter
            H = F.evaluate();
            testCase.verifyNotEmpty(H);
            
            % 5. Transform signal
            X_hat_spatial = B.Lambda.U' * X;
            X_hat = fft(X_hat_spatial, [], 2);
            
            % 6. Apply filter
            X_hat_filtered = X_hat .* H;
            
            % 7. Reconstruct
            X_filtered_spatial = ifft(X_hat_filtered, [], 2, 'symmetric');
            X_filtered = B.Lambda.U * X_filtered_spatial;
            
            testCase.verifySize(X_filtered, size(X));
            testCase.verifyLessThan(norm(X_filtered, 'fro'), norm(X, 'fro'));
        end
    end
end
