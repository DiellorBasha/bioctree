function demo_bunny_dgw()
% DEMO_BUNNY_DGW Dynamic Graph Wavelets on Stanford bunny with MEG data
%
% This demo showcases Dynamic Graph Wavelets (DGW) with different kernels:
%   - Heat kernel DGW (diffusion-based)
%   - Wave kernel DGW (oscillatory)
%   - Causal damped kernel DGW (exponential decay)
%   - Custom kernel DGW (user-defined)
%
% DGW provides localized analysis in both graph and time domains,
% capturing propagation phenomena and local dynamics.

fprintf('=== Bioctree DGW Demo: Stanford Bunny ===\n\n');

%% 1. Setup and Data Loading
fprintf('1. Loading data and preparing DGW analysis...\n');

[G, X, fs, t] = load_bunny_data();
fprintf('   Graph: %d vertices, %d edges\n', G.N, G.Ne);
fprintf('   Signal: %d samples at %.1f Hz\n', length(t), fs);

% Select analysis vertices (for computational efficiency)
n_analysis_vertices = min(50, G.N);
rng(123);  % Reproducible selection
analysis_vertices = sort(randperm(G.N, n_analysis_vertices));

fprintf('   Selected %d vertices for DGW analysis\n', n_analysis_vertices);

%% 2. Heat Kernel DGW
fprintf('\n2. Heat kernel DGW (diffusion-based)...\n');

% Heat kernel parameters
heat_scales = [0.5, 1.0, 2.0, 4.0];  % Diffusion time scales
n_scales = length(heat_scales);

fprintf('   Heat scales: %s\n', mat2str(heat_scales));

% Compute heat kernel DGW
DGW_heat = cell(n_analysis_vertices, n_scales);
heat_coefficients = zeros(n_analysis_vertices, n_scales, length(t));

for v_idx = 1:n_analysis_vertices
    vertex = analysis_vertices(v_idx);
    
    for s = 1:n_scales
        scale = heat_scales(s);
        
        % Heat kernel: K(λ) = exp(-scale * λ)
        heat_kernel = @(x) exp(-scale * x);
        
        % Create localized heat kernel centered at vertex
        impulse = zeros(G.N, 1);
        impulse(vertex) = 1;
        
        % Heat diffusion from vertex
        heat_response = gsp_filter(G, heat_kernel, impulse);
        
        % Compute DGW coefficients for this vertex and scale
        dgw_coeffs = zeros(1, length(t));
        for t_idx = 1:length(t)
            signal_t = X(:, t_idx);
            dgw_coeffs(t_idx) = heat_response' * signal_t;
        end
        
        DGW_heat{v_idx, s} = heat_response;
        heat_coefficients(v_idx, s, :) = dgw_coeffs;
    end
    
    if mod(v_idx, 10) == 0
        fprintf('   Processed %d/%d vertices\n', v_idx, n_analysis_vertices);
    end
end

fprintf('   Heat kernel DGW completed\n');

%% 3. Wave Kernel DGW
fprintf('\n3. Wave kernel DGW (oscillatory)...\n');

% Wave kernel parameters
wave_frequencies = [0.2, 0.5, 1.0, 2.0];  % Oscillation frequencies
wave_damping = 0.1;  % Damping factor

fprintf('   Wave frequencies: %s, damping: %.2f\n', ...
        mat2str(wave_frequencies), wave_damping);

% Compute wave kernel DGW
DGW_wave = cell(n_analysis_vertices, length(wave_frequencies));
wave_coefficients = zeros(n_analysis_vertices, length(wave_frequencies), length(t));

