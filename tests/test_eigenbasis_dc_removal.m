%% Test eigenbasis DC component removal behavior
%
% This script tests the RemoveDC parameter in computeEigenbasis to verify:
%   1. By default, all requested modes are kept (including DC)
%   2. With RemoveDC=true, DC is removed and you get N-1 modes
%   3. The DC mode is the one with smallest absolute eigenvalue

clear; close all; clc;

fprintf('=== Testing Eigenbasis DC Removal ===\n\n');

%% Load test mesh
fprintf('Loading test mesh...\n');
B = bct_fsaverage('lh');
fprintf('  Manifold: %d vertices\n\n', B.Manifold.N);

%% Test 1: Default behavior (RemoveDC = false, keep all modes)
fprintf('Test 1: Default behavior (RemoveDC = false)\n');
fprintf('  Requesting 50 eigenmodes...\n');

B1 = B;
B1 = B1.computeEigenbasis('K', 50);

fprintf('  Result: Got %d modes\n', B1.Lambda.K);
fprintf('  Min eigenvalue: %.6e\n', min(B1.Lambda.lambda));
fprintf('  Max eigenvalue: %.6f\n', max(B1.Lambda.lambda));

assert(B1.Lambda.K == 50, 'Should get exactly 50 modes when RemoveDC=false');
fprintf('  ✓ PASS: Got all 50 requested modes\n\n');

%% Test 2: With RemoveDC = true (remove DC component)
fprintf('Test 2: With RemoveDC = true\n');
fprintf('  Requesting 50 eigenmodes with DC removal...\n');

B2 = B;
B2 = B2.computeEigenbasis('K', 50, 'RemoveDC', true);

fprintf('  Result: Got %d modes\n', B2.Lambda.K);
fprintf('  Min eigenvalue: %.6e\n', min(B2.Lambda.lambda));
fprintf('  Max eigenvalue: %.6f\n', max(B2.Lambda.lambda));

assert(B2.Lambda.K == 49, 'Should get 49 modes when RemoveDC=true (50 - 1 DC)');
fprintf('  ✓ PASS: Got 49 modes (DC component removed)\n\n');

%% Test 3: Verify DC is the smallest eigenvalue
fprintf('Test 3: Verify DC component identification\n');

% The smallest eigenvalue in B1 should be very close to zero (DC component)
dc_eigenvalue = min(abs(B1.Lambda.lambda));
fprintf('  Smallest eigenvalue magnitude: %.6e\n', dc_eigenvalue);

% It should be much smaller than the second-smallest
[sorted_lambda, ~] = sort(abs(B1.Lambda.lambda));
second_smallest = sorted_lambda(2);
fprintf('  Second smallest magnitude: %.6e\n', second_smallest);
fprintf('  Ratio (DC/second): %.6e\n', dc_eigenvalue / second_smallest);

assert(dc_eigenvalue < 1e-6, 'DC eigenvalue should be near zero');
assert(dc_eigenvalue / second_smallest < 0.1, 'DC should be much smaller than other modes');
fprintf('  ✓ PASS: DC component correctly identified as smallest eigenvalue\n\n');

%% Test 4: Compare eigenvalue spectra
fprintf('Test 4: Compare eigenvalue spectra\n');

% With DC removed, the smallest eigenvalue should match the second-smallest from full set
lambda_with_dc = sort(B1.Lambda.lambda, 'ascend');
lambda_without_dc = sort(B2.Lambda.lambda, 'ascend');

% The first eigenvalue of B2 should match the second of B1
tolerance = 1e-10;
difference = abs(lambda_without_dc(1) - lambda_with_dc(2));
fprintf('  First eigenvalue (no DC): %.6f\n', lambda_without_dc(1));
fprintf('  Second eigenvalue (with DC): %.6f\n', lambda_with_dc(2));
fprintf('  Difference: %.6e\n', difference);

assert(difference < tolerance, 'Eigenvalues should match after DC removal');
fprintf('  ✓ PASS: Eigenvalue spectra match correctly\n\n');

%% Summary
fprintf('========================================\n');
fprintf('✅ ALL DC REMOVAL TESTS PASSED!\n');
fprintf('========================================\n\n');

fprintf('Summary:\n');
fprintf('  • Default behavior: Keep all requested modes (including DC)\n');
fprintf('  • RemoveDC=false: Returns exactly K modes as requested\n');
fprintf('  • RemoveDC=true: Returns K-1 modes (DC removed)\n');
fprintf('  • DC component is correctly identified as smallest eigenvalue\n\n');
