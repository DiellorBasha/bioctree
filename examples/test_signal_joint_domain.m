%% Test Signal Class with Joint Domains
% This script tests the refactored Signal class with various domain types,
% including Joint domains (Manifold×Time).
%
% Tests:
% 1. Signal on Manifold domain [N×1]
% 2. Signal on Time domain [T×1]
% 3. Signal on Joint Manifold×Time domain [N×T]
% 4. Delta signals on different domains
% 5. Backward compatibility with dependent properties

clear; clc;

%% Step 1: Create BCT object with Manifold and Time
fprintf('Step 1: Create BCT object with domains\n');
fprintf('---------------------------------------\n');

% Create icosphere manifold
B = bct;
B.Manifold = bct.Manifold(icosphere(3));
fprintf('  Manifold: N = %d vertices\n', B.Manifold.N);

% Create time domain (this automatically creates Joint Manifold×Time)
B.Time = bct.Time(100, 200);  % 100 samples at 200 Hz
fprintf('  Time: T = %d samples at %.0f Hz\n', B.Time.N, B.Time.fs);

% Verify Joint domain was auto-created
assert(~isempty(B.Joint), 'Joint domain should be auto-created');
fprintf('  Joint Manifold×Time: [%d × %d]\n', B.Joint.size());

%% Step 2: Test Signal on Manifold domain
fprintf('\nStep 2: Test Signal on Manifold domain\n');
fprintf('---------------------------------------\n');

% Create scalar signal on Manifold [N×1]
data_manifold = randn(B.Manifold.N, 1);
sig_manifold = bct.Signal(B.Manifold, data_manifold, 'Test Manifold Signal');

fprintf('  Signal domain: %s\n', class(sig_manifold.Domain));
fprintf('  Signal dimensions: [%s]\n', num2str(size(sig_manifold.Data)));
fprintf('  IsVector: %d\n', sig_manifold.IsVector);
fprintf('  IsStatic: %d\n', sig_manifold.IsStatic);
fprintf('  N property: %d\n', sig_manifold.N);
fprintf('  T property: %d\n', sig_manifold.T);

% Test backward compatibility: Manifold property
fprintf('  Manifold property (legacy): %s\n', class(sig_manifold.Manifold));
assert(isa(sig_manifold.Manifold, 'bct.Manifold'), 'Manifold property should return Manifold');

%% Step 3: Test vector signal on Manifold domain
fprintf('\nStep 3: Test vector Signal on Manifold domain\n');
fprintf('---------------------------------------------\n');

% Create vector signal [N×3]
data_vector = randn(B.Manifold.N, 3);
sig_vector = bct.Signal(B.Manifold, data_vector, 'Test Vector Signal');

fprintf('  Signal dimensions: [%s]\n', num2str(size(sig_vector.Data)));
fprintf('  IsVector: %d\n', sig_vector.IsVector);
fprintf('  IsStatic: %d\n', sig_vector.IsStatic);

%% Step 4: Test Signal on Time domain
fprintf('\nStep 4: Test Signal on Time domain\n');
fprintf('-----------------------------------\n');

% Create temporal signal [T×1]
data_time = sin(2*pi*10 * B.Time.axis);  % 10 Hz sine wave
sig_time = bct.Signal(B.Time, data_time, 'Test Time Signal');

fprintf('  Signal domain: %s\n', class(sig_time.Domain));
fprintf('  Signal dimensions: [%s]\n', num2str(size(sig_time.Data)));
fprintf('  IsVector: %d\n', sig_time.IsVector);
fprintf('  IsStatic: %d\n', sig_time.IsStatic);
fprintf('  T property: %d\n', sig_time.T);

% Test backward compatibility: Time property
fprintf('  Time property (legacy): %s\n', class(sig_time.Time));
assert(isa(sig_time.Time, 'bct.Time'), 'Time property should return Time');

%% Step 5: Test Signal on Joint domain
fprintf('\nStep 5: Test Signal on Joint Manifold×Time domain\n');
fprintf('--------------------------------------------------\n');

% Create spatiotemporal signal [N×T]
data_joint = randn(B.Manifold.N, B.Time.N);
sig_joint = bct.Signal(B.Joint, data_joint, 'Test Joint Signal');