for v_idx = 1:n_analysis_vertices
    vertex = analysis_vertices(v_idx);
    
    for f = 1:length(wave_frequencies)
        freq = wave_frequencies(f);
        
        % Wave kernel: K(λ) = cos(freq * sqrt(λ)) * exp(-damping * λ)
        wave_kernel = @(x) cos(freq * sqrt(x)) .* exp(-wave_damping * x);
        
        % Create localized wave kernel
        impulse = zeros(G.N, 1);
        impulse(vertex) = 1;
        
        % Wave propagation from vertex
        wave_response = gsp_filter(G, wave_kernel, impulse);
        
        % Compute DGW coefficients
        dgw_coeffs = zeros(1, length(t));
        for t_idx = 1:length(t)
            signal_t = X(:, t_idx);
            dgw_coeffs(t_idx) = wave_response' * signal_t;
        end
        
        DGW_wave{v_idx, f} = wave_response;
        wave_coefficients(v_idx, f, :) = dgw_coeffs;
    end
end

fprintf('   Wave kernel DGW completed\n');

%% 4. Causal Damped Kernel DGW
fprintf('\n4. Causal damped kernel DGW...\n');

% Causal damped parameters
damping_rates = [0.5, 1.0, 2.0, 4.0];  % Exponential decay rates
delay_samples = 5;  % Causal delay

fprintf('   Damping rates: %s, delay: %d samples\n', ...
        mat2str(damping_rates), delay_samples);

% Compute causal DGW using temporal convolution
DGW_causal = cell(n_analysis_vertices, length(damping_rates));
causal_coefficients = zeros(n_analysis_vertices, length(damping_rates), length(t));

for v_idx = 1:n_analysis_vertices
    vertex = analysis_vertices(v_idx);
    
    for d = 1:length(damping_rates)
        damping = damping_rates(d);
        
        % Causal kernel in graph domain
        causal_kernel = @(x) exp(-damping * x);
        
        % Create spatial filter
        impulse = zeros(G.N, 1);
        impulse(vertex) = 1;
        spatial_filter = gsp_filter(G, causal_kernel, impulse);
        
        % Apply causal temporal filtering
        vertex_signal = X(vertex, :);
        
        % Causal exponential filter
        causal_temporal_filter = zeros(1, length(t));
        for lag = 1:min(delay_samples*3, length(t))
            if lag <= length(t)
                causal_temporal_filter(lag) = exp(-damping * (lag-1) / fs);
            end
        end
        causal_temporal_filter = causal_temporal_filter / sum(causal_temporal_filter);
        
        % Apply causal convolution
        dgw_coeffs = zeros(1, length(t));
        for t_idx = delay_samples:length(t)
            % Spatial filtering
            signal_t = X(:, t_idx);
            spatial_response = spatial_filter' * signal_t;
            
            % Temporal causal integration
            temporal_weights = causal_temporal_filter(1:min(t_idx, length(causal_temporal_filter)));
            past_samples = t_idx-length(temporal_weights)+1:t_idx;
            past_values = vertex_signal(past_samples);
            
            dgw_coeffs(t_idx) = spatial_response * sum(temporal_weights .* past_values);
        end
        
        DGW_causal{v_idx, d} = spatial_filter;
        causal_coefficients(v_idx, d, :) = dgw_coeffs;
    end
end

fprintf('   Causal damped DGW completed\n');

%% 5. Custom Kernel DGW (Mexican Hat)
fprintf('\n5. Custom kernel DGW (Mexican Hat)...\n');

% Mexican hat parameters
hat_widths = [1.0, 2.0, 3.0];  % Kernel widths

fprintf('   Mexican hat widths: %s\n', mat2str(hat_widths));

% Compute Mexican hat DGW
DGW_mexhat = cell(n_analysis_vertices, length(hat_widths));
mexhat_coefficients = zeros(n_analysis_vertices, length(hat_widths), length(t));

