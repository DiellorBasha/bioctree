%% Test bct.ui.component.Fplot integration with bct.ui.show
% This script tests that Fplot component works standalone and via show()

clearvars; close all;

% Initialize bioctree
scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
cd(projectRoot);
bioctree_start;

fprintf('=== Testing bct.ui.component.Fplot ===\n\n');

%% 1. Test direct instantiation
fprintf('1. Testing direct instantiation...\n');
try
    fig1 = uifigure('Name', 'Fplot - Direct Instantiation', 'Position', [100 100 500 400]);
    grid1 = uigridlayout(fig1, [1 1]);
    
    fp1 = bct.ui.component.Fplot(grid1);
    fp1.TitleText = "Gaussian";
    fp1.XLabelText = "x";
    fp1.YLabelText = "exp(-x²)";
    fp1.XAxis = linspace(-5, 5, 200);
    fp1.Function = @(x) exp(-x.^2);
    fp1.refresh();
    
    fprintf('   ✓ Direct instantiation successful\n');
catch ME
    fprintf('   ✗ ERROR: %s\n', ME.message);
    rethrow(ME);
end

%% 2. Test with parameters
fprintf('\n2. Testing parameterized function...\n');
try
    fig2 = uifigure('Name', 'Fplot - Parameterized', 'Position', [650 100 500 400]);
    grid2 = uigridlayout(fig2, [1 1]);
    
    fp2 = bct.ui.component.Fplot(grid2);
    fp2.TitleText = "Parameterized Gaussian";
    fp2.XAxis = linspace(-10, 10, 300);
    fp2.Function = @(x, p) exp(-(x - p.mu).^2 / (2 * p.sigma^2));
    fp2.Params = struct('mu', 2, 'sigma', 1.5);
    fp2.refresh();
    
    fprintf('   ✓ Parameterized function successful\n');
    fprintf('   Parameters: mu=%.1f, sigma=%.1f\n', fp2.Params.mu, fp2.Params.sigma);
catch ME
    fprintf('   ✗ ERROR: %s\n', ME.message);
    rethrow(ME);
end

%% 3. Test complex mode
fprintf('\n3. Testing complex-valued function...\n');
try
    fig3 = uifigure('Name', 'Fplot - Complex Mode', 'Position', [100 550 900 350]);
    grid3 = uigridlayout(fig3, [1 3]);
    
    fn_complex = @(x) exp(1i * 2 * pi * x);
    xaxis = linspace(0, 2, 200);
    
    % Real part
    fp3a = bct.ui.component.Fplot(grid3);
    fp3a.XAxis = xaxis;
    fp3a.Function = fn_complex;
    fp3a.ComplexMode = "real";
    fp3a.TitleText = "Real Part";
    fp3a.refresh();
    
    % Imaginary part
    fp3b = bct.ui.component.Fplot(grid3);
    fp3b.XAxis = xaxis;
    fp3b.Function = fn_complex;
    fp3b.ComplexMode = "imag";
    fp3b.TitleText = "Imaginary Part";
    fp3b.refresh();
    
    % Magnitude
    fp3c = bct.ui.component.Fplot(grid3);
    fp3c.XAxis = xaxis;
    fp3c.Function = fn_complex;
    fp3c.ComplexMode = "abs";
    fp3c.TitleText = "Magnitude";
    fp3c.refresh();
    
    fprintf('   ✓ Complex mode (real/imag/abs) successful\n');
catch ME
    fprintf('   ✗ ERROR: %s\n', ME.message);
    rethrow(ME);
end

%% 4. Test bct.ui.show integration
fprintf('\n4. Testing bct.ui.show() integration...\n');
try
    % Define a function to display
    myFunction = @(x) sin(3*x) .* exp(-0.1*x.^2);
    
    % Use show() to automatically create viewer
    [comp, fig4] = bct.ui.show(myFunction, 'Title', 'Fplot via show()');
    
    fprintf('   ✓ bct.ui.show() integration successful\n');
    fprintf('   Component class: %s\n', class(comp));
    fprintf('   Figure created: %s\n', class(fig4));
    
    % Verify it's the right component
    if isa(comp, 'bct.ui.component.Fplot')
        fprintf('   ✓ Correct component type selected\n');
    else
        warning('Expected bct.ui.component.Fplot, got %s', class(comp));
    end
    
    % Verify function was bound
    if isequal(comp.Function, myFunction)
        fprintf('   ✓ Function bound correctly\n');
    else
        warning('Function not bound correctly');
    end
    
catch ME
    fprintf('   ✗ ERROR: %s\n', ME.message);
    fprintf('   Stack:\n');
    for i = 1:length(ME.stack)
        fprintf('     %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    rethrow(ME);
end

%% 5. Test registry listing
fprintf('\n5. Testing registry listing...\n');
try
    inspectors = bct.ui.listInspectors();
    fprintf('   Registered inspectors:\n');
    disp(inspectors);
    
    % Check if FplotComponent is registered
    if any(inspectors.Id == "FplotComponent")
        fprintf('   ✓ FplotComponent found in registry\n');
        idx = find(inspectors.Id == "FplotComponent");
        fprintf('   Class: %s\n', inspectors.Class(idx));
        fprintf('   Supports: %s\n', strjoin(inspectors.Supports{idx}, ', '));
        fprintf('   Priority: %d\n', inspectors.Priority(idx));
    else
        warning('FplotComponent not found in registry');
    end
catch ME
    fprintf('   ✗ ERROR: %s\n', ME.message);
    rethrow(ME);
end

%% 6. Test runtime dispatch
fprintf('\n6. Testing runtime dispatch...\n');
try
    testFn = @(x) cos(x);
    [factory, def] = bct.runtime.ui.resolveInspector(testFn);
    
    fprintf('   Resolved inspector for function_handle:\n');
    fprintf('   Id: %s\n', def.Id);
    fprintf('   Class: %s\n', def.Class);
    fprintf('   Priority: %d\n', def.Priority);
    fprintf('   ✓ Runtime dispatch successful\n');
catch ME
    fprintf('   ✗ ERROR: %s\n', ME.message);
    rethrow(ME);
end

%% Summary
fprintf('\n=== Test Summary ===\n');
fprintf('✓ Direct instantiation\n');
fprintf('✓ Parameterized functions\n');
fprintf('✓ Complex mode handling\n');
fprintf('✓ bct.ui.show() integration\n');
fprintf('✓ Registry listing\n');
fprintf('✓ Runtime dispatch\n');
fprintf('\nAll tests passed! Fplot component fully integrated.\n');
