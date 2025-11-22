% test_filter_architecture.m
% Test script for new filter architecture
%
% Tests:
% 1. Kernel functions work correctly
% 2. Filter creation on different domains
% 3. Parameter updates (direct property access)
% 4. FilterDesigner factory methods
% 5. FilterBank management
% 6. Event listeners for parameter changes

%% Setup
fprintf('=== Testing New Filter Architecture ===\n\n');

% Create BCT object with mesh using factory method
[x, y] = meshgrid(linspace(0, 1, 20));
V = [x(:), y(:), zeros(400, 1)];
F = delaunay(x(:), y(:));
B = bct.bct.fromMesh(V, F);  % Use factory method - auto-creates Lambda

% Lambda is automatically created as dual of Manifold with estimated eigenvalue axis

% Set up time domain
B.Time = bct.Time(linspace(0, 1, 100), 100);
B.Omega = B.Time.dual;

%% Test 1: Kernel Functions
fprintf('Test 1: Kernel Functions\n');
fprintf('-------------------------\n');

% Test temporal Gaussian kernel
gauss_kernel = bct.filters.kernels.gaussian();
x_test = linspace(0, 20, 100);
H_gauss = gauss_kernel(x_test, 10, 2);
assert(max(H_gauss) <= 1, 'Gaussian kernel max should be <= 1');
[~, max_idx] = max(H_gauss);
assert(abs(x_test(max_idx) - 10) < 0.5, 'Gaussian peak should be near center');
fprintf('  ✓ Gaussian kernel works correctly\n');

% Test spatial heat kernel
heat_kernel = bct.filters.kernels.heat();
lambda_test = linspace(0, 100, 50);
H_heat = heat_kernel(lambda_test, 0.1);
assert(all(H_heat >= 0 & H_heat <= 1), 'Heat kernel should be in [0,1]');
assert(H_heat(1) > H_heat(end), 'Heat kernel should decay');
fprintf('  ✓ Heat kernel works correctly\n');

% Test joint Gabor kernel
gabor_kernel = bct.filters.kernels.gabor();
[X, Y] = meshgrid(linspace(0, 10, 20), linspace(0, 20, 30));
H_gabor = gabor_kernel(X, Y, 5, 10, 1, 2);
assert(all(H_gabor(:) >= 0 & H_gabor(:) <= 1), 'Gabor should be in [0,1]');
fprintf('  ✓ Gabor kernel works correctly\n\n');

%% Test 2: Filter Creation on Different Domains
fprintf('Test 2: Filter Creation on Different Domains\n');
fprintf('---------------------------------------------\n');

% Test temporal filter
filt_temporal = bct.filters.Filter(B.Omega, 'gaussian', ...
    'center', 10, 'sigma', 2, 'label', 'alpha');
assert(isa(filt_temporal, 'bct.filters.Filter'), 'Should create Filter object');
assert(strcmp(filt_temporal.Label, 'alpha'), 'Label should match');
H_temp = filt_temporal.evaluate();
assert(~isempty(H_temp), 'Should evaluate filter');
fprintf('  ✓ Created temporal filter on Omega domain\n');

% Test spatial filter
filt_spatial = bct.filters.Filter(B.Lambda, 'heat', ...
    'tau', 0.1, 'label', 'lowpass');
H_spat = filt_spatial.evaluate();
assert(~isempty(H_spat), 'Should evaluate spatial filter');
fprintf('  ✓ Created spatial filter on Lambda domain\n');

% Test joint filter
B.createJoint('Lambda', 'Omega');  % Creates B.Joint
filt_joint = bct.filters.Filter(B.Joint, 'gabor', ...
    'center_x', 5, 'center_y', 10, ...
    'sigma_x', 1, 'sigma_x', 2);
H_joint = filt_joint.evaluate();
joint_size = B.Joint.size();
assert(size(H_joint, 1) == joint_size(1), 'Joint filter size should match grid');
assert(size(H_joint, 2) == joint_size(2), 'Joint filter size should match grid');
fprintf('  ✓ Created joint filter on Joint domain\n\n');

%% Test 3: Parameter Updates
fprintf('Test 3: Direct Parameter Updates\n');
fprintf('---------------------------------\n');

% Create filter
filt = bct.filters.Filter(B.Omega, 'gaussian', ...
    'center', 10, 'sigma', 2);

% Test direct property access
initial_center = filt.center;
initial_sigma = filt.sigma;
assert(initial_center == 10, 'Initial center should be 10');
assert(initial_sigma == 2, 'Initial sigma should be 2');
fprintf('  ✓ Can read parameter values via properties\n');

% Update center
filt.center = 15;
assert(filt.center == 15, 'Center should update to 15');
assert(filt.Parameters.center == 15, 'Parameters struct should update');
fprintf('  ✓ Can update center via property assignment\n');

