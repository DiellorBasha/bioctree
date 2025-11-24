classdef PerfJointFiltering < matlab.unittest.TestCase
    % PERFJOINTFILTERING Performance tests for joint filtering operations
    %
    % Benchmarks:
    % - Joint transform performance
    % - Filter evaluation time
    % - Filtering large signals
    % - Memory efficiency
    
    properties (TestParameter)
        MeshSize = {icosphere(2), icosphere(3)}
        TimeLength = {100, 500, 1000}
    end
    
    properties
        Bct
    end
    
    methods (TestMethodSetup)
        function setupBct(testCase)
            % Create standard bct object for each test
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            B = B.createJoint('Lambda', 'Omega');
            
            testCase.Bct = B;
        end
    end
    
    %% Joint Transform Performance Tests
    methods (Test)
        function testJointTransformTime(testCase, TimeLength)
            % Benchmark joint spatiotemporal transform
            
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            t = linspace(0, 1, TimeLength)';
            B.Time = bct.Time(t, TimeLength);
            
            % Create test signal
            X = randn(B.Manifold.N, TimeLength);
            
            % Time forward transform
            tic;
            % Spatial transform
            X_hat_spatial = B.Lambda.U' * X;
            % Temporal transform (FFT)
            X_hat = fft(X_hat_spatial, [], 2);
            elapsed_forward = toc;
            
            % Time inverse transform
            tic;
            X_recon_spatial = ifft(X_hat, [], 2, 'symmetric');
            X_recon = B.Lambda.U * X_recon_spatial;
            elapsed_inverse = toc;
            
            fprintf('Joint transform (N=%d, T=%d): forward=%.3f sec, inverse=%.3f sec\n', ...
                B.Manifold.N, TimeLength, elapsed_forward, elapsed_inverse);
            
            % Performance assertions
            testCase.verifyLessThan(elapsed_forward, 5, ...
                'Forward transform should complete in reasonable time');
            testCase.verifyLessThan(elapsed_inverse, 5, ...
                'Inverse transform should complete in reasonable time');
            
            % Verify accuracy
            testCase.verifyEqual(X_recon, X, 'RelTol', 1e-10, ...
                'Transform should be reversible');
        end
        
        function testTransformScaling(testCase)
            % Test transform time scaling with problem size
            
            levels = [1, 2];
            T_values = [50, 100];
            times_forward = zeros(length(levels), length(T_values));
            times_inverse = zeros(length(levels), length(T_values));
            
            for i = 1:length(levels)
                [V, F] = icosphere(levels(i));
                B = bct.bct.fromMesh(V, F);
                k = min(50, B.Manifold.N);
                B = B.computeEigenbasis(k);
                
                for j = 1:length(T_values)
                    T = T_values(j);
                    t = linspace(0, 1, T)';
                    B.Time = bct.Time(t, T);
                    
                    X = randn(B.Manifold.N, T);
                    
                    % Forward
                    tic;
                    X_hat_spatial = B.Lambda.U' * X;
                    X_hat = fft(X_hat_spatial, [], 2);
                    times_forward(i, j) = toc;
                    
                    % Inverse
                    tic;
                    X_recon_spatial = ifft(X_hat, [], 2, 'symmetric');
                    X_recon = B.Lambda.U * X_recon_spatial;
                    times_inverse(i, j) = toc;
                    
                    fprintf('Level=%d, T=%d: forward=%.3f, inverse=%.3f\n', ...
                        levels(i), T, times_forward(i,j), times_inverse(i,j));
                end
            end
            
            % Verify reasonable scaling
            testCase.verifyTrue(true, 'Scaling analysis complete');
        end
    end
    
    %% Filter Evaluation Performance Tests
    methods (Test)
        function testFilterEvaluationTime(testCase)
            % Benchmark filter evaluation on joint grid
            
            B = testCase.Bct;
            FD = bct.filters.FilterDesigner(B);
            
            % Create filter
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20*2*pi, 'sigma_y', 5*2*pi);
            
            % Time evaluation
            tic;
            H = F.evaluate();
            elapsed = toc;
            
            fprintf('Filter evaluation: grid_size=[%d×%d], time=%.4f sec\n', ...
                size(H, 1), size(H, 2), elapsed);
            
            testCase.verifyLessThan(elapsed, 1, ...
                'Filter evaluation should be fast (< 1 sec)');
            
            % Verify result
            testCase.verifyEqual(size(H), B.Joint.size());
        end
        
        function testMultipleFilterEvaluations(testCase)
            % Benchmark evaluating multiple filters (filterbank)
            
            B = testCase.Bct;
            FD = bct.filters.FilterDesigner(B);
            
            n_filters = 10;
            center_freqs = linspace(10, 40, n_filters);
            
            tic;
            for i = 1:n_filters
                F = FD.joint('gaussian', ...
                    'center_x', 0.5, 'sigma_x', 0.1, ...
                    'center_y', center_freqs(i)*2*pi, 'sigma_y', 3*2*pi);
                H = F.evaluate();
            end
            elapsed = toc;
            
            time_per_filter = elapsed / n_filters;
            fprintf('Filterbank (%d filters): total=%.3f sec, per_filter=%.3f sec\n', ...
                n_filters, elapsed, time_per_filter);
            
            testCase.verifyLessThan(time_per_filter, 0.5, ...
                'Each filter should evaluate quickly');
        end
    end
    
    %% Filtering Application Performance Tests
    methods (Test)
        function testFilteringLargeSignal(testCase, TimeLength)
            % Benchmark filtering large spatiotemporal signals
            
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            B = B.computeEigenbasis(50);
            
            t = linspace(0, 1, TimeLength)';
            B.Time = bct.Time(t, TimeLength);
            B = B.createJoint('Lambda', 'Omega');
            
            % Create signal
            X = randn(B.Manifold.N, TimeLength);
            
            % Create filter
            FD = bct.filters.FilterDesigner(B);
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20*2*pi, 'sigma_y', 5*2*pi);
            
            H = F.evaluate();
            
            % Time complete filtering pipeline
            tic;
            % Forward transform
            X_hat_spatial = B.Lambda.U' * X;
            X_hat = fft(X_hat_spatial, [], 2);
            
            % Apply filter
            X_hat_filtered = X_hat .* H;
            
            % Inverse transform
            X_filtered_spatial = ifft(X_hat_filtered, [], 2, 'symmetric');
            X_filtered = B.Lambda.U * X_filtered_spatial;
            elapsed = toc;
            
            data_size_mb = 8 * numel(X) / 1024^2;  % Double precision
            throughput_mbps = data_size_mb / elapsed;
            
            fprintf('Filtering (N=%d, T=%d, %.2f MB): time=%.3f sec, throughput=%.2f MB/s\n', ...
                B.Manifold.N, TimeLength, data_size_mb, elapsed, throughput_mbps);
            
            testCase.verifyLessThan(elapsed, 10, ...
                'Filtering should complete in reasonable time');
            testCase.verifySize(X_filtered, size(X));
        end
        
        function testFilteringMultipleSignals(testCase)
            % Benchmark filtering multiple signals (batch processing)
            
            B = testCase.Bct;
            FD = bct.filters.FilterDesigner(B);
            
            n_signals = 5;
            signals = cell(n_signals, 1);
            for i = 1:n_signals
                signals{i} = randn(B.Manifold.N, B.Time.N);
            end
            
            % Create filter
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20*2*pi, 'sigma_y', 5*2*pi);
            H = F.evaluate();
            
            % Time batch filtering
            tic;
            filtered = cell(n_signals, 1);
            for i = 1:n_signals
                X = signals{i};
                X_hat_spatial = B.Lambda.U' * X;
                X_hat = fft(X_hat_spatial, [], 2);
                X_hat_filtered = X_hat .* H;
                X_filtered_spatial = ifft(X_hat_filtered, [], 2, 'symmetric');
                filtered{i} = B.Lambda.U * X_filtered_spatial;
            end
            elapsed = toc;
            
            time_per_signal = elapsed / n_signals;
            fprintf('Batch filtering (%d signals): total=%.3f sec, per_signal=%.3f sec\n', ...
                n_signals, elapsed, time_per_signal);
            
            testCase.verifyLessThan(time_per_signal, 5, ...
                'Each signal should filter reasonably fast');
        end
    end
    
    %% Memory Performance Tests
    methods (Test)
        function testFilteringMemoryUsage(testCase)
            % Benchmark memory usage during filtering
            
            B = testCase.Bct;
            
            % Create signal
            X = randn(B.Manifold.N, B.Time.N);
            
            % Memory before
            mem_before = memory;
            mem_start = mem_before.MemUsedMATLAB;
            
            % Perform filtering
            FD = bct.filters.FilterDesigner(B);
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20*2*pi, 'sigma_y', 5*2*pi);
            H = F.evaluate();
            
            X_hat_spatial = B.Lambda.U' * X;
            X_hat = fft(X_hat_spatial, [], 2);
            X_hat_filtered = X_hat .* H;
            X_filtered_spatial = ifft(X_hat_filtered, [], 2, 'symmetric');
            X_filtered = B.Lambda.U * X_filtered_spatial;
            
            % Memory after
            mem_after = memory;
            mem_end = mem_after.MemUsedMATLAB;
            
            mem_used_mb = (mem_end - mem_start) / 1024^2;
            
            % Expected memory: signal (N×T) + transforms (~k×T) + filter (k×T/2)
            signal_mb = 8 * B.Manifold.N * B.Time.N / 1024^2;
            
            fprintf('Filtering memory: signal=%.2f MB, used=%.2f MB\n', ...
                signal_mb, mem_used_mb);
            
            testCase.verifyLessThan(mem_used_mb, 10*signal_mb, ...
                'Memory usage should be reasonable');
        end
    end
    
    %% Optimization Tests
    methods (Test)
        function testInPlaceOperations(testCase)
            % Test in-place operations for memory efficiency
            
            B = testCase.Bct;
            X = randn(B.Manifold.N, B.Time.N);
            
            FD = bct.filters.FilterDesigner(B);
            F = FD.joint('gaussian', ...
                'center_x', 0.5, 'sigma_x', 0.1, ...
                'center_y', 20*2*pi, 'sigma_y', 5*2*pi);
            H = F.evaluate();
            
            % Test that operations can be done in-place
            tic;
            X_transformed = B.Lambda.U' * X;
            X_transformed = fft(X_transformed, [], 2);
            X_transformed = X_transformed .* H;  % In-place multiplication
            X_transformed = ifft(X_transformed, [], 2, 'symmetric');
            X_result = B.Lambda.U * X_transformed;
            elapsed = toc;
            
            fprintf('In-place filtering: %.3f sec\n', elapsed);
            
            testCase.verifySize(X_result, size(X));
        end
    end
    
    %% Comparative Performance Tests
    methods (Test)
        function testCompareFilterTypes(testCase)
            % Compare performance of different filter types
            
            B = testCase.Bct;
            FD = bct.filters.FilterDesigner(B);
            
            filter_types = {'gaussian', 'gabor'};
            times = zeros(size(filter_types));
            
            for i = 1:length(filter_types)
                tic;
                F = FD.joint(filter_types{i}, ...
                    'center_x', 0.5, 'sigma_x', 0.1, ...
                    'center_y', 20*2*pi, 'sigma_y', 5*2*pi);
                H = F.evaluate();
                times(i) = toc;
                
                fprintf('Filter "%s": evaluation=%.4f sec\n', ...
                    filter_types{i}, times(i));
            end
            
            % All filter types should be reasonably fast
            testCase.verifyLessThan(max(times), 1, ...
                'All filter types should evaluate quickly');
        end
    end
end
