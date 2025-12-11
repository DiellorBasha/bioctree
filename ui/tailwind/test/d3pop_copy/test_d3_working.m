% Test if the working population pyramid example works
clear all
close all

fprintf('Testing population pyramid example...\n');
try
    % Change to the correct directory
    cd('ui/tailwind/test/d3pop_copy');
    
    % Run the working example
    d3_population_pyramid_mat;
    
    fprintf('\nIf the population pyramid appears, then D3 is working.\n');
    fprintf('If it does not appear, there is a MATLAB/D3 compatibility issue.\n');
catch ME
    fprintf('ERROR: %s\n', ME.message);
end
