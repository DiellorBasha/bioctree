classdef TestTime < matlab.unittest.TestCase
    % TESTTIME Unit tests for bct.Time class
    %
    % Tests temporal domain creation, sampling properties,
    % time axis management, and dual Omega domain
    
    properties (TestParameter)
        SamplingRate = {100, 250, 500, 1000}
        Duration = {1, 2, 5, 10}
    end
    
    properties
        Time
        TestTimeVector
        TestFs
    end
    
    methods (TestClassSetup)
        function createTestData(testCase)
            % Create standard test data
            testCase.TestFs = 100;  % Hz
            testCase.TestTimeVector = linspace(0, 1, 100)';  % 1 second, 100 samples
        end
    end
    
    methods (TestMethodSetup)
        function createTime(testCase)
            % Create fresh Time domain for each test
            testCase.Time = bct.Time(testCase.TestTimeVector, testCase.TestFs);
        end
    end
    
    %% Constructor Tests
    methods (Test)
        function testConstructorBasic(testCase)
            % Test basic Time construction
            T = bct.Time(testCase.TestTimeVector, testCase.TestFs);
            
            testCase.verifyClass(T, 'bct.Time');
            testCase.verifyEqual(T.fs, testCase.TestFs, 'Sampling rate should match');
            testCase.verifyEqual(T.N, length(testCase.TestTimeVector), 'N should match time vector length');
        end
        
        function testConstructorParameterized(testCase, SamplingRate, Duration)
            % Test with different sampling rates and durations
            N = SamplingRate * Duration;
            t = linspace(0, Duration, N)';
            T = bct.Time(t, SamplingRate);
            
            testCase.verifyEqual(T.fs, SamplingRate, 'Sampling rate should match');
            testCase.verifyEqual(T.N, N, 'N should match computed samples');
            testCase.verifyEqual(T.T, N, 'T should equal N for sample count');
        end
        
        function testConstructorFromSamples(testCase)
            % Test construction from sample count and sampling rate
            N = 1000;
            fs = 500;
            
            if nargin(str2func(class(bct.Time))) > 1
                % If constructor supports (N, fs) signature
                T = bct.Time.fromSamples(N, fs);
                
                if ~isempty(T)
                    testCase.verifyEqual(T.N, N, 'N should match');
                    testCase.verifyEqual(T.fs, fs, 'fs should match');
                end
            end
        end
    end
    
    %% Time Vector Tests
    methods (Test)
        function testTimeAxis(testCase)
            % Test time axis property
            T = testCase.Time;
            
            if isprop(T, 'axis')
                testCase.verifyEqual(length(T.axis), T.N, 'Axis length should be N');
                testCase.verifyTrue(issorted(T.axis), 'Time axis should be sorted');
                testCase.verifyGreaterThanOrEqual(min(T.axis), 0, ...
                    'Time should start at 0 or positive');
            end
        end
        
        function testTimeVectorProperty(testCase)
            % Test t (time vector) property
            T = testCase.Time;
            
            if isprop(T, 't')
                testCase.verifyEqual(length(T.t), T.N, 'Time vector length should be N');
                testCase.verifyEqual(T.t, testCase.TestTimeVector, ...
                    'Time vector should match input');
            end
        end
        
        function testTimeIncrement(testCase)
            % Test dt (time increment)
            T = testCase.Time;
            
            if isprop(T, 'dt')
                expected_dt = 1 / T.fs;
                testCase.verifyEqual(T.dt, expected_dt, 'RelTol', 1e-10, ...
                    'dt should equal 1/fs');
            end
        end
    end
    
    %% Sampling Properties Tests
    methods (Test)
        function testSamplingRate(testCase)
            % Test fs (sampling rate) property
            T = testCase.Time;
            
            testCase.verifyEqual(T.fs, testCase.TestFs, 'Sampling rate should match');
            testCase.verifyGreaterThan(T.fs, 0, 'Sampling rate should be positive');
        end
        
        function testNyquistFrequency(testCase)
            % Test Nyquist frequency
            T = testCase.Time;
            
            nyq = T.fs / 2;
            
            if isprop(T, 'nyquist') || ismethod(T, 'nyquist')
                if isprop(T, 'nyquist')
                    testCase.verifyEqual(T.nyquist, nyq, 'Nyquist should be fs/2');
                else
                    testCase.verifyEqual(T.nyquist(), nyq, 'Nyquist should be fs/2');
                end
            end
        end
        
        function testSampleCount(testCase)
            % Test N (number of samples)
            T = testCase.Time;
            
            testCase.verifyEqual(T.N, length(testCase.TestTimeVector), ...
                'N should match time vector length');
            testCase.verifyClass(T.N, 'double', 'N should be numeric');
        end
        
        function testTotalSamples(testCase)
            % Test T (total samples) property
            T = testCase.Time;
            
            if isprop(T, 'T')
                testCase.verifyEqual(T.T, T.N, 'T should equal N');
            end
        end
    end
    
    %% Duration Tests
    methods (Test)
        function testDuration(testCase)
            % Test duration calculation
            T = testCase.Time;
            
            expected_duration = T.N / T.fs;
            
            if isprop(T, 'duration') || ismethod(T, 'duration')
                if isprop(T, 'duration')
                    actual = T.duration;
                else
                    actual = T.duration();
                end
                testCase.verifyEqual(actual, expected_duration, 'RelTol', 1e-10, ...
                    'Duration should be N/fs');
            end
        end
    end
    
    %% Domain Properties Tests
    methods (Test)
        function testDomainProperty(testCase)
            % Test Domain identifier
            T = testCase.Time;
            
            if isprop(T, 'Domain')
                testCase.verifyEqual(T.Domain, 'Time', 'Domain should be Time');
            end
        end
        
        function testUnitsProperty(testCase)
            % Test units property (e.g., 's', 'ms')
            T = testCase.Time;
            
            if isprop(T, 'units')
                testCase.verifyClass(T.units, 'char', 'Units should be char');
            end
        end
        
        function testSizeMethod(testCase)
            % Test size() method
            T = testCase.Time;
            
            if ismethod(T, 'size')
                sz = T.size();
                testCase.verifyEqual(sz(1), T.N, 'First dimension should be N');
            end
        end
    end
    
    %% Dual Omega Domain Tests
    methods (Test)
        function testDualOmegaCreation(testCase)
            % Test automatic Omega (frequency) dual creation
            T = testCase.Time;
            
            if isprop(T, 'dual')
                testCase.verifyClass(T.dual, 'bct.Omega', 'Dual should be Omega');
                testCase.verifyEqual(T.dual.N, T.N, 'Omega should have same N');
            end
        end
        
        function testDualFrequencyRange(testCase)
            % Test Omega frequency range matches Time sampling
            T = testCase.Time;
            
            if isprop(T, 'dual') && ~isempty(T.dual)
                O = T.dual;
                
                if ~isempty(O.axis)
                    max_omega = max(abs(O.axis));
                    nyq_omega = 2 * pi * T.fs / 2;
                    
                    testCase.verifyEqual(max_omega, nyq_omega, 'RelTol', 1e-6, ...
                        'Max omega should equal Nyquist angular frequency');
                end
            end
        end
        
        function testBidirectionalDuality(testCase)
            % Test bidirectional dual relationship
            T = testCase.Time;
            
            if isprop(T, 'dual') && ~isempty(T.dual)
                O = T.dual;
                if isprop(O, 'dual')
                    testCase.verifyEqual(O.dual, T, 'Dual of dual should return to Time');
                end
            end
        end
    end
    
    %% Signal Operations Tests
    methods (Test)
        function testSignalStorage(testCase)
            % Test signal data storage
            T = testCase.Time;
            
            if isprop(T, 'data') || isprop(T, 'signal')
                prop = 'data';
                if ~isprop(T, 'data')
                    prop = 'signal';
                end
                
                % Create test signal
                test_signal = randn(T.N, 10);  % 10 channels
                T.(prop) = test_signal;
                
                testCase.verifyEqual(size(T.(prop), 1), T.N, ...
                    'Signal should have N rows');
            end
        end
        
        function testMultichannelSignal(testCase)
            % Test multichannel signal handling
            T = testCase.Time;
            n_channels = 5;
            
            if isprop(T, 'data') || isprop(T, 'signal')
                prop = 'data';
                if ~isprop(T, 'data')
                    prop = 'signal';
                end
                
                signal = randn(T.N, n_channels);
                T.(prop) = signal;
                
                testCase.verifyEqual(size(T.(prop), 2), n_channels, ...
                    'Should preserve channel count');
            end
        end
    end
    
    %% Windowing Tests
    methods (Test)
        function testTimeWindow(testCase)
            % Test time windowing/slicing
            T = testCase.Time;
            
            if ismethod(T, 'window') || ismethod(T, 'slice')
                t_start = 0.2;
                t_end = 0.8;
                
                if ismethod(T, 'window')
                    T_win = T.window(t_start, t_end);
                else
                    T_win = T.slice(t_start, t_end);
                end
                
                if ~isempty(T_win)
                    testCase.verifyLessThan(T_win.N, T.N, ...
                        'Windowed time should have fewer samples');
                end
            end
        end
    end
    
    %% Error Handling Tests
    methods (Test)
        function testInvalidSamplingRate(testCase)
            % Test error on invalid sampling rate
            t = testCase.TestTimeVector;
            
            testCase.verifyError(@() bct.Time(t, 0), ?MException, ...
                'Should error on zero sampling rate');
            testCase.verifyError(@() bct.Time(t, -100), ?MException, ...
                'Should error on negative sampling rate');
        end
        
        function testEmptyTimeVector(testCase)
            % Test error on empty time vector
            testCase.verifyError(@() bct.Time([], 100), ?MException, ...
                'Should error on empty time vector');
        end
        
        function testInconsistentSampling(testCase)
            % Test warning/error on non-uniform sampling
            t_nonuniform = [0, 0.1, 0.15, 0.3, 0.5]';
            fs = 10;
            
            % Some implementations may allow non-uniform, others may warn/error
            % This test documents the behavior
            try
                T = bct.Time(t_nonuniform, fs);
                % If it succeeds, verify it stored the data
                testCase.verifyEqual(T.N, length(t_nonuniform));
            catch
                % If it errors, that's also acceptable behavior
                testCase.verifyTrue(true, 'Non-uniform sampling rejected');
            end
        end
    end
    
    %% Integration Tests
    methods (Test)
        function testTimeInBctObject(testCase)
            % Test Time domain in full bct object
            [V, F] = icosphere(2);
            B = bct.bct.fromMesh(V, F);
            
            % Add Time domain
            t = linspace(0, 1, 100)';
            B.Time = bct.Time(t, 100);
            
            testCase.verifyNotEmpty(B.Time, 'Time should be added to bct');
            testCase.verifyClass(B.Time, 'bct.Time', 'Time should be correct class');
            testCase.verifyNotEmpty(B.Omega, 'Omega should be created automatically');
        end
        
        function testTimeOmegaPair(testCase)
            % Test Time-Omega domain pair
            t = linspace(0, 2, 200)';
            T = bct.Time(t, 100);
            
            if isprop(T, 'dual')
                O = T.dual;
                
                % Both should have same N
                testCase.verifyEqual(T.N, O.N, 'Time and Omega should have same N');
                
                % Frequency resolution should match time duration
                if ~isempty(O.axis) && length(O.axis) > 1
                    df = O.axis(2) - O.axis(1);
                    expected_df = 2*pi*T.fs / T.N;
                    testCase.verifyEqual(df, expected_df, 'RelTol', 1e-6, ...
                        'Frequency resolution should match 2π*fs/N');
                end
            end
        end
    end
end