for v_idx = 1:n_analysis_vertices
    vertex = analysis_vertices(v_idx);
    
    for w = 1:length(hat_widths)
        width = hat_widths(w);
        
        % Mexican hat kernel: K(λ) = (1 - λ/width) * exp(-λ/(2*width))
        mexhat_kernel = @(x) (1 - x/width) .* exp(-x/(2*width));
        
        % Create localized Mexican hat
        impulse = zeros(G.N, 1);
        impulse(vertex) = 1;
        mexhat_response = gsp_filter(G, mexhat_kernel, impulse);
        
        % Compute DGW coefficients
        dgw_coeffs = zeros(1, length(t));
        for t_idx = 1:length(t)
            signal_t = X(:, t_idx);
            dgw_coeffs(t_idx) = mexhat_response' * signal_t;
        end
        
        DGW_mexhat{v_idx, w} = mexhat_response;
        mexhat_coefficients(v_idx, w, :) = dgw_coeffs;
    end
end

fprintf('   Mexican hat DGW completed\n');

%% 6. DGW Analysis and Comparison
fprintf('\n6. DGW analysis and comparison...\n');

% Compute energy distributions
heat_energy = squeeze(sum(abs(heat_coefficients).^2, 3));
wave_energy = squeeze(sum(abs(wave_coefficients).^2, 3));
causal_energy = squeeze(sum(abs(causal_coefficients).^2, 3));
mexhat_energy = squeeze(sum(abs(mexhat_coefficients).^2, 3));

% Find most active vertices for each kernel type
[~, most_active_heat] = max(sum(heat_energy, 2));
[~, most_active_wave] = max(sum(wave_energy, 2));
[~, most_active_causal] = max(sum(causal_energy, 2));
[~, most_active_mexhat] = max(sum(mexhat_energy, 2));

fprintf('   Most active vertices:\n');
fprintf('     Heat kernel: vertex %d (index %d)\n', ...
        analysis_vertices(most_active_heat), most_active_heat);
fprintf('     Wave kernel: vertex %d (index %d)\n', ...
        analysis_vertices(most_active_wave), most_active_wave);
fprintf('     Causal kernel: vertex %d (index %d)\n', ...
        analysis_vertices(most_active_causal), most_active_causal);
fprintf('     Mexican hat: vertex %d (index %d)\n', ...
        analysis_vertices(most_active_mexhat), most_active_mexhat);

% Temporal dynamics analysis
heat_dynamics = squeeze(std(heat_coefficients, [], 3));
wave_dynamics = squeeze(std(wave_coefficients, [], 3));
causal_dynamics = squeeze(std(causal_coefficients, [], 3));

fprintf('   Temporal variability:\n');
fprintf('     Heat kernel: %.2e ± %.2e\n', mean(heat_dynamics(:)), std(heat_dynamics(:)));
fprintf('     Wave kernel: %.2e ± %.2e\n', mean(wave_dynamics(:)), std(wave_dynamics(:)));
fprintf('     Causal kernel: %.2e ± %.2e\n', mean(causal_dynamics(:)), std(causal_dynamics(:)));

%% 7. Visualization
fprintf('\n7. Creating DGW visualizations...\n');

figure('Name', 'Bioctree DGW Demo', 'Position', [50, 50, 1800, 1200]);

% Select representative vertex for detailed analysis
repr_vertex_idx = most_active_heat;
repr_vertex = analysis_vertices(repr_vertex_idx);

% Plot 1: Heat kernel spatial responses
subplot(3, 5, 1);
gsp_plot_graph(G, DGW_heat{repr_vertex_idx, 2});  % Medium scale
title(sprintf('Heat Kernel (v=%d)', repr_vertex));
colorbar;
view(45, 30);

% Plot 2: Wave kernel spatial responses  
subplot(3, 5, 2);
gsp_plot_graph(G, DGW_wave{repr_vertex_idx, 2});  % Medium frequency
title(sprintf('Wave Kernel (v=%d)', repr_vertex));
colorbar;
view(45, 30);

% Plot 3: Causal kernel spatial responses
subplot(3, 5, 3);
gsp_plot_graph(G, DGW_causal{repr_vertex_idx, 2});  % Medium damping
title(sprintf('Causal Kernel (v=%d)', repr_vertex));
colorbar;
view(45, 30);

