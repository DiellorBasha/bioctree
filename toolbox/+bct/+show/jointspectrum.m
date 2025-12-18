function h = jointspectrum(sig, varargin)
%BCT.SHOW.JOINTSPECTRUM  Visualize joint Manifold-Time Fourier Transform
%
%   Displays the 2D joint transform as an imagesc plot with proper axis labeling.
%
%   h = BCT.SHOW.JOINTSPECTRUM(sig) displays the power spectrum of a signal
%   in the joint spectral-frequency domain (Lambda × Omega).
%
%   h = BCT.SHOW.JOINTSPECTRUM(sig, Name, Value) specifies additional options:
%
%   Parameters:
%     'FrequencyUnits' - Units for frequency axis (default: 'Hz')
%                        'Hz'    - Frequency in Hertz
%                        'index' - Frequency index (sample number)
%                        'norm'  - Normalized frequency [0, 1]
%
%     'SpatialUnits'   - Units for spatial axis (default: 'eigenvalue')
%                        'eigenvalue'     - Eigenvalue λ
%                        'wavenumber'     - Wavenumber k = √λ
%                        'wavelength'     - Wavelength 2π/√λ
%                        'halfwavelength' - Half wavelength π/√λ
%                        'index'          - Eigenmode index
%
%     'PlotType'       - Type of plot (default: 'power')
%                        'power'     - Power spectrum |X|²
%                        'logpower'  - Log₁₀ power spectrum
%                        'magnitude' - Magnitude |X|
%                        'phase'     - Phase angle
%                        'real'      - Real part
%                        'imag'      - Imaginary part
%
%     'Colormap'       - Colormap name (default: 'parula')
%
%     'FrequencyRange' - [fmin fmax] frequency range to display (in Hz if 'Hz' units)
%                        Default: full range
%
%     'SpatialRange'   - [λmin λmax] or [kmin kmax] spatial range to display
%                        Default: full range
%
%     'Axes'           - Axes handle to plot into (default: gca)
%
% Example:
%   % Create and transform spatiotemporal signal
%   sig_st = bct.Signal.fromBrush(B.Manifold, 'Category', 'time', ...
%       'Type', 'spectral', 'Time', B.Time);
%   sig_spectral = bct.operator.transform.joint(sig_st);
%   
%   % Visualize in frequency domain
%   figure;
%   bct.show.jointspectrum(sig_spectral, 'FrequencyUnits', 'Hz', ...
%       'PlotType', 'logpower');
%
% See also: bct.operator.transform.joint, bct.show.eigenspectrum

    arguments
        sig (1,1) bct.Signal
    end
    
    % Parse input arguments
    p = inputParser;
    addParameter(p, 'FrequencyUnits', 'Hz', @(x) ischar(x) || isstring(x));
    addParameter(p, 'SpatialUnits', 'eigenvalue', @(x) ischar(x) || isstring(x));
    addParameter(p, 'PlotType', 'power', @(x) ischar(x) || isstring(x));
    addParameter(p, 'Colormap', 'parula', @(x) ischar(x) || isstring(x));
    addParameter(p, 'FrequencyRange', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
    addParameter(p, 'SpatialRange', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
    addParameter(p, 'Axes', [], @(x) isempty(x) || isa(x, 'matlab.graphics.axis.Axes'));
    parse(p, varargin{:});
    opts = p.Results;
    
    % Validate signal is on Joint domain
    if ~isa(sig.Domain, 'bct.Joint')
        error("bct:show:jointspectrum:InvalidDomain", ...
            "Signal must be on a Joint domain.");
    end
    
    % Extract domains
    lambda_domain = sig.Domain.A;
    omega_domain = sig.Domain.B;
    
    % Check if this is Lambda × Omega domain
    is_spectral = isa(lambda_domain, 'bct.Lambda') && isa(omega_domain, 'bct.Omega');
    
    if ~is_spectral
        error("bct:show:jointspectrum:InvalidDomains", ...
            "Signal must be on Joint(Lambda, Omega) domain. " + ...
            "Use bct.operator.transform.joint to transform first.");
    end
    
    % Get data
    data = sig.Data;  % [K × Nt]
    [K, Nt] = size(data);
    
    % Compute plot data based on PlotType
    switch lower(opts.PlotType)
        case 'power'
            plot_data = abs(data).^2;
            clabel = 'Power';
        case 'logpower'
            plot_data = log10(abs(data).^2 + 1e-20);
            clabel = 'Log_{10} Power';
        case 'magnitude'
            plot_data = abs(data);
            clabel = 'Magnitude';
        case 'phase'
            plot_data = angle(data);
            clabel = 'Phase (rad)';
        case 'real'
            plot_data = real(data);
            clabel = 'Real Part';
        case 'imag'
            plot_data = imag(data);
            clabel = 'Imaginary Part';
        otherwise
            error("bct:show:jointspectrum:InvalidPlotType", ...
                "PlotType must be: power, logpower, magnitude, phase, real, or imag");
    end
    
    % Get spatial axis
    lambda = lambda_domain.lambda;  % eigenvalues
    spatial_axis = convert_spatial_units(lambda, opts.SpatialUnits);
    spatial_label = get_spatial_label(opts.SpatialUnits);
    
    % Get frequency axis (fftshifted, so zero is centered)
    time_domain = omega_domain.dual;
    fs = time_domain.SampleRate;
    
    % Create frequency axis with zero in center
    freq_axis = create_frequency_axis(Nt, fs, opts.FrequencyUnits);
    freq_label = get_frequency_label(opts.FrequencyUnits);
    
    % Apply range filters
    if ~isempty(opts.SpatialRange)
        idx_spatial = spatial_axis >= opts.SpatialRange(1) & spatial_axis <= opts.SpatialRange(2);
        plot_data = plot_data(idx_spatial, :);
        spatial_axis = spatial_axis(idx_spatial);
    end
    
    if ~isempty(opts.FrequencyRange)
        idx_freq = freq_axis >= opts.FrequencyRange(1) & freq_axis <= opts.FrequencyRange(2);
        plot_data = plot_data(:, idx_freq);
        freq_axis = freq_axis(idx_freq);
    end
    
    % Get or create axes
    if isempty(opts.Axes)
        ax = gca;
    else
        ax = opts.Axes;
    end
    
    % Create imagesc plot
    h_img = imagesc(ax, freq_axis, spatial_axis, plot_data);
    
    % Set axis properties
    axis(ax, 'xy');  % Origin at bottom-left
    colormap(ax, opts.Colormap);
    h_cbar = colorbar(ax);
    ylabel(h_cbar, clabel);
    
    % Labels
    xlabel(ax, freq_label);
    ylabel(ax, spatial_label);
    
    % Title
    title(ax, sprintf('Joint Spectrum: \\Lambda × \\Omega (%s)', opts.PlotType));
    
    % Add grid
    grid(ax, 'on');
    
    % Return handle if requested
    if nargout > 0
        h = h_img;
    end
end

%% Helper functions

function axis_values = convert_spatial_units(lambda, units)
    %CONVERT_SPATIAL_UNITS Convert eigenvalues to specified spatial units
    switch lower(units)
        case 'eigenvalue'
            axis_values = lambda;
        case 'wavenumber'
            axis_values = sqrt(lambda);
        case 'wavelength'
            axis_values = 2 * pi ./ sqrt(lambda);
        case 'halfwavelength'
            axis_values = pi ./ sqrt(lambda);
        case 'index'
            axis_values = 1:length(lambda);
        otherwise
            error("bct:show:jointspectrum:InvalidSpatialUnits", ...
                "SpatialUnits must be: eigenvalue, wavenumber, wavelength, halfwavelength, or index");
    end
end

function label = get_spatial_label(units)
    %GET_SPATIAL_LABEL Get axis label for spatial units
    switch lower(units)
        case 'eigenvalue'
            label = 'Eigenvalue \lambda';
        case 'wavenumber'
            label = 'Wavenumber k = \surd\lambda';
        case 'wavelength'
            label = 'Wavelength 2\pi/\surd\lambda';
        case 'halfwavelength'
            label = 'Half Wavelength \pi/\surd\lambda';
        case 'index'
            label = 'Eigenmode Index';
        otherwise
            label = 'Spatial Axis';
    end
end

function freq_axis = create_frequency_axis(Nt, fs, units)
    %CREATE_FREQUENCY_AXIS Create frequency axis with zero in center
    % After fftshift, the DC component is at the center
    
    if mod(Nt, 2) == 0
        % Even length: -Nt/2 to Nt/2-1
        freq_indices = (-Nt/2):(Nt/2-1);
    else
        % Odd length: -(Nt-1)/2 to (Nt-1)/2
        freq_indices = (-(Nt-1)/2):((Nt-1)/2);
    end
    
    switch lower(units)
        case 'hz'
            % Convert to Hz
            freq_axis = freq_indices * (fs / Nt);
        case 'index'
            % Just use indices
            freq_axis = freq_indices;
        case 'norm'
            % Normalized frequency [0, 1]
            freq_axis = freq_indices / Nt;
        otherwise
            error("bct:show:jointspectrum:InvalidFrequencyUnits", ...
                "FrequencyUnits must be: Hz, index, or norm");
    end
end

function label = get_frequency_label(units)
    %GET_FREQUENCY_LABEL Get axis label for frequency units
    switch lower(units)
        case 'hz'
            label = 'Frequency (Hz)';
        case 'index'
            label = 'Frequency Index';
        case 'norm'
            label = 'Normalized Frequency';
        otherwise
            label = 'Frequency';
    end
end
