classdef TailwindPlotPanel < Component
    %TailwindPlotPanel Wrapper for Tailwind-based PlotPanel component
    %
    %   Provides MATLAB interface for the Tailwind PlotPanel HTML component.
    %   This version is portable and not tied to the +bct package structure.
    %
    %   Location: ui/matlab/TailwindPlotPanel.m
    %
    %   Usage:
    %       % Add ui/matlab to path
    %       addpath('ui/matlab');
    %       
    %       % In App Designer or figure
    %       app.PlotPanel = TailwindPlotPanel(app, app.HTMLPlotPanel);
    %       app.PlotPanel.plotMesh(vertices, faces);
    %
    %   See also: Component, TailwindToolstrip, TailwindSidebar
    
    properties (Access = public)
        InteractionMode = 'rotate'  % 'rotate', 'pan', 'zoom', 'select'
        PlotType = ''               % 'mesh', 'signal', 'spectrum'
    end
    
    properties (Access = private)
        CurrentData = struct()      % Cache of current plot data
    end
    
    methods
        function obj = TailwindPlotPanel(app, htmlControl)
            % Call superclass constructor
            obj@Component(app, htmlControl, 'plotpanel');
            
            % Set path to Tailwind components directory
            % Find ui directory relative to this file
            thisFile = mfilename('fullpath');
            matlabDir = fileparts(thisFile);  % ui/matlab
            uiDir = fileparts(matlabDir);      % ui
            obj.HTMLPath = fullfile(uiDir, 'tailwind', 'components');
            
            % Load HTML
            obj.loadHTML('plotpanel.html');
        end
        
        function plotMesh(obj, vertices, faces, varargin)
            p = inputParser;
            addRequired(p, 'vertices', @(x) ismatrix(x) && size(x,2) == 3);
            addRequired(p, 'faces', @(x) ismatrix(x) && size(x,2) == 3);
            addParameter(p, 'Signal', [], @isnumeric);
            addParameter(p, 'Alpha', 1, @(x) isscalar(x) && x >= 0 && x <= 1);
            parse(p, vertices, faces, varargin{:});
            
            % Store data
            obj.CurrentData.vertices = vertices;
            obj.CurrentData.faces = faces;
            obj.CurrentData.signal = p.Results.Signal;
            obj.CurrentData.alpha = p.Results.Alpha;
            obj.PlotType = 'mesh';
            
            % Send to JavaScript
            msg = struct('cmd', 'plotMesh', ...
                'vertices', vertices, ...
                'faces', faces);
            
            if ~isempty(p.Results.Signal)
                msg.signal = p.Results.Signal;
            end
            if p.Results.Alpha ~= 1
                msg.alpha = p.Results.Alpha;
            end
            
            obj.send(msg);
        end
        
        function plotSignal(obj, data, varargin)
            p = inputParser;
            addRequired(p, 'data', @isnumeric);
            addParameter(p, 'XData', [], @isnumeric);
            addParameter(p, 'Title', '', @ischar);
            addParameter(p, 'XLabel', '', @ischar);
            addParameter(p, 'YLabel', '', @ischar);
            parse(p, data, varargin{:});
            
            % Store data
            obj.CurrentData.data = data;
            obj.CurrentData.xdata = p.Results.XData;
            obj.PlotType = 'signal';
            
            % Send to JavaScript
            msg = struct('cmd', 'plotSignal', 'data', data);
            
            if ~isempty(p.Results.XData)
                msg.xdata = p.Results.XData;
            end
            if ~isempty(p.Results.Title)
                msg.title = p.Results.Title;
            end
            if ~isempty(p.Results.XLabel)
                msg.xlabel = p.Results.XLabel;
            end
            if ~isempty(p.Results.YLabel)
                msg.ylabel = p.Results.YLabel;
            end
            
            obj.send(msg);
        end
        
        function plotSpectrum(obj, frequencies, magnitudes, varargin)
            p = inputParser;
            addRequired(p, 'frequencies', @isnumeric);
            addRequired(p, 'magnitudes', @isnumeric);
            addParameter(p, 'LogScale', false, @islogical);
            parse(p, frequencies, magnitudes, varargin{:});
            
            % Store data
            obj.CurrentData.frequencies = frequencies;
            obj.CurrentData.magnitudes = magnitudes;
            obj.PlotType = 'spectrum';
            
            % Send to JavaScript
            msg = struct('cmd', 'plotSpectrum', ...
                'frequencies', frequencies, ...
                'magnitudes', magnitudes);
            
            if p.Results.LogScale
                msg.logScale = true;
            end
            
            obj.send(msg);
        end
        
        function clear(obj)
            obj.CurrentData = struct();
            obj.PlotType = '';
            obj.send(struct('cmd', 'clear'));
        end
        
        function resetView(obj)
            obj.send(struct('cmd', 'resetView'));
        end
        
        function setMode(obj, mode)
            assert(ismember(mode, {'rotate', 'pan', 'zoom', 'select'}), ...
                'Mode must be rotate, pan, zoom, or select');
            
            obj.InteractionMode = mode;
            obj.send(struct('cmd', 'setMode', 'mode', mode));
        end
        
        function exportImage(obj, filename)
            obj.send(struct('cmd', 'exportImage', 'filename', filename));
        end
        
        function onMessage(obj, data)
            switch data.cmd
                case 'vertexSelected'
                    % Call app callback if it exists
                    if ismethod(obj.App, 'onVertexSelected')
                        try
                            obj.App.onVertexSelected(data.vertexIndex);
                        catch ME
                            warning('TailwindPlotPanel:CallbackError', ...
                                'Error executing onVertexSelected: %s', ME.message);
                        end
                    end
                    
                case 'regionSelected'
                    % Call app callback if it exists
                    if ismethod(obj.App, 'onRegionSelected')
                        try
                            obj.App.onRegionSelected(data.vertices);
                        catch ME
                            warning('TailwindPlotPanel:CallbackError', ...
                                'Error executing onRegionSelected: %s', ME.message);
                        end
                    end
                    
                case 'imageExported'
                    % Notify successful export
                    if ismethod(obj.App, 'onImageExported')
                        try
                            obj.App.onImageExported(data.filename);
                        catch ME
                            warning('TailwindPlotPanel:CallbackError', ...
                                'Error executing onImageExported: %s', ME.message);
                        end
                    end
                    
                otherwise
                    warning('TailwindPlotPanel:UnknownCommand', 'Unknown command: %s', data.cmd);
            end
        end
    end
end