% Plot 4: Mexican hat spatial responses
subplot(3, 5, 4);
gsp_plot_graph(G, DGW_mexhat{repr_vertex_idx, 2});  % Medium width
title(sprintf('Mexican Hat (v=%d)', repr_vertex));
colorbar;
view(45, 30);

% Plot 5: Kernel comparison in spectral domain
subplot(3, 5, 5);
lambda_range = linspace(0, G.lmax, 100);
plot(lambda_range, exp(-heat_scales(2) * lambda_range), 'r-', 'LineWidth', 2, 'DisplayName', 'Heat');
hold on;
plot(lambda_range, cos(wave_frequencies(2) * sqrt(lambda_range)) .* exp(-wave_damping * lambda_range), ...
     'b-', 'LineWidth', 2, 'DisplayName', 'Wave');
plot(lambda_range, exp(-damping_rates(2) * lambda_range), 'g-', 'LineWidth', 2, 'DisplayName', 'Causal');
width = hat_widths(2);
plot(lambda_range, (1 - lambda_range/width) .* exp(-lambda_range/(2*width)), ...
     'm-', 'LineWidth', 2, 'DisplayName', 'Mexican Hat');
xlabel('Graph Eigenvalue λ');
ylabel('Kernel Response');
title('Kernel Functions');
legend('Location', 'best');
grid on;

% Plot 6-9: Temporal evolution for each kernel
subplot(3, 5, 6);
plot(t, squeeze(heat_coefficients(repr_vertex_idx, :, :)));
xlabel('Time (s)');
ylabel('DGW Coefficient');
title('Heat DGW Evolution');
legend(arrayfun(@(x) sprintf('τ=%.1f', x), heat_scales, 'UniformOutput', false), 'Location', 'best');
grid on;

subplot(3, 5, 7);
plot(t, squeeze(wave_coefficients(repr_vertex_idx, :, :)));
xlabel('Time (s)');
ylabel('DGW Coefficient');
title('Wave DGW Evolution');
legend(arrayfun(@(x) sprintf('f=%.1f', x), wave_frequencies, 'UniformOutput', false), 'Location', 'best');
grid on;

subplot(3, 5, 8);
plot(t, squeeze(causal_coefficients(repr_vertex_idx, :, :)));
xlabel('Time (s)');
ylabel('DGW Coefficient');
title('Causal DGW Evolution');
legend(arrayfun(@(x) sprintf('d=%.1f', x), damping_rates, 'UniformOutput', false), 'Location', 'best');
grid on;

subplot(3, 5, 9);
plot(t, squeeze(mexhat_coefficients(repr_vertex_idx, :, :)));
xlabel('Time (s)');
ylabel('DGW Coefficient');
title('Mexican Hat DGW Evolution');
legend(arrayfun(@(x) sprintf('w=%.1f', x), hat_widths, 'UniformOutput', false), 'Location', 'best');
grid on;

% Plot 10: Energy distribution across scales
subplot(3, 5, 10);
boxplot([heat_energy(:), wave_energy(:), causal_energy(:), mexhat_energy(:)], ...
        'Labels', {'Heat', 'Wave', 'Causal', 'MexHat'});
ylabel('DGW Energy');
title('Energy Distribution');
grid on;

% Plot 11-14: Scale-space analysis
subplot(3, 5, 11);
imagesc(t, 1:length(heat_scales), squeeze(heat_coefficients(repr_vertex_idx, :, :)));
xlabel('Time (s)');
ylabel('Scale Index');
title('Heat DGW Scale-Time');
colorbar;

subplot(3, 5, 12);
imagesc(t, 1:length(wave_frequencies), squeeze(wave_coefficients(repr_vertex_idx, :, :)));
xlabel('Time (s)');
ylabel('Frequency Index');
title('Wave DGW Freq-Time');
colorbar;

subplot(3, 5, 13);
imagesc(t, 1:length(damping_rates), squeeze(causal_coefficients(repr_vertex_idx, :, :)));
xlabel('Time (s)');
ylabel('Damping Index');
title('Causal DGW Scale-Time');
colorbar;

