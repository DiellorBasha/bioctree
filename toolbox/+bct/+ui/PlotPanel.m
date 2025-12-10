classdef PlotPanel < bct.ui.Component
    %PLOTPANEL HTML-based plot panel component for BCT visualizations
    %
    %   The PlotPanel provides an interactive canvas for displaying
    %   3D meshes, signals, spectral data, and other visualizations
    %   using HTML5 Canvas and JavaScript libraries like D3.js or Three.js.
    %
    %   Properties:
    %       PlotType        - Type of plot (mesh, signal, spectrum, etc.)
    %       ViewOptions     - Struct with view configuration
    %       InteractionMode - Current interaction mode (rotate, pan, zoom)
    %
    %   Methods:
    %       plotMesh       - Display a 3D mesh
    %       plotSignal     - Display a signal on the mesh
    %       plotSpectrum   - Display spectral data
    %       clear          - Clear the plot
    %       setViewOptions - Set viewing options
    %       exportImage    - Export current view as image
    %       resetView      - Reset camera to default position
    %
    %   Example:
    %       % In App Designer:
    %       app.PlotPanel = bct.ui.PlotPanel(app, app.HTMLPlot);
    %
    %       % Plot mesh data:
    %       app.PlotPanel.plotMesh(vertices, faces);
    %
    %       % Plot signal on mesh:
    %       app.PlotPanel.plotSignal(vertices, faces, signalData);
    %
    %   See also: bct.ui.Component, bct.ui.Toolstrip
    
    properties (Access = public)
        PlotType        % Type of plot being displayed
        ViewOptions     % View configuration
        InteractionMode % Interaction mode
    end
    
    methods
        function obj = PlotPanel(app, htmlComponent)
            %PLOTPANEL Construct a PlotPanel instance
            %
            %   obj = PlotPanel(app, htmlComponent) creates a plot panel
            %   component and loads its HTML interface.
            
            % Call superclass constructor
            obj@bct.ui.Component(app, htmlComponent, "PlotPanel");
            
            % Initialize properties
            obj.PlotType = 'none';
            obj.ViewOptions = struct(...
                'colormap', 'parula', ...
                'lighting', true, ...
                'showAxes', false, ...
                'background', [1 1 1]);
            obj.InteractionMode = 'rotate';
            
            % Load the HTML interface
            obj.loadHTML("plotpanel.html");
            
            % Send initial configuration
            obj.sendConfiguration();
        end
        
        function plotMesh(obj, vertices, faces, varargin)
            %PLOTMESH Display a 3D mesh
            %
            %   plotMesh(obj, vertices, faces) displays a mesh with
            %   the given vertices (Nx3) and faces (Mx3).
            %
            %   plotMesh(..., 'PropertyName', PropertyValue) specifies
            %   additional display properties.
            
            % Parse optional inputs
            p = inputParser;
            addParameter(p, 'FaceColor', [0.8 0.8 0.8]);
            addParameter(p, 'EdgeColor', 'none');
            addParameter(p, 'FaceAlpha', 1.0);
            parse(p, varargin{:});
            
            % Prepare data for JavaScript
            data = struct(...
                'vertices', vertices, ...
                'faces', faces, ...
                'faceColor', p.Results.FaceColor, ...
                'edgeColor', p.Results.EdgeColor, ...
                'faceAlpha', p.Results.FaceAlpha);
            
            obj.PlotType = 'mesh';
            obj.send(struct('cmd', 'plotMesh', 'data', data));
        end
        
        function plotSignal(obj, vertices, faces, signal, varargin)
            %PLOTSIGNAL Display a signal on a mesh
            %
            %   plotSignal(obj, vertices, faces, signal) displays a mesh
            %   with per-vertex signal values mapped to colors.
            
            % Parse optional inputs
            p = inputParser;
            addParameter(p, 'Colormap', 'parula');
            addParameter(p, 'CLim', [min(signal), max(signal)]);
            parse(p, varargin{:});
            
            % Prepare data for JavaScript
            data = struct(...
                'vertices', vertices, ...
                'faces', faces, ...
                'signal', signal, ...
                'colormap', p.Results.Colormap, ...
                'clim', p.Results.CLim);
            
            obj.PlotType = 'signal';
            obj.send(struct('cmd', 'plotSignal', 'data', data));
        end
        
        function plotSpectrum(obj, frequencies, values, varargin)
            %PLOTSPECTRUM Display spectral data
            %
            %   plotSpectrum(obj, frequencies, values) displays a
            %   spectrum plot.
            
            % Parse optional inputs
            p = inputParser;
            addParameter(p, 'LineColor', 'blue');
            addParameter(p, 'LineWidth', 2);
            parse(p, varargin{:});
            
            % Prepare data for JavaScript
            data = struct(...
                'frequencies', frequencies, ...
                'values', values, ...
                'lineColor', p.Results.LineColor, ...
                'lineWidth', p.Results.LineWidth);
            
            obj.PlotType = 'spectrum';
            obj.send(struct('cmd', 'plotSpectrum', 'data', data));
        end
        
        function clear(obj)
            %CLEAR Clear the plot
            
            obj.PlotType = 'none';
            obj.send(struct('cmd', 'clear'));
        end
        
        function setViewOptions(obj, options)
            %SETVIEWOPTIONS Set view configuration options
            %
            %   setViewOptions(obj, options) updates view options with
            %   the provided struct fields.
            
            fields = fieldnames(options);
            for i = 1:length(fields)
                obj.ViewOptions.(fields{i}) = options.(fields{i});
            end
            
            obj.send(struct('cmd', 'setViewOptions', 'options', obj.ViewOptions));
        end
        
        function exportImage(obj, filename)
            %EXPORTIMAGE Export current view as image
            %
            %   exportImage(obj, filename) saves the current plot view
            %   as an image file.
            
            if nargin < 2
                [file, path] = uiputfile({'*.png', 'PNG Image'}, ...
                    'Export Image');
                if isequal(file, 0)
                    return;
                end
                filename = fullfile(path, file);
            end
            
            obj.send(struct('cmd', 'exportImage', 'filename', filename));
        end
        
        function resetView(obj)
            %RESETVIEW Reset camera to default position
            
            obj.send(struct('cmd', 'resetView'));
        end
        
        function setInteractionMode(obj, mode)
            %SETINTERACTIONMODE Set interaction mode
            %
            %   setInteractionMode(obj, mode) sets the interaction mode
            %   ('rotate', 'pan', 'zoom', 'select').
            
            obj.InteractionMode = mode;
            obj.send(struct('cmd', 'setInteractionMode', 'mode', mode));
        end
        
        function onMessage(obj, data)
            %ONMESSAGE Handle messages from JavaScript
            
            if ~isfield(data, 'cmd')
                return;
            end
            
            cmd = data.cmd;
            
            switch cmd
                case "viewChanged"
                    obj.handleViewChanged(data);
                    
                case "meshClicked"
                    obj.handleMeshClicked(data.vertexId, data.position);
                    
                case "imageExported"
                    obj.handleImageExported(data.imageData, data.filename);
                    
                case "ready"
                    obj.sendConfiguration();
                    
                otherwise
                    warning('bct:ui:PlotPanel:UnknownCommand', ...
                        'Unknown command: %s', cmd);
            end
        end
    end
    
    methods (Access = private)
        function sendConfiguration(obj)
            %SENDCONFIGURATION Send configuration to JavaScript
            
            config = struct(...
                'plotType', obj.PlotType, ...
                'viewOptions', obj.ViewOptions, ...
                'interactionMode', obj.InteractionMode);
            
            obj.send(struct('cmd', 'configure', 'config', config));
        end
        
        function handleViewChanged(obj, data)
            %HANDLEVIEWCHANGED Handle view change notifications
            
            % Update view state if needed
            if isfield(data, 'camera')
                obj.State.camera = data.camera;
            end
            
            % Notify app if it has a handler
            if ismethod(obj.App, 'onPlotViewChanged')
                obj.App.onPlotViewChanged(data);
            end
        end
        
        function handleMeshClicked(obj, vertexId, position)
            %HANDLEMESHCLICKED Handle mesh click events
            
            % Notify app if it has a handler
            if ismethod(obj.App, 'onMeshClicked')
                obj.App.onMeshClicked(vertexId, position);
            end
        end
        
        function handleImageExported(obj, imageData, filename)
            %HANDLEIMAGEEXPORTED Handle image export from JavaScript
            
            try
                % Decode base64 image data
                img = matlab.net.base64decode(imageData);
                
                % Write to file
                fid = fopen(filename, 'w');
                fwrite(fid, img);
                fclose(fid);
                
                % Notify app
                if ismethod(obj.App, 'Console') && ...
                   ismethod(obj.App.Console, 'success')
                    obj.App.Console.success('Image exported: %s', filename);
                end
            catch ME
                warning('bct:ui:PlotPanel:ExportError', ...
                    'Image export failed: %s', ME.message);
            end
        end
    end
end