% Update sigma
filt.sigma = 3;
assert(filt.sigma == 3, 'Sigma should update to 3');
fprintf('  ✓ Can update sigma via property assignment\n');

% Test setParameter method
filt.setParameter('center', 12);
assert(filt.center == 12, 'setParameter should work');
fprintf('  ✓ setParameter() method works\n');

% Test setParameters (batch update)
filt.setParameters('center', 8, 'sigma', 1.5);
assert(filt.center == 8, 'Batch update center works');
assert(filt.sigma == 1.5, 'Batch update sigma works');
fprintf('  ✓ setParameters() batch update works\n\n');

%% Test 4: Event Listeners
fprintf('Test 4: Event Listeners\n');
fprintf('-----------------------\n');

% Create filter and get initial response
filt_event = bct.filters.Filter(B.Omega, 'gaussian', ...
    'center', 10, 'sigma', 2);
H_before = filt_event.Response;

% Update parameter - should trigger event and invalidate cache
filt_event.center = 12;
H_after = filt_event.Response;

% Response should be different after parameter change
assert(~isequal(H_before, H_after), 'Response should change when parameters change');
fprintf('  ✓ ParametersChanged event system working (cache invalidation verified)\n\n');

%% Test 5: FilterDesigner
fprintf('Test 5: FilterDesigner Factory\n');
fprintf('------------------------------\n');

designer = bct.filters.FilterDesigner(B);

% Test temporal filter creation
f1 = designer.temporal('gaussian', 'center', 10, 'sigma', 2, 'label', 'alpha');
assert(isa(f1, 'bct.filters.Filter'), 'Should create Filter');
assert(isa(f1.Domain, 'bct.Omega'), 'Should use Omega domain');
fprintf('  ✓ designer.temporal() works\n');

% Test spatial filter creation
f2 = designer.spatial('heat', 'tau', 0.1, 'label', 'heat_filter');
assert(isa(f2.Domain, 'bct.Lambda'), 'Should use Lambda domain');
fprintf('  ✓ designer.spatial() works\n');

% Test joint filter creation with auto-Joint
f3 = designer.joint('gabor', 'domains', {'Lambda', 'Omega'}, ...
    'center_x', 5, 'center_y', 10);
assert(isa(f3.Domain, 'bct.Joint'), 'Should create Joint domain');
fprintf('  ✓ designer.joint() with auto-Joint creation works\n\n');

%% Test 6: FilterBank
fprintf('Test 6: FilterBank Management\n');
fprintf('-----------------------------\n');

bank = bct.filters.FilterBank();

% Add filters
bank.add(designer.temporal('gaussian', 'center', 8, 'sigma', 1, 'label', 'theta'));
bank.add(designer.temporal('gaussian', 'center', 12, 'sigma', 1, 'label', 'alpha'));
bank.add(designer.temporal('gaussian', 'center', 30, 'sigma', 2, 'label', 'beta'));

assert(bank.length() == 3, 'Should have 3 filters');
fprintf('  ✓ Can add filters to bank\n');

% Get by index
f_idx = bank.get(1);
assert(strcmp(f_idx.Label, 'theta'), 'Get by index works');
fprintf('  ✓ Can get filter by index\n');

% Get by label
f_label = bank.get('alpha');
assert(f_label.center == 12, 'Get by label works');
fprintf('  ✓ Can get filter by label\n');

% Evaluate all
responses = bank.evaluateAll();
assert(length(responses) == 3, 'Should evaluate all filters');
fprintf('  ✓ Can evaluate all filters\n');

% Remove filter
bank.remove(2);
assert(bank.length() == 2, 'Should have 2 filters after removal');
fprintf('  ✓ Can remove filter\n\n');

%% Test 7: Cache Invalidation
fprintf('Test 7: Cache Invalidation\n');
fprintf('--------------------------\n');

filt_cache = bct.filters.Filter(B.Omega, 'gaussian', ...
    'center', 10, 'sigma', 2);

% Get initial response
H1 = filt_cache.Response;
assert(~isempty(H1), 'Should compute response');

% Change parameter - should invalidate cache
filt_cache.center = 15;
H2 = filt_cache.Response;
assert(~isequal(H1, H2), 'Response should change after parameter update');
fprintf('  ✓ Cache invalidation works correctly\n\n');

%% Summary
fprintf('=== All Tests Passed! ===\n');
fprintf('Filter architecture is working correctly.\n');
fprintf('\nKey Features Verified:\n');
fprintf('  • Kernel functions (gaussian, heat, gabor)\n');
fprintf('  • Filter creation on all domain types\n');
fprintf('  • Direct parameter updates (filt.center = val)\n');
fprintf('  • Event system (ParametersChanged)\n');
fprintf('  • FilterDesigner factory methods\n');
fprintf('  • FilterBank collection management\n');
fprintf('  • Automatic cache invalidation\n');

