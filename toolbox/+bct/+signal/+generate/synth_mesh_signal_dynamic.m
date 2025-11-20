```matlab
function [B_out, spatial_pattern, temporal_pattern] = synth_mesh_signal_dynamic(B, spec, timespec, varargin)
%SYNTH_MESH_SIGNAL_DYNAMIC Generate time-varying graph signal with spatial and temporal structure
%
%   B_out = bct.sim.synth_mesh_signal_dynamic(B, spec, timespec) generates a
%       dynamic signal by creating a spatial pattern (using spec) and evolving
%       it over time according to temporal dynamics (using timespec).
%
%   [B_out, spatial_pattern, temporal_pattern] = ... also returns:
%       spatial_pattern   - [N×1] base spatial pattern
%       temporal_pattern  - [T×1] temporal modulation (empty for sinusoid type)
%
%   Algorithm:
%       For 'sinusoid' type:
%           - Maps spatial pattern to phase offsets: φ[n] ∈ [0, 2π]
%           - Each vertex oscillates at same frequency but different phase:
%             X[n,t] = A[n] * sin(ωt + φ[n])
%           - This creates a traveling wave-like pattern where vertices
%             oscillate together but phase-shifted based on initial values
%
%       For 'oscillation_burst' type:
%           - Uses outer product: X[n,t] = spatial[n] * temporal[t]
%           - All vertices follow the same temporal envelope
%
%   Parameters:
%       spec     - Spatial spectral specification (same as synth_mesh_signal)
%                  Controls spatial frequency content
%       timespec - Temporal dynamics specification
%                  .type - 'sinusoid', 'traveling_wave', 'oscillation_burst'
%
%       'k'         - Number of spatial eigenmodes (default: use cached or 200)
%       'normalize' - Normalize spatial pattern to unit RMS (default: true)
%       'verbose'   - Print computation progress (default: true)
%       'label'     - Label for the Signal object (default: auto-generated)
%       
%   Timespec Structure:
%       For 'sinusoid':
%           timespec.type = 'sinusoid'
%           timespec.freq - Temporal frequency in Hz (e.g., 10 Hz)
%           timespec.phase - Global phase offset in radians (default: 0)
%           
%           Each vertex will oscillate at the same frequency but starts at
%           a different phase determined by its spatial pattern value.
%           Vertices with similar spatial values oscillate in phase.
%
%       For 'traveling_wave':
%           timespec.type = 'traveling_wave'
%           timespec.freq - Temporal frequency in Hz
%           timespec.velocity - Wave velocity (spatial units/second)
%           timespec.direction - [x, y, z] propagation direction
%
%       For 'oscillation_burst':
%           timespec.type = 'oscillation_burst'
%           timespec.freq - Carrier frequency in Hz
%           timespec.burst_start - Burst start time (seconds)
%           timespec.burst_duration - Burst duration (seconds)
%           timespec.taper_width - Gaussian taper width (seconds)
%
%   Returns:
%       B_out - bct object with dynamic Signal added [N×T]
%       spatial_pattern - Base spatial pattern [N×1]
%       temporal_pattern - Temporal modulation [T×1] (empty for sinusoid)
%
%   Example 1: Sinusoidal modulation with phase mapping
%       B = bct.bct.fromMesh(V, F);
%       B.Manifold.Time = bct.manifold.Time(100, 100);  % 1 sec at 100 Hz
%       
%       % Spatial pattern (alpha band)
%       spec.type = 'narrowband';
%       spec.f0 = 0.1;
%       spec.bw_abs = 0.02;
%       
%       % Temporal dynamics (10 Hz oscillation)
%       % Each vertex will oscillate at 10 Hz but start at different phases
%       timespec.type = 'sinusoid';
%       timespec.freq = 10;  % Hz
%       
%       B = bct.sim.synth_mesh_signal_dynamic(B, spec, timespec);
%
%   Example 2: Oscillation burst
%       timespec.type = 'oscillation_burst';
%       timespec.freq = 10;
%       timespec.burst_start = 0.3;
%       timespec.burst_duration = 0.4;
%       timespec.taper_width = 0.05;
%       
%       B = bct.sim.synth_mesh_signal_dynamic(B, spec, timespec);
%
%   Notes:
%       - For sinusoid type, the spatial pattern determines phase offsets,
%         creating spatially coherent oscillations
%       - For burst type, spatial and temporal patterns are separable
%       - The Manifold must have Time property set before calling
%
%   See also: bct.sim.synth_mesh_signal, bct.signal.Signal, bct.manifold.Time

    % Validate inputs
    if isempty(B.Manifold)
        error('bct:NoManifold', 'BCT object must have a Manifold');
    end
    
    if isempty(B.Manifold.Time)
        error('bct:NoManifoldTime', ...
            'BCT object must have Manifold.Time set for dynamic signals');
    end
    
    % Get dimensions
    N = B.Manifold.N;
    T = B.Manifold.Time.T;
    fs = B.Manifold.Time.fs;
    t_vec = B.Manifold.Time.get_time_vector();
    
    % Parse inputs
    p = inputParser;
    p.addParameter('k', [], @(x)isempty(x)||(isscalar(x)&&x>0));
    p.addParameter('normalize', true, @islogical);
    p.addParameter('verbose', true, @islogical);
    p.addParameter('label', '', @(x)ischar(x)||isstring(x));
    p.parse(varargin{:});
    
    k_requested = p.Results.k;
    do_normalize = p.Results.normalize;
    verbose = p.Results.verbose;
    user_label = string(p.Results.label);
    
    if verbose
        fprintf('[bct.sim.synth_mesh_signal_dynamic] Generating dynamic signal\n');
        fprintf('  Spatial: N=%d vertices\n', N);
        fprintf('  Temporal: T=%d samples at %.1f Hz (%.3f sec)\n', ...
            T, fs, B.Manifold.Time.get_duration());
    end
    
    %% Step 1: Generate spatial pattern
    if verbose
        fprintf('  Step 1: Generating spatial pattern...\n');
    end
    
    % Use synth_mesh_signal to create spatial pattern (return raw data)
    if isempty(k_requested)
        spatial_pattern = bct.sim.synth_mesh_signal(B, spec, ...
            'normalize', do_normalize, 'verbose', false, 'return_raw', true);
    else
        spatial_pattern = bct.sim.synth_mesh_signal(B, spec, 'k', k_requested, ...
            'normalize', do_normalize, 'verbose', false, 'return_raw', true);
    end
    
    if verbose
        fprintf('    ✓ Spatial pattern: [%d×1], RMS=%.3f\n', ...
            length(spatial_pattern), sqrt(mean(spatial_pattern.^2)));
    end
    
    %% Step 2: Generate temporal pattern
    if verbose
        fprintf('  Step 2: Generating temporal pattern (%s)...\n', timespec.type);
    end
    
    % For sinusoid: each vertex starts at different phase based on spatial pattern
    % For other types: use standard temporal pattern
    if strcmpi(timespec.type, 'sinusoid')
        temporal_pattern = [];  % Not used for sinusoid
        if verbose
            fprintf('    Using phase mapping: each vertex at different phase\n');
        end
    else
        temporal_pattern = generate_temporal_pattern(t_vec, timespec, verbose);
        if verbose
            fprintf('    ✓ Temporal pattern: [%d×1], range=[%.3f, %.3f]\n', ...
                length(temporal_pattern), min(temporal_pattern), max(temporal_pattern));
        end
    end
    
    %% Step 3: Combine spatial and temporal patterns
    if verbose
        fprintf('  Step 3: Combining spatial and temporal patterns...\n');
    end
    
    % Create dynamic signal
    if strcmpi(timespec.type, 'sinusoid')
        % Map spatial pattern to phase offsets
        % Normalize spatial to [0, 2π] range
        spatial_norm = (spatial_pattern - min(spatial_pattern)) / ...
                       (max(spatial_pattern) - min(spatial_pattern));
        phase_offsets = spatial_norm * 2 * pi;  % [N×1], range [0, 2π]
        
        % Each vertex oscillates: X[n,t] = A[n] * sin(ωt + φ[n])
        omega = 2 * pi * timespec.freq;  % angular frequency
        if isfield(timespec, 'phase')
            omega_phase = timespec.phase;
        else
            omega_phase = 0;
        end
        
        % X[n,t] = A[n] * sin(ωt + φ[n] + global_phase)
        % Broadcasting: [N×1] .* sin([N×1] + ω*[1×T] + global_phase)
        dynamic_signal = abs(spatial_pattern) .* ...
                        sin(phase_offsets + omega * t_vec' + omega_phase);
        
        if verbose
            fprintf('    Phase range: [0, 2π], frequency: %.1f Hz\n', timespec.freq);
        end
    else
        % Standard outer product: X[n,t] = spatial[n] * temporal[t]
        dynamic_signal = spatial_pattern * temporal_pattern';  % [N×T]
    end
    
    dynamic_signal = single(dynamic_signal);
    
    if verbose
        fprintf('    ✓ Dynamic signal: [%d×%d], RMS=%.3f\n', ...
            size(dynamic_signal, 1), size(dynamic_signal, 2), ...
            sqrt(mean(dynamic_signal(:).^2)));
    end
    
    %% Step 4: Create Signal object and add to bct
    % Generate label if not provided
    if isempty(user_label)
        label = generate_label(spec, timespec);
    else
        label = user_label;
    end
    
    % Create Signal object
    sig = bct.signal.Signal(B.Manifold, dynamic_signal, label);
    
    % Add to bct object
    B_out = B;
    B_out.addSignal(sig);
    
    if verbose
        fprintf('  ✓ Added dynamic signal "%s" to bct object\n', label);
    end
end

%% Helper functions

function temporal_pattern = generate_temporal_pattern(t_vec, timespec, verbose)
    % Generate temporal modulation pattern based on timespec
    % Note: For sinusoid type, this is not called (handled in main function)
    
    switch lower(timespec.type)
        case 'sinusoid'
            % Simple sinusoidal modulation
            freq = timespec.freq;  % Hz
            if isfield(timespec, 'phase')
                phase = timespec.phase;
            else
                phase = 0;
            end
            
            temporal_pattern = sin(2*pi*freq*t_vec + phase);
            
            if verbose
                fprintf('      Sinusoid: %.1f Hz, phase=%.2f rad\n', freq, phase);
            end
            
        case 'traveling_wave'
            % Traveling wave (requires spatial coordinates)
            error('bct:NotImplemented', ...
                'traveling_wave type not yet implemented. Use sinusoid for now.');
            
        case 'oscillation_burst'
            % Oscillation burst with Gaussian envelope
            freq = timespec.freq;
            burst_start = timespec.burst_start;
            burst_duration = timespec.burst_duration;
            taper_width = timespec.taper_width;
            
            % Carrier oscillation
            carrier = sin(2*pi*freq*t_vec);
            
            % Gaussian envelope centered on burst
            burst_center = burst_start + burst_duration/2;
            envelope = exp(-((t_vec - burst_center).^2) / (2*taper_width^2));
            
            % Modulate carrier with envelope
            temporal_pattern = carrier .* envelope';
            
            if verbose
                fprintf('      Burst: %.1f Hz carrier, %.3f-%.3f sec, taper=%.3f sec\n', ...
                    freq, burst_start, burst_start+burst_duration, taper_width);
            end
            
        otherwise
            error('bct:UnknownTimespecType', ...
                'Unknown timespec.type: %s. Use ''sinusoid'' or ''oscillation_burst''', ...
                timespec.type);
    end
    
    % Ensure column vector
    temporal_pattern = temporal_pattern(:);
end

function label = generate_label(spec, timespec)
    % Generate automatic label based on spec and timespec
    
    % Spatial part
    switch lower(spec.type)
        case 'narrowband'
            if isfield(spec, 'f0')
                spatial_part = sprintf('nb_f%.3g', spec.f0);
            else
                spatial_part = 'nb';
            end
        case 'powerlaw'
            if isfield(spec, 'alpha')
                spatial_part = sprintf('pl_a%.2g', spec.alpha);
            else
                spatial_part = 'pl';
            end
        case 'flat'
            spatial_part = 'flat';
        case 'bandpass'
            if isfield(spec, 'fmin') && isfield(spec, 'fmax')
                spatial_part = sprintf('bp_%.3g_%.3g', spec.fmin, spec.fmax);
            else
                spatial_part = 'bp';
            end
        otherwise
            spatial_part = 'spatial';
    end
    
    % Temporal part
    switch lower(timespec.type)
        case 'sinusoid'
            if isfield(timespec, 'freq')
                temporal_part = sprintf('sin_%.1fHz', timespec.freq);
            else
                temporal_part = 'sin';
            end
        case 'oscillation_burst'
            if isfield(timespec, 'freq')
                temporal_part = sprintf('burst_%.1fHz', timespec.freq);
            else
                temporal_part = 'burst';
            end
        otherwise
            temporal_part = 'temporal';
    end
    
    % Combine
    label = sprintf('%s_%s', spatial_part, temporal_part);
end

```