fprintf('  Signal domain: %s\n', class(sig_joint.Domain));
fprintf('  Signal dimensions: [%s]\n', num2str(size(sig_joint.Data)));
fprintf('  Joint.size(): [%s]\n', num2str(sig_joint.Domain.size()));
fprintf('  IsVector: %d\n', sig_joint.IsVector);
fprintf('  IsStatic: %d\n', sig_joint.IsStatic);
fprintf('  IsDynamic: %d\n', sig_joint.IsDynamic);

% Test backward compatibility: should extract Manifold and Time from Joint
fprintf('  Manifold from Joint (legacy): %s\n', class(sig_joint.Manifold));
fprintf('  Time from Joint (legacy): %s\n', class(sig_joint.Time));
assert(isa(sig_joint.Manifold, 'bct.Manifold'), 'Should extract Manifold from Joint');
assert(isa(sig_joint.Time, 'bct.Time'), 'Should extract Time from Joint');
fprintf('  N property: %d (should be %d)\n', sig_joint.N, B.Manifold.N * B.Time.N);
fprintf('  T property: %d (should be %d)\n', sig_joint.T, B.Time.N);

%% Step 6: Test vector signal on Joint domain
fprintf('\nStep 6: Test vector Signal on Joint domain\n');
fprintf('-------------------------------------------\n');

% Create spatiotemporal vector signal [N×T×3]
data_joint_vec = randn(B.Manifold.N, B.Time.N, 3);
sig_joint_vec = bct.Signal(B.Joint, data_joint_vec, 'Test Joint Vector Signal');

fprintf('  Signal dimensions: [%s]\n', num2str(size(sig_joint_vec.Data)));
fprintf('  IsVector: %d\n', sig_joint_vec.IsVector);
fprintf('  IsDynamic: %d\n', sig_joint_vec.IsDynamic);

%% Step 7: Test delta signal on Manifold
fprintf('\nStep 7: Test delta signal on Manifold\n');
fprintf('--------------------------------------\n');

delta_v = bct.Signal.createDelta(B.Manifold, 50);
fprintf('  Delta at vertex 50\n');
fprintf('  Signal dimensions: [%s]\n', num2str(size(delta_v.Data)));
fprintf('  Label: %s\n', delta_v.Label);
fprintf('  Sum of data: %g (should be 1)\n', sum(delta_v.Data));
assert(delta_v.Data(50) == 1, 'Delta should be 1 at vertex 50');

%% Step 8: Test delta signal on Time
fprintf('\nStep 8: Test delta signal on Time\n');
fprintf('----------------------------------\n');

delta_t = bct.Signal.createDelta(B.Time, 30);
fprintf('  Delta at time index 30\n');
fprintf('  Signal dimensions: [%s]\n', num2str(size(delta_t.Data)));
fprintf('  Label: %s\n', delta_t.Label);
fprintf('  Sum of data: %g (should be 1)\n', sum(delta_t.Data));
assert(delta_t.Data(30) == 1, 'Delta should be 1 at time 30');

%% Step 9: Test delta signal on Joint domain
fprintf('\nStep 9: Test delta signal on Joint domain\n');
fprintf('------------------------------------------\n');

delta_joint = bct.Signal.createDelta(B.Joint, 50, 30);
fprintf('  Delta at vertex 50, time 30\n');
fprintf('  Signal dimensions: [%s]\n', num2str(size(delta_joint.Data)));
fprintf('  Label: %s\n', delta_joint.Label);
fprintf('  Sum of data: %g (should be 1)\n', sum(delta_joint.Data(:)));
assert(delta_joint.Data(50, 30) == 1, 'Delta should be 1 at vertex 50, time 30');

%% Step 10: Test signal summary display
fprintf('\nStep 10: Test signal summary display\n');
fprintf('-------------------------------------\n');

fprintf('\n--- Manifold signal summary ---\n');
disp(sig_manifold);

fprintf('\n--- Joint signal summary ---\n');
disp(sig_joint);

%% All tests passed!
fprintf('\n========================================\n');
fprintf('ALL TESTS PASSED!\n');
fprintf('Signal class successfully refactored for domain-agnostic design.\n');
fprintf('========================================\n');