subplot(3, 5, 14);
% Cross-kernel correlation analysis
kernels = {'Heat', 'Wave', 'Causal', 'MexHat'};
coeffs_all = {squeeze(heat_coefficients(repr_vertex_idx, 2, :)), ...
              squeeze(wave_coefficients(repr_vertex_idx, 2, :)), ...
              squeeze(causal_coefficients(repr_vertex_idx, 2, :)), ...
              squeeze(mexhat_coefficients(repr_vertex_idx, 2, :))};

corr_matrix = zeros(4, 4);
for i = 1:4
    for j = 1:4
        corr_matrix(i, j) = corr(coeffs_all{i}, coeffs_all{j});
    end
end

imagesc(corr_matrix);
set(gca, 'XTick', 1:4, 'XTickLabel', kernels, 'YTick', 1:4, 'YTickLabel', kernels);
title('Kernel Correlation');
colorbar;
caxis([-1, 1]);

% Plot 15: Overall comparison
subplot(3, 5, 15);
% Plot mean temporal profiles
mean_heat = mean(squeeze(heat_coefficients(repr_vertex_idx, :, :)), 1);
mean_wave = mean(squeeze(wave_coefficients(repr_vertex_idx, :, :)), 1);
mean_causal = mean(squeeze(causal_coefficients(repr_vertex_idx, :, :)), 1);
mean_mexhat = mean(squeeze(mexhat_coefficients(repr_vertex_idx, :, :)), 1);

plot(t, mean_heat, 'r-', 'LineWidth', 2, 'DisplayName', 'Heat');
hold on;
plot(t, mean_wave, 'b-', 'LineWidth', 2, 'DisplayName', 'Wave');
plot(t, mean_causal, 'g-', 'LineWidth', 2, 'DisplayName', 'Causal');
plot(t, mean_mexhat, 'm-', 'LineWidth', 2, 'DisplayName', 'MexHat');
xlabel('Time (s)');
ylabel('Mean DGW Response');
title('Kernel Comparison');
legend('Location', 'best');
grid on;

sgtitle('Dynamic Graph Wavelets: Multi-Kernel Analysis');

%% 8. Summary
fprintf('\n8. DGW Summary:\n');
fprintf('   Heat kernels: Capture diffusion-like processes\n');
fprintf('   Wave kernels: Detect oscillatory patterns\n');
fprintf('   Causal kernels: Model directional propagation\n');
fprintf('   Mexican hat: Provide band-pass like filtering\n');
fprintf('   \n');
fprintf('   Analysis completed for %d vertices with %d time samples\n', ...
        n_analysis_vertices, length(t));

% Computational complexity summary
total_dgw_coeffs = n_analysis_vertices * (n_scales + length(wave_frequencies) + ...
                  length(damping_rates) + length(hat_widths)) * length(t);
fprintf('   Total DGW coefficients computed: %d\n', total_dgw_coeffs);

fprintf('\n=== DGW demo completed! ===\n');

end

% Helper function
function [G, X, fs, t] = load_bunny_data()
% Reuse data loading function
dataPath = 'test-data/omega-tutorial/sub-0002/sensor/data_block001_band_02.mat';
data = load(dataPath);
megData = data.F;

G_full = gsp_bunny();
G_full = gsp_compute_fourier_basis(G_full);

rng(42);
nVertices = 300;
vertexIndices = randperm(G_full.N, nVertices);
G = gsp_subgraph(G_full, vertexIndices);
G = gsp_estimate_lmax(G);
G = gsp_compute_fourier_basis(G);

downsample_factor = round(300 / 64);  % Target 64 Hz sampling rate
time_indices = 1:downsample_factor:size(megData, 2);
X = megData(1:G.N, time_indices);

fs = 300 / downsample_factor;
t = (0:length(time_indices)-1) / fs;
end