classdef BioctreePlotter < handle
    % BIOCTREEPLOTTER A plotting class for visualizing Bioctree HDF5 data
    %
    % This class provides specialized plotting methods for data stored in
    % Bioctree HDF5 format, including graph structures, signals, and analysis results.
    %
    % Usage:
    %   plotter = BioctreePlotter(hdf5_file_or_data)
    %   plotter.plotWireframe()
    %
    % Constructor inputs:
    %   hdf5_file_or_data - Either:
    %     1. String/char: Path to HDF5 file
    %     2. Struct: Pre-loaded HDF5 data structure
    %
    % Methods:
    %   plotWireframe() - Plot wireframe view of graph structure
    %
    % Examples:
    %   % From HDF5 file path
    %   plotter = BioctreePlotter('data.h5');
    %   plotter.plotWireframe();
    %
    %   % From loaded data structure  
    %   data = inbct('data.h5');
    %   plotter = BioctreePlotter(data);
    %   plotter.plotWireframe();
    
    properties (Access = private)
        data_source     % Source of data ('file' or 'struct')
        file_path       % Path to HDF5 file (if data_source is 'file')
        data_struct     % Loaded data structure (if data_source is 'struct')
        graph_coords    % Graph coordinates [N x 3]
        graph_faces     % Graph face connectivity (if available)
        graph_edges     % Graph edge list
        graph_N         % Number of vertices
        is_loaded       % Flag indicating if data is loaded
    end
    
    methods
        function obj = BioctreePlotter(hdf5_file_or_data)
            % BIOCTREEPLOTTER Constructor
            %
            % Input:
            %   hdf5_file_or_data - HDF5 file path (string/char) or loaded data (struct)
            
            obj.is_loaded = false;
            
            if ischar(hdf5_file_or_data) || isstring(hdf5_file_or_data)
                % Input is file path
                obj.data_source = 'file';
                obj.file_path = char(hdf5_file_or_data);
                
                % Validate file exists
                if ~exist(obj.file_path, 'file')
                    error('BioctreePlotter:FileNotFound', ...
                        'HDF5 file not found: %s', obj.file_path);
                end
                
                fprintf('BioctreePlotter: Initialized with HDF5 file: %s\n', obj.file_path);
                
            elseif isstruct(hdf5_file_or_data)
                % Input is data structure
                obj.data_source = 'struct';
                obj.data_struct = hdf5_file_or_data;
                
                fprintf('BioctreePlotter: Initialized with data structure\n');
                
            else
                error('BioctreePlotter:InvalidInput', ...
                    'Input must be HDF5 file path (string) or data structure (struct)');
            end
            
            % Load graph data
            obj.loadGraphData();
        end
        
        function fig = plotWireframe(obj, varargin)
            % PLOTWIREFRAME Plot wireframe view of graph structure
            %
            % Usage:
            %   fig = plotWireframe()
            %   fig = plotWireframe('param', value, ...)
            %
            % Parameters:
            %   'Figure'      - Figure handle to plot in (default: new figure)
            %   'LineWidth'   - Edge line width (default: 0.5)
            %   'EdgeColor'   - Edge color (default: 'black')
            %   'VertexSize'  - Vertex marker size (default: 20)
            %   'VertexColor' - Vertex color (default: 'red')
            %   'ShowVertices'- Show vertex markers (default: true)
            %   'Title'       - Plot title (default: 'Graph Wireframe')
            %   'ViewAngle'   - View angle [azimuth, elevation] (default: [45, 30])
            %
            % Returns:
            %   fig - Figure handle
            
            % Parse input parameters
            p = inputParser;
            addParameter(p, 'Figure', [], @(x) isa(x, 'matlab.ui.Figure') || isempty(x));
            addParameter(p, 'LineWidth', 0.5, @(x) isnumeric(x) && x > 0);
            addParameter(p, 'EdgeColor', 'black', @(x) ischar(x) || isnumeric(x));
            addParameter(p, 'VertexSize', 20, @(x) isnumeric(x) && x > 0);
            addParameter(p, 'VertexColor', 'red', @(x) ischar(x) || isnumeric(x));
            addParameter(p, 'ShowVertices', true, @islogical);
            addParameter(p, 'Title', 'Graph Wireframe', @(x) ischar(x) || isstring(x));
            addParameter(p, 'ViewAngle', [45, 30], @(x) isnumeric(x) && length(x) == 2);
            parse(p, varargin{:});
            
            % Check if data is loaded
            if ~obj.is_loaded
                error('BioctreePlotter:DataNotLoaded', ...
                    'Graph data not loaded. Cannot create plot.');
            end
            
            % Create or use specified figure
            if isempty(p.Results.Figure)
                fig = figure('Name', 'Bioctree Graph Wireframe', ...
                           'Position', [100, 100, 800, 600]);
            else
                fig = p.Results.Figure;
                figure(fig);
            end
            
            % Clear current axes
            clf;
            
            % Create wireframe plot
            fprintf('Plotting wireframe with %d vertices and %d edges...\n', ...
                obj.graph_N, size(obj.graph_edges, 1));
            
            hold on;
            
            % Plot edges
            for i = 1:size(obj.graph_edges, 1)
                v1 = obj.graph_edges(i, 1);
                v2 = obj.graph_edges(i, 2);
                
                x_coords = [obj.graph_coords(v1, 1), obj.graph_coords(v2, 1)];
                y_coords = [obj.graph_coords(v1, 2), obj.graph_coords(v2, 2)];
                z_coords = [obj.graph_coords(v1, 3), obj.graph_coords(v2, 3)];
                
                plot3(x_coords, y_coords, z_coords, ...
                     'Color', p.Results.EdgeColor, ...
                     'LineWidth', p.Results.LineWidth);
            end
            
            % Plot vertices if requested
            if p.Results.ShowVertices
                scatter3(obj.graph_coords(:, 1), ...
                        obj.graph_coords(:, 2), ...
                        obj.graph_coords(:, 3), ...
                        p.Results.VertexSize, ...
                        p.Results.VertexColor, 'filled');
            end
            
            hold off;
            
            % Set plot properties
            axis equal;
            grid on;
            title(p.Results.Title, 'FontSize', 14, 'FontWeight', 'bold');
            xlabel('X', 'FontSize', 12);
            ylabel('Y', 'FontSize', 12);
            zlabel('Z', 'FontSize', 12);
            
            % Set view angle
            view(p.Results.ViewAngle(1), p.Results.ViewAngle(2));
            
            % Add lighting for better visualization
            lighting gouraud;
            camlight('headlight');
            
            % Add information text
            info_text = sprintf('Vertices: %d | Edges: %d', ...
                obj.graph_N, size(obj.graph_edges, 1));
            
            if strcmp(obj.data_source, 'file')
                [~, filename, ~] = fileparts(obj.file_path);
                info_text = sprintf('%s | File: %s', info_text, filename);
            end
            
            text(0.02, 0.98, info_text, 'Units', 'normalized', ...
                'VerticalAlignment', 'top', 'FontSize', 10, ...
                'BackgroundColor', 'white', 'EdgeColor', 'black');
            
            fprintf('✓ Wireframe plot created successfully\n');
        end
        
        function fig = plotSignal(obj, varargin)
            % PLOTSIGNAL Plot graph signal on the mesh surface
            %
            % Usage:
            %   fig = plotSignal()
            %   fig = plotSignal('param', value, ...)
            %
            % Parameters:
            %   'SignalName'  - Name of signal dataset (default: 'signal')
            %   'TimeIndex'   - Time index for temporal signals (default: 1)
            %   'Figure'      - Figure handle to plot in (default: new figure)
            %   'Colormap'    - Colormap for signal values (default: 'jet')
            %   'ShowColorbar'- Show colorbar (default: true)
            %   'Title'       - Plot title (default: auto-generated)
            %   'ViewAngle'   - View angle [azimuth, elevation] (default: [45, 30])
            %   'EdgeAlpha'   - Edge transparency (default: 0.3)
            %   'MarkerSize'  - Vertex marker size (default: 50)
            %
            % Returns:
            %   fig - Figure handle
            
            % Parse input parameters
            p = inputParser;
            addParameter(p, 'SignalName', 'signal', @(x) ischar(x) || isstring(x));
            addParameter(p, 'TimeIndex', 1, @(x) isnumeric(x) && x >= 1);
            addParameter(p, 'Figure', [], @(x) isa(x, 'matlab.ui.Figure') || isempty(x));
            addParameter(p, 'Colormap', 'jet', @(x) ischar(x) || isstring(x));
            addParameter(p, 'ShowColorbar', true, @islogical);
            addParameter(p, 'Title', '', @(x) ischar(x) || isstring(x));
            addParameter(p, 'ViewAngle', [45, 30], @(x) isnumeric(x) && length(x) == 2);
            addParameter(p, 'EdgeAlpha', 0.3, @(x) isnumeric(x) && x >= 0 && x <= 1);
            addParameter(p, 'MarkerSize', 50, @(x) isnumeric(x) && x > 0);
            parse(p, varargin{:});
            
            % Check if data is loaded
            if ~obj.is_loaded
                error('BioctreePlotter:DataNotLoaded', ...
                    'Graph data not loaded. Cannot create plot.');
            end
            
            % Load signal data
            signal_data = obj.loadSignalData(p.Results.SignalName, p.Results.TimeIndex);
            
            % Create or use specified figure
            if isempty(p.Results.Figure)
                fig = figure('Name', 'Bioctree Graph Signal', ...
                           'Position', [150, 150, 900, 700]);
            else
                fig = p.Results.Figure;
                figure(fig);
            end
            
            % Clear current axes
            clf;
            
            % Create signal plot
            fprintf('Plotting signal "%s" with %d vertices...\n', ...
                p.Results.SignalName, length(signal_data));
            
            hold on;
            
            % Plot edges with transparency
            if p.Results.EdgeAlpha > 0
                edge_color = [0.7, 0.7, 0.7];
                for i = 1:size(obj.graph_edges, 1)
                    v1 = obj.graph_edges(i, 1);
                    v2 = obj.graph_edges(i, 2);
                    
                    x_coords = [obj.graph_coords(v1, 1), obj.graph_coords(v2, 1)];
                    y_coords = [obj.graph_coords(v1, 2), obj.graph_coords(v2, 2)];
                    z_coords = [obj.graph_coords(v1, 3), obj.graph_coords(v2, 3)];
                    
                    plot3(x_coords, y_coords, z_coords, ...
                         'Color', edge_color, ...
                         'LineWidth', 0.3);
                end
            end
            
            % Plot signal as colored vertices
            scatter3(obj.graph_coords(:, 1), ...
                    obj.graph_coords(:, 2), ...
                    obj.graph_coords(:, 3), ...
                    p.Results.MarkerSize, ...
                    signal_data, 'filled');
            
            hold off;
            
            % Set plot properties
            axis equal;
            grid on;
            
            % Set colormap
            colormap(p.Results.Colormap);
            
            % Add colorbar if requested
            if p.Results.ShowColorbar
                cb = colorbar;
                ylabel(cb, 'Signal Amplitude', 'FontSize', 12);
            end
            
            % Set title
            if isempty(p.Results.Title)
                if p.Results.TimeIndex > 1
                    plot_title = sprintf('Graph Signal: %s (t=%d)', ...
                        p.Results.SignalName, p.Results.TimeIndex);
                else
                    plot_title = sprintf('Graph Signal: %s', p.Results.SignalName);
                end
            else
                plot_title = p.Results.Title;
            end
            
            title(plot_title, 'FontSize', 14, 'FontWeight', 'bold');
            xlabel('X', 'FontSize', 12);
            ylabel('Y', 'FontSize', 12);
            zlabel('Z', 'FontSize', 12);
            
            % Set view angle
            view(p.Results.ViewAngle(1), p.Results.ViewAngle(2));
            
            % Add lighting for better visualization
            lighting gouraud;
            camlight('headlight');
            
            % Add information text
            signal_stats = struct();
            signal_stats.min_val = min(signal_data);
            signal_stats.max_val = max(signal_data);
            signal_stats.mean_val = mean(signal_data);
            signal_stats.nonzero_count = sum(signal_data ~= 0);
            
            info_text = sprintf('Signal: %s | Range: [%.3f, %.3f] | Nonzero: %d/%d', ...
                p.Results.SignalName, signal_stats.min_val, signal_stats.max_val, ...
                signal_stats.nonzero_count, length(signal_data));
            
            text(0.02, 0.98, info_text, 'Units', 'normalized', ...
                'VerticalAlignment', 'top', 'FontSize', 10, ...
                'BackgroundColor', 'white', 'EdgeColor', 'black');
            
            fprintf('✓ Signal plot created successfully\n');
            fprintf('  Signal range: [%.4f, %.4f]\n', signal_stats.min_val, signal_stats.max_val);
            fprintf('  Nonzero vertices: %d/%d (%.1f%%)\n', signal_stats.nonzero_count, ...
                length(signal_data), 100 * signal_stats.nonzero_count / length(signal_data));
        end
        
        function signal_names = getAvailableSignals(obj)
            % GETAVAILABLESIGNALS Get list of available signal datasets
            %
            % Returns:
            %   signal_names - Cell array of signal dataset names
            
            signal_names = {};
            
            try
                if strcmp(obj.data_source, 'file')
                    % Load from HDF5 file
                    try
                        % Check if /data/raw group exists
                        raw_info = h5info(obj.file_path, '/data/raw');
                        
                        % Get all dataset names
                        for i = 1:length(raw_info.Datasets)
                            signal_names{end+1} = raw_info.Datasets(i).Name;
                        end
                        
                    catch
                        % Try alternative paths
                        try
                            data_info = h5info(obj.file_path, '/data');
                            for i = 1:length(data_info.Datasets)
                                signal_names{end+1} = data_info.Datasets(i).Name;
                            end
                        catch
                            fprintf('No signal data found in HDF5 file\n');
                        end
                    end
                    
                else
                    % Load from data structure
                    if isfield(obj.data_struct, 'X')
                        signal_names{end+1} = 'X';
                    end
                    
                    if isfield(obj.data_struct, 'X_layers')
                        layer_fields = fieldnames(obj.data_struct.X_layers);
                        signal_names = [signal_names, layer_fields'];
                    end
                end
                
            catch ME
                fprintf('Warning: Could not retrieve signal list: %s\n', ME.message);
            end
            
            if isempty(signal_names)
                fprintf('No signal datasets found\n');
            else
                fprintf('Available signals: %s\n', strjoin(signal_names, ', '));
            end
        end
        
        function info = getGraphInfo(obj)
            % GETGRAPHINFO Get information about the loaded graph
            %
            % Returns:
            %   info - Struct with graph properties
            
            if ~obj.is_loaded
                error('BioctreePlotter:DataNotLoaded', ...
                    'Graph data not loaded.');
            end
            
            info = struct();
            info.num_vertices = obj.graph_N;
            info.num_edges = size(obj.graph_edges, 1);
            info.coordinate_range = [min(obj.graph_coords); max(obj.graph_coords)];
            info.data_source = obj.data_source;
            
            if strcmp(obj.data_source, 'file')
                info.file_path = obj.file_path;
                file_info = dir(obj.file_path);
                info.file_size_mb = file_info.bytes / 1024^2;
            end
            
            % Calculate basic graph statistics
            center = mean(obj.graph_coords, 1);
            distances = sqrt(sum((obj.graph_coords - center).^2, 2));
            info.spatial_extent = struct();
            info.spatial_extent.center = center;
            info.spatial_extent.mean_distance_from_center = mean(distances);
            info.spatial_extent.max_distance_from_center = max(distances);
        end
        
        function displayInfo(obj)
            % DISPLAYINFO Display information about the loaded graph
            
            if ~obj.is_loaded
                fprintf('BioctreePlotter: No graph data loaded\n');
                return;
            end
            
            info = obj.getGraphInfo();
            
            fprintf('\n=== Bioctree Graph Information ===\n');
            fprintf('Data source: %s\n', info.data_source);
            
            if strcmp(info.data_source, 'file')
                fprintf('File: %s\n', info.file_path);
                fprintf('File size: %.2f MB\n', info.file_size_mb);
            end
            
            fprintf('Vertices: %d\n', info.num_vertices);
            fprintf('Edges: %d\n', info.num_edges);
            
            fprintf('Coordinate ranges:\n');
            fprintf('  X: [%.3f, %.3f]\n', info.coordinate_range(1,1), info.coordinate_range(2,1));
            fprintf('  Y: [%.3f, %.3f]\n', info.coordinate_range(1,2), info.coordinate_range(2,2));
            fprintf('  Z: [%.3f, %.3f]\n', info.coordinate_range(1,3), info.coordinate_range(2,3));
            
            fprintf('Spatial extent:\n');
            fprintf('  Center: [%.3f, %.3f, %.3f]\n', info.spatial_extent.center);
            fprintf('  Mean radius: %.3f\n', info.spatial_extent.mean_distance_from_center);
            fprintf('  Max radius: %.3f\n', info.spatial_extent.max_distance_from_center);
            
            fprintf('================================\n\n');
        end
    end
    
    methods (Access = private)
        function loadGraphData(obj)
            % LOADGRAPHDATA Load graph data from file or struct
            
            try
                if strcmp(obj.data_source, 'file')
                    % Load from HDF5 file
                    fprintf('Loading graph data from HDF5 file...\n');
                    
                    % Load coordinates
                    obj.graph_coords = h5read(obj.file_path, '/graph/coordinates');
                    obj.graph_N = size(obj.graph_coords, 1);
                    
                    % Try to load adjacency matrix and create edge list
                    try
                        % Try sparse matrix format first
                        i_idx = h5read(obj.file_path, '/graph/adjacency_matrix_i');
                        j_idx = h5read(obj.file_path, '/graph/adjacency_matrix_j');
                        
                        % Create edge list from sparse format (remove duplicates for undirected)
                        edges_all = [i_idx, j_idx];
                        % Keep only upper triangular part (i < j) for undirected graph
                        mask = i_idx < j_idx;
                        obj.graph_edges = edges_all(mask, :);
                        
                    catch
                        % Try direct edge list
                        try
                            obj.graph_edges = h5read(obj.file_path, '/graph/edge_list');
                        catch
                            % Create edge list from coordinates using distance threshold
                            fprintf('  No adjacency data found, creating edges from coordinates...\n');
                            obj.createEdgesFromCoords();
                        end
                    end
                    
                else
                    % Load from data structure
                    fprintf('Extracting graph data from structure...\n');
                    
                    if isfield(obj.data_struct, 'graph') && isfield(obj.data_struct.graph, 'coords')
                        % Data structure format
                        obj.graph_coords = obj.data_struct.graph.coords;
                        obj.graph_N = size(obj.graph_coords, 1);
                        
                        if isfield(obj.data_struct.graph, 'edge_list')
                            obj.graph_edges = obj.data_struct.graph.edge_list;
                        else
                            obj.createEdgesFromCoords();
                        end
                        
                    elseif isfield(obj.data_struct, 'G') && isfield(obj.data_struct.G, 'coords')
                        % Direct G structure format (from loaded HDF5)
                        obj.graph_coords = obj.data_struct.G.coords;
                        obj.graph_N = obj.data_struct.G.N;
                        
                        if isfield(obj.data_struct.G, 'W')
                            % Create edge list from adjacency matrix
                            W = obj.data_struct.G.W;
                            [i_idx, j_idx] = find(triu(W)); % Upper triangular only
                            obj.graph_edges = [i_idx, j_idx];
                        else
                            obj.createEdgesFromCoords();
                        end
                        
                    elseif isfield(obj.data_struct, 'coords') && isfield(obj.data_struct, 'N')
                        % Direct graph structure format (G passed directly)
                        obj.graph_coords = obj.data_struct.coords;
                        obj.graph_N = obj.data_struct.N;
                        
                        if isfield(obj.data_struct, 'W') && ~isempty(obj.data_struct.W)
                            % Create edge list from adjacency matrix
                            W = obj.data_struct.W;
                            [i_idx, j_idx] = find(triu(W)); % Upper triangular only
                            obj.graph_edges = [i_idx, j_idx];
                        else
                            obj.createEdgesFromCoords();
                        end
                        
                    else
                        error('BioctreePlotter:InvalidDataStructure', ...
                            'Data structure must contain graph coordinates (coords field) and vertex count (N field)');
                    end
                end
                
                obj.is_loaded = true;
                fprintf('✓ Graph data loaded: %d vertices, %d edges\n', ...
                    obj.graph_N, size(obj.graph_edges, 1));
                
            catch ME
                obj.is_loaded = false;
                error('BioctreePlotter:LoadError', ...
                    'Failed to load graph data: %s', ME.message);
            end
        end
        
        function createEdgesFromCoords(obj)
            % CREATEEDGESFROMCOORDS Create edge list from coordinates using distance threshold
            
            fprintf('  Creating edges from coordinate proximity...\n');
            
            % Calculate pairwise distances
            D = pdist2(obj.graph_coords, obj.graph_coords);
            
            % Use adaptive threshold based on coordinate distribution
            distances = D(triu(true(size(D)), 1)); % Upper triangular distances only
            threshold = prctile(distances, 5); % Use 5th percentile as threshold
            
            % Create edges
            [i_idx, j_idx] = find(triu(D < threshold & D > 0));
            obj.graph_edges = [i_idx, j_idx];
            
            fprintf('  ✓ Created %d edges using distance threshold %.4f\n', ...
                size(obj.graph_edges, 1), threshold);
        end
        
        function signal_data = loadSignalData(obj, signal_name, time_index)
            % LOADSIGNALDATA Load signal data from file or struct
            %
            % Inputs:
            %   signal_name - Name of signal dataset
            %   time_index  - Time index for temporal signals
            %
            % Returns:
            %   signal_data - Signal values [N x 1]
            
            signal_data = [];
            
            try
                if strcmp(obj.data_source, 'file')
                    % Load from HDF5 file
                    signal_path = sprintf('/data/raw/%s', signal_name);
                    
                    try
                        % Try to read signal dataset
                        signal_full = h5read(obj.file_path, signal_path);
                        
                        % Handle temporal dimension
                        if size(signal_full, 2) > 1
                            if time_index > size(signal_full, 2)
                                error('Time index %d exceeds signal length %d', ...
                                    time_index, size(signal_full, 2));
                            end
                            signal_data = signal_full(:, time_index);
                        else
                            signal_data = signal_full(:, 1);
                        end
                        
                    catch
                        % Try alternative path without /raw
                        try
                            signal_path = sprintf('/data/%s', signal_name);
                            signal_full = h5read(obj.file_path, signal_path);
                            
                            if size(signal_full, 2) > 1
                                signal_data = signal_full(:, time_index);
                            else
                                signal_data = signal_full(:, 1);
                            end
                        catch
                            error('Signal "%s" not found in HDF5 file', signal_name);
                        end
                    end
                    
                else
                    % Load from data structure
                    if strcmp(signal_name, 'X') && isfield(obj.data_struct, 'X')
                        signal_full = obj.data_struct.X;
                        if size(signal_full, 2) > 1
                            signal_data = signal_full(:, time_index);
                        else
                            signal_data = signal_full(:, 1);
                        end
                        
                    elseif isfield(obj.data_struct, 'X_layers') && ...
                           isfield(obj.data_struct.X_layers, signal_name)
                        signal_full = obj.data_struct.X_layers.(signal_name);
                        if size(signal_full, 2) > 1
                            signal_data = signal_full(:, time_index);
                        else
                            signal_data = signal_full(:, 1);
                        end
                        
                    else
                        error('Signal "%s" not found in data structure', signal_name);
                    end
                end
                
                % Validate signal dimensions
                if length(signal_data) ~= obj.graph_N
                    error('Signal length (%d) does not match graph vertices (%d)', ...
                        length(signal_data), obj.graph_N);
                end
                
                fprintf('✓ Loaded signal "%s": %d vertices, range [%.4f, %.4f]\n', ...
                    signal_name, length(signal_data), min(signal_data), max(signal_data));
                
            catch ME
                error('BioctreePlotter:SignalLoadError', ...
                    'Failed to load signal "%s": %s', signal_name, ME.message);
            end
        end
    end
end