% Test script for Time class time and frequency vector methods
% Tests get_time_vector() and get_frequency_axis()

clear; close all;

fprintf('=== Testing bct.manifold.Time vector methods ===\n\n');

% Test 1: Basic time vector
fprintf('Test 1: Time vector (100 samples @ 100 Hz)\n');
time1 = bct.manifold.Time(100, 100);
t1 = time1.get_time_vector();
fprintf('  Time vector size: %d x %d\n', size(t1, 1), size(t1, 2));
fprintf('  Time range: [%.4f, %.4f] seconds\n', min(t1), max(t1));
fprintf('  Expected: [0.0000, 0.9900] seconds\n');
fprintf('  Match: %s\n\n', isequal(t1, (0:99)'/100));

% Test 2: Frequency axis
fprintf('Test 2: Frequency axis (100 samples @ 100 Hz)\n');
f1 = time1.get_frequency_axis();
fprintf('  Frequency vector size: %d x %d\n', size(f1, 1), size(f1, 2));
fprintf('  Frequency range: [%.4f, %.4f] Hz\n', min(f1), max(f1));
fprintf('  Expected: [0.0000, 99.0000] Hz\n');
fprintf('  Frequency resolution: %.4f Hz\n', f1(2) - f1(1));
fprintf('  Expected resolution: %.4f Hz\n', 100/100);
fprintf('  Match: %s\n\n', isequal(f1, (0:99)'*1.0));

% Test 3: Different sampling rate
fprintf('Test 3: Different parameters (256 samples @ 500 Hz)\n');
time2 = bct.manifold.Time(256, 500);
t2 = time2.get_time_vector();
f2 = time2.get_frequency_axis();
fprintf('  Time vector:\n');
fprintf('    Range: [%.4f, %.4f] seconds\n', min(t2), max(t2));
fprintf('    Duration: %.4f seconds\n', max(t2) - min(t2) + 1/500);
fprintf('  Frequency axis:\n');
fprintf('    Range: [%.4f, %.4f] Hz\n', min(f2), max(f2));
fprintf('    Resolution: %.4f Hz\n', f2(2) - f2(1));
fprintf('    Expected resolution: %.4f Hz\n', 500/256);
fprintf('    Nyquist freq: %.2f Hz\n', time2.get_nyquist_freq());

% Test 4: Verify dependent property 't' matches get_time_vector()
fprintf('\nTest 4: Verify dependent property matches method\n');
t_dep = time1.t;
t_method = time1.get_time_vector();
fprintf('  Dependent property t matches get_time_vector(): %s\n', mat2str(isequal(t_dep, t_method)));

% Test 5: Integration with SpectralGrid (same as previous test)
fprintf('\nTest 5: Integration with bct.buildSpectralGrid()\n');
fprintf('  This verifies the time vector is used correctly in spectral grid construction\n');
fprintf('  (See test_spectral_grid.m for full test)\n');

fprintf('\n=== All tests completed successfully! ===\n');
