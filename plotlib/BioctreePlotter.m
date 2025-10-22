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
    %   plotWireframe()            - Plot wireframe view of graph structure
    %   plotSurface()              - Plot graph as surface mesh
    %   plotSignal()               - Plot graph signal as colored vertices
    %   plotSurfaceSignal()        - Plot signal mapped onto surface mesh
    %   plotGraphFourierTransform()- Plot Graph Fourier Transform spectrum
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
                % Clear current axes only for new figures
                clf;
            else
                fig = p.Results.Figure;
                figure(fig);
                % Don't clear - we might be in a subplot
            end
            
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
        
        function fig = plotSurface(obj, varargin)
            % PLOTSURFACE Plot graph as a surface mesh using face connectivity
            %
            % Usage:
            %   fig = plotSurface()
            %   fig = plotSurface('param', value, ...)
            %
            % Parameters:
            %   'Figure'      - Figure handle to plot in (default: new figure)
            %   'FaceColor'   - Face color (default: [0.8 0.8 1.0])
            %   'EdgeColor'   - Edge color (default: [0.3 0.3 0.3])
            %   'FaceAlpha'   - Face transparency (default: 0.8)
            %   'EdgeAlpha'   - Edge transparency (default: 0.5)
            %   'Lighting'    - Enable lighting (default: true)
            %   'Shading'     - Shading mode 'flat', 'interp', 'gouraud' (default: 'gouraud')
            %   'ShowInfo'    - Show graph info text (default: true)
            %   'ViewAngle'   - View angle [azimuth, elevation] (default: [45, 30])
            %
            % Returns:
            %   fig - Figure handle
            
            % Parse input parameters
            p = inputParser;
            addParameter(p, 'Figure', [], @(x) isa(x, 'matlab.ui.Figure') || isempty(x));
            addParameter(p, 'FaceColor', [0.8 0.8 1.0], @(x) isnumeric(x) && (length(x) == 3 || ischar(x) || isstring(x)));
            addParameter(p, 'EdgeColor', [0.3 0.3 0.3], @(x) isnumeric(x) && (length(x) == 3 || ischar(x) || isstring(x)));
            addParameter(p, 'FaceAlpha', 0.8, @(x) isnumeric(x) && x >= 0 && x <= 1);
            addParameter(p, 'EdgeAlpha', 0.5, @(x) isnumeric(x) && x >= 0 && x <= 1);
            addParameter(p, 'Lighting', true, @(x) islogical(x));
            addParameter(p, 'Shading', 'gouraud', @(x) ischar(x) || isstring(x));
            addParameter(p, 'ShowInfo', true, @(x) islogical(x));
            addParameter(p, 'ViewAngle', [45, 30], @(x) isnumeric(x) && length(x) == 2);
            parse(p, varargin{:});
            
            % Ensure graph data is loaded
            obj.loadGraphData();
            
            % Use provided figure or create new one
            if ~isempty(p.Results.Figure)
                fig = p.Results.Figure;
                figure(fig);
                % Don't clear - we might be in a subplot
            else
                fig = figure('Position', [100, 100, 800, 600]);
            end
            
            hold on;
            
            fprintf('Plotting surface mesh with %d vertices...\n', obj.graph_N);
            
            % Check if we have face data
            if isempty(obj.graph_faces)
                fprintf('  ⚠ No face connectivity available\n');
            end
            
            if ~isempty(obj.graph_faces)
                % Plot using patch with face connectivity
                patch_handle = patch('Vertices', obj.graph_coords, ...
                                   'Faces', obj.graph_faces, ...
                                   'FaceColor', p.Results.FaceColor, ...
                                   'EdgeColor', p.Results.EdgeColor, ...
                                   'FaceAlpha', p.Results.FaceAlpha, ...
                                   'EdgeAlpha', p.Results.EdgeAlpha, ...
                                   'LineWidth', 0.5);
                
                fprintf('  ✓ Surface mesh created with %d faces\n', size(obj.graph_faces, 1));
                
            else
                % Fallback: create surface using triangulation from coordinates
                fprintf('  ℹ No face connectivity available, creating triangulation...\n');
                
                if size(obj.graph_coords, 1) >= 4
                    % Create Delaunay triangulation for surface approximation
                    tri = delaunayTriangulation(obj.graph_coords);
                    
                    % Get the convex hull (outer surface)
                    faces = convexHull(tri);
                    
                    patch_handle = patch('Vertices', obj.graph_coords, ...
                                       'Faces', faces, ...
                                       'FaceColor', p.Results.FaceColor, ...
                                       'EdgeColor', p.Results.EdgeColor, ...
                                       'FaceAlpha', p.Results.FaceAlpha, ...
                                       'EdgeAlpha', p.Results.EdgeAlpha, ...
                                       'LineWidth', 0.5);
                    
                    fprintf('  ✓ Surface created via convex hull: %d faces\n', size(faces, 1));
                else
                    error('Insufficient vertices for surface mesh creation');
                end
            end
            
            % Apply shading (validate MATLAB shading options)
            valid_shading = {'flat', 'interp', 'faceted'};
            if ismember(lower(p.Results.Shading), valid_shading)
                shading(p.Results.Shading);
            elseif strcmpi(p.Results.Shading, 'gouraud')
                shading interp; % gouraud is equivalent to interp in modern MATLAB
            else
                shading interp; % default fallback
            end
            
            % Set up lighting if requested
            if p.Results.Lighting
                lighting gouraud;
                camlight('headlight');
                material dull;
            end
            
            % Set view and axis properties
            axis equal;
            grid on;
            xlabel('X coordinate', 'FontSize', 12);
            ylabel('Y coordinate', 'FontSize', 12);
            zlabel('Z coordinate', 'FontSize', 12);
            view(p.Results.ViewAngle);
            
            % Add informational text if requested
            if p.Results.ShowInfo
                info_text = sprintf('Surface Mesh: %d vertices | %d faces', ...
                    obj.graph_N, size(obj.graph_faces, 1));
                
                if strcmp(obj.data_source, 'file')
                    [~, filename, ~] = fileparts(obj.file_path);
                    info_text = sprintf('%s | File: %s', info_text, filename);
                end
                
                text(0.02, 0.98, info_text, 'Units', 'normalized', ...
                    'VerticalAlignment', 'top', 'FontSize', 10, ...
                    'BackgroundColor', 'white', 'EdgeColor', 'black');
            end
            
            hold off;
            
            fprintf('✓ Surface mesh plot created successfully\n');
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
                % Clear current axes only for new figures
                clf;
            else
                fig = p.Results.Figure;
                figure(fig);
                % Don't clear - we might be in a subplot
            end
            
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
        
        function fig = plotSurfaceSignal(obj, varargin)
            % PLOTSURFACESIGNAL Plot graph signal mapped onto surface mesh
            %
            % Creates a surface mesh with signal data mapped as vertex colors,
            % similar to exportIcosphereVideo but as a static plot.
            %
            % Usage:
            %   fig = plotSurfaceSignal()
            %   fig = plotSurfaceSignal('param', value, ...)
            %
            % Parameters:
            %   'SignalName'  - Name of signal dataset (default: 'signal')
            %   'TimeIndex'   - Time index for temporal signals (default: 1)
            %   'Figure'      - Figure handle to plot in (default: new figure)
            %   'Colormap'    - Colormap for signal values (default: 'turbo')
            %   'ColorLimits' - Color scale limits [min, max] (default: auto)
            %   'ShowColorbar'- Show colorbar (default: true)
            %   'Title'       - Plot title (default: auto-generated)
            %   'ViewAngle'   - View angle [azimuth, elevation] (default: [45, 30])
            %   'EdgeColor'   - Edge color (default: [0.3 0.3 0.3])
            %   'EdgeAlpha'   - Edge transparency (default: 0.1)
            %   'FaceAlpha'   - Face transparency (default: 1.0)
            %   'Lighting'    - Enable lighting (default: true)
            %   'Shading'     - Shading mode 'flat', 'interp', 'gouraud' (default: 'interp')
            %
            % Returns:
            %   fig - Figure handle
            
            % Parse input parameters
            p = inputParser;
            addParameter(p, 'SignalName', 'signal', @(x) ischar(x) || isstring(x));
            addParameter(p, 'TimeIndex', 1, @(x) isnumeric(x) && x >= 1);
            addParameter(p, 'Figure', [], @(x) isa(x, 'matlab.ui.Figure') || isempty(x));
            addParameter(p, 'Colormap', 'turbo', @(x) ischar(x) || isstring(x));
            addParameter(p, 'ColorLimits', [], @(x) isnumeric(x) && length(x) == 2);
            addParameter(p, 'ShowColorbar', true, @islogical);
            addParameter(p, 'ShowInfo', true, @islogical);
            addParameter(p, 'Title', '', @(x) ischar(x) || isstring(x));
            addParameter(p, 'ViewAngle', [45, 30], @(x) isnumeric(x) && length(x) == 2);
            addParameter(p, 'EdgeColor', [0.3 0.3 0.3], @(x) isnumeric(x) && (length(x) == 3 || ischar(x) || isstring(x)));
            addParameter(p, 'EdgeAlpha', 0.1, @(x) isnumeric(x) && x >= 0 && x <= 1);
            addParameter(p, 'FaceAlpha', 1.0, @(x) isnumeric(x) && x >= 0 && x <= 1);
            addParameter(p, 'Lighting', true, @islogical);
            addParameter(p, 'Shading', 'interp', @(x) ischar(x) || isstring(x));
            parse(p, varargin{:});
            
            % Ensure graph data is loaded
            obj.loadGraphData();
            
            % Load signal data
            signal_data = obj.loadSignalData(p.Results.SignalName, p.Results.TimeIndex);
            
            % Validate signal data dimensions
            if length(signal_data) ~= obj.graph_N
                error('BioctreePlotter:SignalDimensionMismatch', ...
                    'Signal data length (%d) does not match number of vertices (%d)', ...
                    length(signal_data), obj.graph_N);
            end
            
            % Ensure signal data is a column vector for proper FaceVertexCData usage
            signal_data = signal_data(:);
            
            % Create or use specified figure
            if isempty(p.Results.Figure)
                fig = figure('Name', 'Bioctree Surface Signal', ...
                           'Position', [150, 150, 900, 700]);
                % Clear current axes only for new figures
                cla;
            else
                fig = p.Results.Figure;
                figure(fig);
                % Don't clear - we might be in a subplot
            end
            
            hold on;
            
            fprintf('Plotting surface signal "%s" with %d vertices...\n', ...
                p.Results.SignalName, length(signal_data));
            
            % Determine color limits
            if isempty(p.Results.ColorLimits)
                signal_range = [min(signal_data), max(signal_data)];
                if signal_range(1) == signal_range(2)
                    signal_range = signal_range + [-0.1, 0.1]; % Add small range if constant
                end
            else
                signal_range = p.Results.ColorLimits;
            end
            
            if ~isempty(obj.graph_faces)
                % Create surface mesh with signal-colored vertices
                patch_handle = patch('Vertices', obj.graph_coords, ...
                                   'Faces', obj.graph_faces, ...
                                   'FaceVertexCData', signal_data, ...
                                   'FaceColor', 'interp', ...
                                   'EdgeColor', p.Results.EdgeColor, ...
                                   'EdgeAlpha', p.Results.EdgeAlpha, ...
                                   'FaceAlpha', p.Results.FaceAlpha, ...
                                   'LineWidth', 0.5);
                
                fprintf('  ✓ Surface signal mesh created with %d faces\n', size(obj.graph_faces, 1));
                
            else
                % Fallback: create surface using triangulation
                fprintf('  ℹ No face connectivity available, creating triangulation...\n');
                
                if size(obj.graph_coords, 1) >= 4
                    % Create Delaunay triangulation for surface approximation
                    tri = delaunayTriangulation(obj.graph_coords);
                    
                    % Get the convex hull (outer surface)
                    faces = convexHull(tri);
                    
                    patch_handle = patch('Vertices', obj.graph_coords, ...
                                       'Faces', faces, ...
                                       'FaceVertexCData', signal_data, ...
                                       'FaceColor', 'interp', ...
                                       'EdgeColor', p.Results.EdgeColor, ...
                                       'EdgeAlpha', p.Results.EdgeAlpha, ...
                                       'FaceAlpha', p.Results.FaceAlpha, ...
                                       'LineWidth', 0.5);
                    
                    fprintf('  ✓ Surface signal created via convex hull: %d faces\n', size(faces, 1));
                else
                    error('Insufficient vertices for surface mesh creation');
                end
            end
            
            % Apply shading (validate MATLAB shading options)
            valid_shading = {'flat', 'interp', 'faceted'};
            if ismember(lower(p.Results.Shading), valid_shading)
                shading(p.Results.Shading);
            elseif strcmpi(p.Results.Shading, 'gouraud')
                shading interp; % gouraud is equivalent to interp in modern MATLAB
            else
                shading interp; % default fallback
            end
            
            % Set colormap and color limits
            colormap(p.Results.Colormap);
            caxis(signal_range);
            
            % Set up lighting if requested
            if p.Results.Lighting
                lighting gouraud;
                camlight('headlight');
                material dull;
            end
            
            % Set view and axis properties
            axis equal;
            grid on;
            xlabel('X coordinate', 'FontSize', 12);
            ylabel('Y coordinate', 'FontSize', 12);
            zlabel('Z coordinate', 'FontSize', 12);
            view(p.Results.ViewAngle);
            
            % Add colorbar if requested
            if p.Results.ShowColorbar
                cb = colorbar;
                ylabel(cb, sprintf('Signal "%s" Amplitude', p.Results.SignalName), 'FontSize', 12);
            end
            
            % Set title
            if isempty(p.Results.Title)
                if p.Results.TimeIndex > 1
                    title_str = sprintf('Surface Signal: %s (t=%d)', p.Results.SignalName, p.Results.TimeIndex);
                else
                    title_str = sprintf('Surface Signal: %s', p.Results.SignalName);
                end
            else
                title_str = p.Results.Title;
            end
            title(title_str, 'FontSize', 14, 'FontWeight', 'bold');
            
            % Add informational text if requested
            if p.Results.ShowInfo
                info_text = sprintf('Surface Signal: %d vertices | %d faces | Range: [%.3g, %.3g]', ...
                    obj.graph_N, size(obj.graph_faces, 1), signal_range(1), signal_range(2));
                
                if strcmp(obj.data_source, 'file')
                    [~, filename, ~] = fileparts(obj.file_path);
                    info_text = sprintf('%s | File: %s', info_text, filename);
                end
                
                text(0.02, 0.02, info_text, 'Units', 'normalized', ...
                    'VerticalAlignment', 'bottom', 'FontSize', 10, ...
                    'BackgroundColor', 'white', 'EdgeColor', 'black');
            end
            
            hold off;
            
            fprintf('✓ Surface signal plot created successfully\n');
        end
        
        function fig = plotMultipanel(obj, plot_specs, varargin)
            % PLOTMULTIPANEL Create multipanel figure with BioctreePlotter components
            %
            % This function creates a single figure with multiple subplots, where each
            % subplot contains a different BioctreePlotter visualization. This allows
            % for comprehensive analysis displays combining spatial, temporal, and
            % spectral views of the data.
            %
            % Usage:
            %   fig = plotMultipanel(plot_specs)
            %   fig = plotMultipanel(plot_specs, 'param', value, ...)
            %
            % Inputs:
            %   plot_specs - Cell array of plot specifications, where each element is a struct:
            %     .type     - Plot type: 'wireframe', 'surface', 'signal', 'surfaceSignal', 'gft'
            %     .subplot  - Subplot position (e.g., [1,2,1] for subplot(1,2,1))
            %     .params   - Cell array of name-value parameters for the plot function
            %     .title    - Optional custom title for this subplot
            %
            % Parameters:
            %   'Figure'      - Figure handle to use (default: new figure)
            %   'FigureSize'  - Figure size [width, height] in pixels (default: [1400, 1000])
            %   'MainTitle'   - Main figure title (default: auto-generated)
            %   'TightLayout' - Use tight subplot layout (default: true)
            %   'ShowInfo'    - Show info panels on individual plots (default: false)
            %
            % Returns:
            %   fig - Figure handle
            %
            % Examples:
            %   % Simple 2-panel layout: surface signal + GFT
            %   specs = {
            %       struct('type', 'surfaceSignal', 'subplot', [1,2,1], ...
            %              'params', {{'SignalName', 'signal_patch_15_pct'}}), ...
            %       struct('type', 'gft', 'subplot', [1,2,2], ...
            %              'params', {{'SignalName', 'signal_patch_15_pct'}})
            %   };
            %   fig = plotter.plotMultipanel(specs);
            %
            %   % Complex 4-panel layout with custom titles
            %   specs = {
            %       struct('type', 'wireframe', 'subplot', [2,2,1], ...
            %              'title', 'Graph Structure', 'params', {{}}), ...
            %       struct('type', 'surface', 'subplot', [2,2,2], ...
            %              'title', 'Surface Mesh', 'params', {{}}), ...
            %       struct('type', 'surfaceSignal', 'subplot', [2,2,3], ...
            %              'title', 'Signal Distribution', ...
            %              'params', {{'SignalName', 'signal_patch_15_pct'}}), ...
            %       struct('type', 'gft', 'subplot', [2,2,4], ...
            %              'title', 'Frequency Analysis', ...
            %              'params', {{'SignalName', 'signal_patch_15_pct'}})
            %   };
            %   fig = plotter.plotMultipanel(specs, 'MainTitle', 'Comprehensive Analysis');
            
            % Parse input parameters
            p = inputParser;
            addRequired(p, 'plot_specs', @(x) iscell(x) && all(cellfun(@isstruct, x)));
            addParameter(p, 'Figure', [], @(x) isa(x, 'matlab.ui.Figure') || isempty(x));
            addParameter(p, 'FigureSize', [1400, 1000], @(x) isnumeric(x) && length(x) == 2);
            addParameter(p, 'MainTitle', '', @(x) ischar(x) || isstring(x));
            addParameter(p, 'TightLayout', true, @islogical);
            addParameter(p, 'ShowInfo', false, @islogical);
            parse(p, plot_specs, varargin{:});
            
            % Validate plot specifications
            valid_types = {'wireframe', 'surface', 'signal', 'surfaceSignal', 'gft'};
            for i = 1:length(plot_specs)
                spec = plot_specs{i};
                if ~isfield(spec, 'type') || ~ismember(spec.type, valid_types)
                    error('BioctreePlotter:InvalidPlotType', ...
                        'Plot spec %d must have valid type: %s', i, strjoin(valid_types, ', '));
                end
                if ~isfield(spec, 'subplot') || ~isnumeric(spec.subplot) || length(spec.subplot) ~= 3
                    error('BioctreePlotter:InvalidSubplot', ...
                        'Plot spec %d must have subplot position [rows, cols, index]', i);
                end
                if ~isfield(spec, 'params')
                    spec.params = {};
                end
            end
            
            % Create or use specified figure
            if isempty(p.Results.Figure)
                fig = figure('Name', 'Bioctree Multipanel Analysis', ...
                           'Position', [100, 100, p.Results.FigureSize], ...
                           'Color', 'white');
            else
                fig = p.Results.Figure;
                figure(fig);
                clf;
            end
            
            % Set main title
            if isempty(p.Results.MainTitle)
                if strcmp(obj.data_source, 'file')
                    [~, filename, ~] = fileparts(obj.file_path);
                    main_title = sprintf('Bioctree Analysis: %s', filename);
                else
                    main_title = 'Bioctree Multipanel Analysis';
                end
            else
                main_title = p.Results.MainTitle;
            end
            
            fprintf('Creating multipanel figure with %d plots...\n', length(plot_specs));
            
            % Create each subplot
            for i = 1:length(plot_specs)
                spec = plot_specs{i};
                
                % Create subplot
                subplot(spec.subplot(1), spec.subplot(2), spec.subplot(3));
                
                fprintf('  Panel %d: %s plot in subplot(%d,%d,%d)...\n', ...
                    i, spec.type, spec.subplot(1), spec.subplot(2), spec.subplot(3));
                
                % Prepare parameters for the plot function
                plot_params = spec.params;
                
                % Add ShowInfo parameter based on global setting
                if ~any(strcmpi(plot_params(1:2:end), 'ShowInfo'))
                    plot_params = [plot_params, {'ShowInfo', p.Results.ShowInfo}];
                end
                
                % Disable automatic figure creation by passing current figure
                plot_params = [plot_params, {'Figure', fig}];
                
                try
                    % Call appropriate plotting method
                    switch spec.type
                        case 'wireframe'
                            obj.plotWireframe(plot_params{:});
                            
                        case 'surface'
                            obj.plotSurface(plot_params{:});
                            
                        case 'signal'
                            obj.plotSignal(plot_params{:});
                            
                        case 'surfaceSignal'
                            obj.plotSurfaceSignal(plot_params{:});
                            
                        case 'gft'
                            % GFT plot has its own subplot structure, need special handling
                            obj.plotGraphFourierTransformPanel(plot_params{:});
                    end
                    
                    % Set custom title if provided
                    if isfield(spec, 'title') && ~isempty(spec.title)
                        title(spec.title, 'FontSize', 12, 'FontWeight', 'bold');
                    end
                    
                    fprintf('    ✓ %s plot completed\n', spec.type);
                    
                catch ME
                    fprintf('    ✗ %s plot failed: %s\n', spec.type, ME.message);
                    
                    % Create error placeholder
                    text(0.5, 0.5, sprintf('Error: %s\n%s', spec.type, ME.message), ...
                        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'middle', 'FontSize', 10, 'Color', 'red');
                    axis off;
                end
            end
            
            % Set main title
            sgtitle(main_title, 'FontSize', 16, 'FontWeight', 'bold');
            
            % Adjust layout if requested
            if p.Results.TightLayout
                % Use tight layout for better spacing
                set(fig, 'Units', 'normalized');
                
                % Add some padding around the plots
                for i = 1:length(plot_specs)
                    spec = plot_specs{i};
                    subplot(spec.subplot(1), spec.subplot(2), spec.subplot(3));
                    
                    % Get current position and add some padding
                    pos = get(gca, 'Position');
                    padding = 0.02;
                    pos(1) = pos(1) + padding/2;
                    pos(2) = pos(2) + padding/2;
                    pos(3) = pos(3) - padding;
                    pos(4) = pos(4) - padding;
                    set(gca, 'Position', pos);
                end
            end
            
            fprintf('✓ Multipanel figure created successfully\n');
        end
        
        function plotGraphFourierTransformPanel(obj, varargin)
            % PLOTGRAPHFOURIERTRANSFORMPANEL Plot GFT in a single panel (for multipanel use)
            %
            % This is a simplified version of plotGraphFourierTransform designed
            % for use within multipanel layouts. It creates a single plot instead
            % of the complex subplot structure used by the full GFT method.
            %
            % Parameters: Same as plotGraphFourierTransform but creates single panel
            
            % Parse input parameters (subset of full GFT parameters)
            p = inputParser;
            addParameter(p, 'SignalName', 'signal', @(x) ischar(x) || isstring(x));
            addParameter(p, 'TimeIndex', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
            addParameter(p, 'PlotType', 'stem', @(x) any(validatestring(x, {'stem', 'bar', 'line'})));
            addParameter(p, 'Colormap', 'turbo', @(x) ischar(x) || isstring(x));
            addParameter(p, 'ShowEigenvalues', true, @islogical);
            addParameter(p, 'LogScale', false, @islogical);
            addParameter(p, 'Normalize', true, @islogical);
            addParameter(p, 'HighlightLowFreq', true, @islogical);
            addParameter(p, 'NumFreqBands', 10, @(x) isnumeric(x) && isscalar(x) && x > 0);
            addParameter(p, 'ComputeBasis', false, @islogical);
            addParameter(p, 'Verbose', false, @islogical);
            addParameter(p, 'Figure', [], @(x) isa(x, 'matlab.ui.Figure') || isempty(x));
            addParameter(p, 'ShowInfo', true, @islogical);
            parse(p, varargin{:});
            
            % Ensure data is loaded
            if ~obj.is_loaded
                error('BioctreePlotter:DataNotLoaded', ...
                    'Graph data not loaded. Cannot compute GFT.');
            end
            
            try
                % Compute GFT using gftH5 function
                if strcmp(obj.data_source, 'file')
                    [gft_data, analysis_info] = gftH5(obj.file_path, ...
                        'SignalName', p.Results.SignalName, ...
                        'TimeIndex', p.Results.TimeIndex, ...
                        'ComputeBasis', p.Results.ComputeBasis, ...
                        'Verbose', p.Results.Verbose);
                else
                    [gft_data, analysis_info] = gftH5(obj.data_struct, ...
                        'SignalName', p.Results.SignalName, ...
                        'TimeIndex', p.Results.TimeIndex, ...
                        'ComputeBasis', p.Results.ComputeBasis, ...
                        'Verbose', p.Results.Verbose);
                end
                
            catch ME
                % Create error display in current axes
                text(0.5, 0.5, sprintf('GFT Error:\n%s', ME.message), ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', 'FontSize', 10, 'Color', 'red');
                axis off;
                return;
            end
            
            % Extract GFT data
            X_gft = gft_data.X_gft;
            eigenvalues = gft_data.eigenvalues;
            spectral_energy = gft_data.spectral_energy;
            
            % Handle time dimension
            if size(X_gft, 2) > 1
                energy_plot = spectral_energy(:, 1);
            else
                energy_plot = spectral_energy;
            end
            
            % Normalize if requested
            if p.Results.Normalize
                energy_plot = energy_plot / max(energy_plot);
            end
            
            % Create x-axis data
            N = length(eigenvalues);
            if p.Results.ShowEigenvalues
                x_data = eigenvalues;
                x_label = 'Graph Eigenvalues';
            else
                x_data = 1:N;
                x_label = 'Frequency Index';
            end
            
            % Create plot based on type
            switch p.Results.PlotType
                case 'stem'
                    stem(x_data, energy_plot, 'filled', 'LineWidth', 1.5);
                case 'bar'
                    bar(x_data, energy_plot, 'EdgeColor', 'none');
                case 'line'
                    plot(x_data, energy_plot, 'LineWidth', 2);
                    hold on;
                    scatter(x_data, energy_plot, 36, energy_plot, 'filled');
                    hold off;
            end
            
            % Highlight low frequency components
            if p.Results.HighlightLowFreq
                hold on;
                low_freq_idx = 1:min(p.Results.NumFreqBands, N);
                if p.Results.ShowEigenvalues
                    highlight_x = eigenvalues(low_freq_idx);
                else
                    highlight_x = low_freq_idx;
                end
                highlight_y = energy_plot(low_freq_idx);
                scatter(highlight_x, highlight_y, 60, 'red', 'filled', 'MarkerEdgeColor', 'black');
                hold off;
            end
            
            % Set plot properties
            xlabel(x_label, 'FontSize', 11);
            if p.Results.Normalize
                ylabel('Normalized Energy', 'FontSize', 11);
            else
                ylabel('Spectral Energy', 'FontSize', 11);
            end
            
            if p.Results.LogScale
                set(gca, 'YScale', 'log');
            end
            
            grid on;
            colormap(p.Results.Colormap);
            
            % Add minimal info if requested
            if p.Results.ShowInfo
                total_energy = sum(energy_plot);
                low_freq_energy = sum(energy_plot(1:min(round(N/10), N)));
                info_text = sprintf('Low freq: %.1f%%', 100*low_freq_energy/total_energy);
                text(0.98, 0.98, info_text, 'Units', 'normalized', ...
                    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                    'FontSize', 9, 'BackgroundColor', 'white', 'EdgeColor', 'black');
            end
        end
        
        function fig = plotGraphFourierTransform(obj, varargin)
            % PLOTGRAPHFOURIERTRANSFORM Plot Graph Fourier Transform spectrum
            %
            % This function computes and plots the Graph Fourier Transform (GFT) 
            % of signals stored in the BioctreePlotter data source, displaying
            % spectral energy distribution across graph frequencies.
            %
            % Usage:
            %   fig = plotGraphFourierTransform()
            %   fig = plotGraphFourierTransform('param', value, ...)
            %
            % Parameters:
            %   'Figure'       - Figure handle to plot in (default: new figure)
            %   'SignalName'   - Signal to analyze (default: 'signal')
            %   'TimeIndex'    - Time index for temporal signals (default: 1)
            %   'PlotType'     - 'stem', 'bar', 'line' (default: 'stem')
            %   'Colormap'     - Colormap for frequency coloring (default: 'viridis')
            %   'ShowEigenvalues' - Show eigenvalues on x-axis (default: true)
            %   'LogScale'     - Use log scale for y-axis (default: false)
            %   'Normalize'    - Normalize spectral energy (default: true)
            %   'HighlightLowFreq' - Highlight low frequency components (default: true)
            %   'NumFreqBands' - Number of frequency bands to highlight (default: 10)
            %   'Title'        - Plot title (default: auto-generated)
            %   'ComputeBasis' - Force recomputation of Fourier basis (default: false)
            %   'Verbose'      - Display computation details (default: false)
            %
            % Returns:
            %   fig - Figure handle
            %
            % The function will:
            %   1. Load or compute the graph Fourier basis (eigenvectors)
            %   2. Compute the GFT of the specified signal
            %   3. Display spectral energy vs. graph frequencies
            %   4. Optionally save Fourier basis back to HDF5 file
            %
            % Dependencies:
            %   - GSPBox for graph Fourier computations
            %   - gftH5 function for HDF5-based GFT analysis
            
            % Parse input parameters
            p = inputParser;
            addParameter(p, 'Figure', [], @(x) isa(x, 'matlab.ui.Figure') || isempty(x));
            addParameter(p, 'SignalName', 'signal', @(x) ischar(x) || isstring(x));
            addParameter(p, 'TimeIndex', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
            addParameter(p, 'PlotType', 'stem', @(x) any(validatestring(x, {'stem', 'bar', 'line'})));
            addParameter(p, 'Colormap', 'turbo', @(x) ischar(x) || isstring(x));
            addParameter(p, 'ShowEigenvalues', true, @islogical);
            addParameter(p, 'LogScale', false, @islogical);
            addParameter(p, 'Normalize', true, @islogical);
            addParameter(p, 'HighlightLowFreq', true, @islogical);
            addParameter(p, 'NumFreqBands', 10, @(x) isnumeric(x) && isscalar(x) && x > 0);
            addParameter(p, 'Title', '', @(x) ischar(x) || isstring(x));
            addParameter(p, 'ComputeBasis', false, @islogical);
            addParameter(p, 'Verbose', false, @islogical);
            parse(p, varargin{:});
            
            % Ensure data is loaded
            if ~obj.is_loaded
                error('BioctreePlotter:DataNotLoaded', ...
                    'Graph data not loaded. Cannot compute GFT.');
            end
            
            fprintf('Computing Graph Fourier Transform for signal "%s"...\n', p.Results.SignalName);
            
            % Create or use specified figure
            if isempty(p.Results.Figure)
                fig = figure('Name', 'Bioctree Graph Fourier Transform', ...
                           'Position', [100, 100, 1000, 700]);
                % Clear current axes only for new figures
                clf;
            else
                fig = p.Results.Figure;
                figure(fig);
                % Don't clear - we might be in a subplot
            end
            
            try
                % Compute GFT using gftH5 function
                if strcmp(obj.data_source, 'file')
                    % Use HDF5 file for computation
                    [gft_data, analysis_info] = gftH5(obj.file_path, ...
                        'SignalName', p.Results.SignalName, ...
                        'TimeIndex', p.Results.TimeIndex, ...
                        'ComputeBasis', p.Results.ComputeBasis, ...
                        'Verbose', p.Results.Verbose);
                else
                    % Use in-memory data structure
                    [gft_data, analysis_info] = gftH5(obj.data_struct, ...
                        'SignalName', p.Results.SignalName, ...
                        'TimeIndex', p.Results.TimeIndex, ...
                        'ComputeBasis', p.Results.ComputeBasis, ...
                        'Verbose', p.Results.Verbose);
                end
                
                fprintf('✓ GFT computation completed\n');
                
            catch ME
                error('BioctreePlotter:GFTError', ...
                    'Failed to compute GFT: %s', ME.message);
            end
            
            % Extract GFT data
            X_gft = gft_data.X_gft;
            eigenvalues = gft_data.eigenvalues;
            spectral_energy = gft_data.spectral_energy;
            
            % Handle time dimension for plotting
            if size(X_gft, 2) > 1
                % Multiple time points - use specified time index
                energy_plot = spectral_energy(:, 1);
                fprintf('Note: Plotting GFT for time index 1 (of %d available)\n', size(X_gft, 2));
            else
                energy_plot = spectral_energy;
            end
            
            % Normalize if requested
            if p.Results.Normalize
                energy_plot = energy_plot / max(energy_plot);
                energy_label = 'Normalized Spectral Energy';
            else
                energy_label = 'Spectral Energy';
            end
            
            % Create subplot layout
            subplot(2, 2, [1, 2]); % Top panel - main spectral plot
            
            % Create x-axis (frequency index or eigenvalues)
            N = length(eigenvalues);
            freq_indices = 1:N;
            
            if p.Results.ShowEigenvalues
                x_data = eigenvalues;
                x_label = 'Graph Eigenvalues (Frequency)';
            else
                x_data = freq_indices;
                x_label = 'Frequency Index';
            end
            
            % Create main spectral plot
            switch p.Results.PlotType
                case 'stem'
                    stem_handle = stem(x_data, energy_plot, 'filled', 'LineWidth', 1.5);
                    
                case 'bar'
                    bar(x_data, energy_plot, 'EdgeColor', 'none');
                    
                case 'line'
                    plot(x_data, energy_plot, 'LineWidth', 2);
                    hold on;
                    scatter(x_data, energy_plot, 36, energy_plot, 'filled');
                    hold off;
            end
            
            % Apply colormap
            if exist('stem_handle', 'var')
                % Color stem plot based on energy values
                colormap(p.Results.Colormap);
                stem_colors = colormap;
                energy_normalized = energy_plot / max(energy_plot);
                color_indices = round(energy_normalized * (size(stem_colors, 1) - 1)) + 1;
                
                % Set colors for each stem
                for i = 1:length(energy_plot)
                    stem_handle.MarkerFaceColor = stem_colors(color_indices(i), :);
                end
            elseif exist('bar_handle', 'var')
                colormap(p.Results.Colormap);
            end
            
            % Highlight low frequency components if requested
            if p.Results.HighlightLowFreq
                hold on;
                low_freq_idx = 1:min(p.Results.NumFreqBands, N);
                if p.Results.ShowEigenvalues
                    highlight_x = eigenvalues(low_freq_idx);
                else
                    highlight_x = low_freq_idx;
                end
                highlight_y = energy_plot(low_freq_idx);
                
                scatter(highlight_x, highlight_y, 100, 'red', 'filled', 'MarkerEdgeColor', 'black');
                hold off;
            end
            
            % Set axis properties
            xlabel(x_label, 'FontSize', 12);
            ylabel(energy_label, 'FontSize', 12);
            
            if p.Results.LogScale
                set(gca, 'YScale', 'log');
            end
            
            grid on;
            
            % Set title
            if isempty(p.Results.Title)
                if p.Results.TimeIndex > 1
                    title_str = sprintf('Graph Fourier Transform: %s (t=%d)', p.Results.SignalName, p.Results.TimeIndex);
                else
                    title_str = sprintf('Graph Fourier Transform: %s', p.Results.SignalName);
                end
            else
                title_str = p.Results.Title;
            end
            title(title_str, 'FontSize', 14, 'FontWeight', 'bold');
            
            % Add colorbar for energy visualization
            cb = colorbar;
            ylabel(cb, energy_label, 'FontSize', 11);
            
            % Bottom left - Low frequency detail
            subplot(2, 2, 3);
            low_detail_idx = 1:min(20, N);
            if p.Results.ShowEigenvalues
                low_x = eigenvalues(low_detail_idx);
            else
                low_x = low_detail_idx;
            end
            low_y = energy_plot(low_detail_idx);
            
            stem(low_x, low_y, 'filled', 'Color', [0.8 0.2 0.2], 'LineWidth', 1.5);
            xlabel(x_label, 'FontSize', 10);
            ylabel(energy_label, 'FontSize', 10);
            title('Low Frequency Detail', 'FontSize', 12);
            grid on;
            
            % Bottom right - Statistics and information
            subplot(2, 2, 4);
            axis off;
            
            % Compute spectral statistics
            total_energy = sum(energy_plot);
            low_freq_energy = sum(energy_plot(1:min(round(N/10), N)));
            high_freq_energy = sum(energy_plot(max(1, round(9*N/10)):end));
            
            % Find peak frequency
            [max_energy, peak_idx] = max(energy_plot);
            if p.Results.ShowEigenvalues
                peak_freq = eigenvalues(peak_idx);
                freq_unit = sprintf('λ = %.4f', peak_freq);
            else
                peak_freq = peak_idx;
                freq_unit = sprintf('index %d', peak_freq);
            end
            
            % Create info text
            info_lines = {
                sprintf('\\bf{Signal:} %s', p.Results.SignalName);
                sprintf('\\bf{Graph:} %d vertices', analysis_info.graph_info.N);
                sprintf('\\bf{Eigenvalue range:} [%.4f, %.4f]', ...
                    analysis_info.graph_info.eigenvalue_range);
                '';
                sprintf('\\bf{Spectral Statistics:}');
                sprintf('Total energy: %.4g', total_energy);
                sprintf('Low freq (10%%): %.1f%%', 100*low_freq_energy/total_energy);
                sprintf('High freq (10%%): %.1f%%', 100*high_freq_energy/total_energy);
                '';
                sprintf('\\bf{Peak frequency:} %s', freq_unit);
                sprintf('Peak energy: %.4g', max_energy);
                '';
                sprintf('\\bf{Computation time:} %.3f s', analysis_info.computation_time.total);
                sprintf('\\bf{GFT time:} %.3f s', analysis_info.computation_time.gft_computation);
            };
            
            % Display info text
            text(0.05, 0.95, info_lines, 'Units', 'normalized', ...
                'VerticalAlignment', 'top', 'FontSize', 10, ...
                'Interpreter', 'tex');
            
            % Add source information
            if strcmp(obj.data_source, 'file')
                [~, filename, ~] = fileparts(obj.file_path);
                source_text = sprintf('Source: %s', filename);
            else
                source_text = 'Source: Data structure';
            end
            
            text(0.05, 0.02, source_text, 'Units', 'normalized', ...
                'VerticalAlignment', 'bottom', 'FontSize', 9, ...
                'FontAngle', 'italic');
            
            % Adjust layout
            sgtitle(sprintf('Graph Fourier Analysis: %s', p.Results.SignalName), ...
                'FontSize', 16, 'FontWeight', 'bold');
            
            fprintf('✓ Graph Fourier Transform plot created successfully\n');
            fprintf('  Signal energy concentrated in %d frequencies (%.1f%% in lowest 10%%)\n', ...
                sum(energy_plot > 0.01*max(energy_plot)), 100*low_freq_energy/total_energy);
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
                    
                    % Try to load face connectivity from HDF5
                    try
                        obj.graph_faces = h5read(obj.file_path, '/graph/faces');
                        fprintf('  ✓ Loaded %d faces from HDF5 file\n', size(obj.graph_faces, 1));
                    catch
                        obj.graph_faces = [];
                        fprintf('  ℹ No face connectivity found in HDF5 file\n');
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
                        
                        % Load face data if available
                        if isfield(obj.data_struct.graph, 'F')
                            obj.graph_faces = obj.data_struct.graph.F;
                        elseif isfield(obj.data_struct.graph, 'faces')
                            obj.graph_faces = obj.data_struct.graph.faces;
                        else
                            obj.graph_faces = [];
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
                        
                        % Load face data if available
                        if isfield(obj.data_struct.G, 'F')
                            obj.graph_faces = obj.data_struct.G.F;
                        elseif isfield(obj.data_struct.G, 'faces')
                            obj.graph_faces = obj.data_struct.G.faces;
                        else
                            obj.graph_faces = [];
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
                        elseif isfield(obj.data_struct, 'E') && ~isempty(obj.data_struct.E)
                            % Use existing edge list
                            obj.graph_edges = obj.data_struct.E;
                        else
                            obj.createEdgesFromCoords();
                        end
                        
                        % Load face data if available (for icosphere and other triangular meshes)
                        if isfield(obj.data_struct, 'F') && ~isempty(obj.data_struct.F)
                            obj.graph_faces = obj.data_struct.F;
                            fprintf('  ✓ Loaded %d faces from graph structure\n', size(obj.graph_faces, 1));
                        elseif isfield(obj.data_struct, 'faces') && ~isempty(obj.data_struct.faces)
                            obj.graph_faces = obj.data_struct.faces;
                            fprintf('  ✓ Loaded %d faces from graph structure\n', size(obj.graph_faces, 1));
                        else
                            obj.graph_faces = [];
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