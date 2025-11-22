%% Test bct.manifold.Time class
% Tests the basic functionality of the Time class

clear all;
close all;

% Add toolbox to path
addpath(fullfile(fileparts(pwd), 'toolbox'));

fprintf('=== Testing bct.manifold.Time Class ===\n\n');

%% Test 1: Basic construction
fprintf('Test 1: Basic construction\n');
T = 1000;
fs = 250;
time = bct.manifold.Time(T, fs);

assert(time.T == T, 'T property not set correctly');
assert(time.fs == fs, 'fs property not set correctly');
fprintf('✓ Construction successful\n\n');

%% Test 2: Get duration
fprintf('Test 2: Duration calculation\n');
expected_duration = T / fs;
duration = time.get_duration();
assert(abs(duration - expected_duration) < 1e-10, 'Duration calculation incorrect');
fprintf('  Duration: %.4f seconds (expected %.4f)\n', duration, expected_duration);
fprintf('✓ Duration calculation correct\n\n');

%% Test 3: Get time vector
fprintf('Test 3: Time vector generation\n');
t = time.get_time_vector();
assert(length(t) == T, 'Time vector length incorrect');
assert(abs(t(1) - 0) < 1e-10, 'Time vector should start at 0');
assert(abs(t(end) - (T-1)/fs) < 1e-10, 'Time vector end time incorrect');
fprintf('  Time vector: %d points from %.4f to %.4f seconds\n', length(t), t(1), t(end));
fprintf('✓ Time vector generation correct\n\n');

%% Test 4: Nyquist frequency
fprintf('Test 4: Nyquist frequency\n');
nyquist = time.get_nyquist_freq();
expected_nyquist = fs / 2;
assert(abs(nyquist - expected_nyquist) < 1e-10, 'Nyquist frequency incorrect');
fprintf('  Nyquist frequency: %.2f Hz (expected %.2f Hz)\n', nyquist, expected_nyquist);
fprintf('✓ Nyquist frequency correct\n\n');

%% Test 5: Display method
fprintf('Test 5: Display method\n');
disp(time);
fprintf('✓ Display method works\n\n');

%% Test 6: Invalid inputs
fprintf('Test 6: Input validation\n');
try
    time_bad = bct.manifold.Time(-100, 250);
    error('Should have thrown error for negative T');
catch ME
    if contains(ME.identifier, 'Time:InvalidT')
        fprintf('✓ Correctly rejected negative T\n');
    else
        rethrow(ME);
    end
end

try
    time_bad = bct.manifold.Time(100.5, 250);
    error('Should have thrown error for non-integer T');
catch ME
    if contains(ME.identifier, 'Time:InvalidT')
        fprintf('✓ Correctly rejected non-integer T\n');
    else
        rethrow(ME);
    end
end

try
    time_bad = bct.manifold.Time(100, -250);
    error('Should have thrown error for negative fs');
catch ME
    if contains(ME.identifier, 'Time:InvalidFs')
        fprintf('✓ Correctly rejected negative fs\n');
    else
        rethrow(ME);
    end
end

try
    time_bad = bct.manifold.Time(100, 0);
    error('Should have thrown error for zero fs');
catch ME
    if contains(ME.identifier, 'Time:InvalidFs')
        fprintf('✓ Correctly rejected zero fs\n');
    else
        rethrow(ME);
    end
end

fprintf('\n=== All Time class tests passed! ===\n');

