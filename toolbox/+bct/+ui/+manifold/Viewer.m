classdef Viewer < matlab.ui.componentcontainer.ComponentContainer
    % Viewer - Manifold visualization component
    %
    % Minimal MATLAB ComponentContainer wrapper around the bct.ui.manifold.viewer
    % three.js implementation.
    %
    % This component:
    % - Loads the modular three.js viewer from +viewer/web/
    % - Supports GLB and JSON geometry loading
    % - Provides lil-gui visualization controls
    % - Handles coordinate frame transforms (MATLAB Z-up ↔ three.js Y-up)
    % - No explicit data passing (loads from assets)
    % - No callbacks (pure visualization)
    %
    % Intended usage (grid-layout driven sizing):
    %   fig  = uifigure('Position', [100 100 1200 800]);
    %   grid = uigridlayout(fig, [1 1]);
    %   grid.RowHeight    = {'1x'};
    %   grid.ColumnWidth  = {'1x'};
    %   v = bct.ui.manifold.Viewer(grid);
    %   v.Layout.Row = 1; 
    %   v.Layout.Column = 1;

    properties (Access = private, Transient, NonCopyable)
        HTMLComponent matlab.ui.control.HTML
    end
    
    properties (Access = private)
        Vertices (:,3) double = []
        Faces (:,3) uint32 = []
    end

    methods (Access = protected)
        function setup(comp)
            % Create the HTML component as a child of this container.
            comp.HTMLComponent = uihtml(comp);

            % Point to the viewer's index.html in +viewer/web/ subdirectory.
            comp.HTMLComponent.HTMLSource = bct.ui.manifold.Viewer.resolveHTMLSource();

            % Let the parent (e.g., uigridlayout) control sizing.
            % We will size the uihtml to fill this container in update().
            comp.update();
        end

        function update(comp)
            if isempty(comp.HTMLComponent) || ~isvalid(comp.HTMLComponent)
                return;
            end

            % Fill the ComponentContainer client area.
            % ComponentContainer Position is in pixels; in a uigridlayout the grid sets it.
            w = comp.Position(3);
            h = comp.Position(4);

            % Guard against transient 0-size states.
            if w < 2 || h < 2
                return;
            end

            comp.HTMLComponent.Position = [1 1 w h];
        end
    end

    methods (Access = private, Static)
        function htmlPath = resolveHTMLSource()
            % Resolve the absolute path to +viewer/web/index.html
            % Works in both development and packaged toolbox scenarios.
            classFile = mfilename('fullpath');
            classDir  = fileparts(classFile);
            htmlPath  = fullfile(classDir, '+viewer', 'web', 'index.html');
        end
    end
    
    methods (Access = public)
        function setMesh(comp, varargin)
            % setMesh - Set the mesh to display in the viewer
            %
            % Syntax:
            %   comp.setMesh(manifold)        % Use bct.Manifold object
            %   comp.setMesh(V, F)            % Vertices and faces only
            %   comp.setMesh(V, F, N)         % Vertices, faces, and normals
            %
            % Inputs:
            %   manifold - bct.Manifold object (normals computed automatically)
            %   V - Vertices matrix [N×3] double, MATLAB Z-up coordinates
            %   F - Faces matrix [M×3] uint32, 1-based indexing
            %   N - (Optional) Normals matrix [N×3] double, vertex normals
            %
            % Notes:
            %   - Vertices are expected in MATLAB Z-up coordinates
            %   - Faces are converted from 1-based to 0-based indexing
            %   - Arrays are flattened for JSON transfer
            %   - Updates HTMLComponent.Data to trigger JavaScript viewer
            %   - Pre-computed normals avoid expensive JavaScript computation
            %   - Lightweight construction: only sends mesh geometry
            %   - Use setScalar(), setVector() etc. to add visualizations later
            
            % Parse input arguments
            M_obj = [];
            if nargin == 2 && isa(varargin{1}, 'bct.Manifold')
                % Case 1: bct.Manifold object provided
                M_obj = varargin{1};
                V = M_obj.Vertices;   % Access property (not method)
                F = M_obj.Faces;      % Access property (not method)
                % Let JavaScript compute normals as fallback for now
                N = [];
            elseif nargin == 3
                % Case 2: V, F provided
                V = varargin{1};
                F = varargin{2};
                N = [];  % No normals provided
            elseif nargin == 4
                % Case 3: V, F, N provided
                V = varargin{1};
                F = varargin{2};
                N = varargin{3};
            else
                error('bct:ui:manifold:Viewer:InvalidInputs', ...
                    'Invalid inputs. Use setMesh(manifold) or setMesh(V,F) or setMesh(V,F,N).');
            end
            
            % Validate inputs
            validateattributes(V, {'double'}, {'real', 'finite', 'ncols', 3}, 'setMesh', 'V');
            validateattributes(F, {'numeric'}, {'integer', 'positive', 'ncols', 3}, 'setMesh', 'F');
            if ~isempty(N)
                validateattributes(N, {'double'}, {'real', 'finite', 'ncols', 3, 'nrows', size(V,1)}, 'setMesh', 'N');
            end
            
            % Convert faces to uint32 and ensure 1-based
            F = uint32(F);
            
            % Store mesh data
            comp.Vertices = V;
            comp.Faces = F;
            
            % Flatten vertices: [x1 y1 z1 x2 y2 z2 ...]
            % IMPORTANT: Use .' to transpose then reshape to preserve XYZ order
            verticesFlat = reshape(V.', 1, []);
            
            % Flatten faces and convert to 0-based indexing: [i1 i2 i3 ...] - 1
            facesFlat = double(reshape(F.', 1, [])) - 1;
            
            % Create mesh data payload
            meshData = struct(...
                'vertices', verticesFlat, ...
                'faces', facesFlat, ...
                'indexBase', 0, ...
                'frame', 'matlab' ...
            );
            
            % Add normals if provided
            if ~isempty(N)
                % Flatten normals: [nx1 ny1 nz1 nx2 ny2 nz2 ...]
                normalsFlat = reshape(N.', 1, []);
                meshData.normals = normalsFlat;
            end
            
            % Set HTMLComponent.Data to trigger DataChanged event in JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('mesh', meshData);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Mesh data stored but not sent.');
            end
        end
        
        function clearMesh(comp)
            % clearMesh - Clear the currently displayed mesh
            %
            % Syntax:
            %   comp.clearMesh()
            %
            % Notes:
            %   - Removes the mesh from the viewer
            %   - Clears any associated scalar visualization
            %   - Resets internal vertex/face storage
            
            % Clear internal storage
            comp.Vertices = [];
            comp.Faces = [];
            
            % Send clear command to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('clearMesh', true);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Clear command not sent.');
            end
        end
        
        function setScalar(comp, scalarData)
            % setScalar - Replace scalar field visualization (no blending)
            %
            % Syntax:
            %   comp.setScalar(scalarData)
            %
            % Inputs:
            %   scalarData - [N×1] vector of scalar values (one per vertex)
            %
            % Examples:
            %   % Visualize scalar field
            %   viewer.setScalar(scalarData);
            %
            %   % Clear scalar visualization
            %   viewer.setScalar([]);
            %
            % Notes:
            %   - This always REPLACES the existing scalar field
            %   - Use addScalar() with 'Mode' to blend/combine fields
            %   - Scalar data must match number of vertices from last setMesh call
            %   - Colormap can be changed via viewer UI controls
            %   - Call without arguments or empty array to clear visualization
            %
            % See also: addScalar, clearScalar
            
            arguments
                comp (1,1) bct.ui.manifold.Viewer
                scalarData (:,1) double = []
            end
            
            % Validate scalar data is real and finite if not empty
            if ~isempty(scalarData)
                if ~all(isfinite(scalarData))
                    error('bct:ui:manifold:Viewer:InvalidScalarData', ...
                        'Scalar data must contain only finite values');
                end
                
                % Validate scalar data size
                if ~isempty(comp.Vertices)
                    if length(scalarData) ~= size(comp.Vertices, 1)
                        error('bct:ui:manifold:Viewer:ScalarSizeMismatch', ...
                            'Scalar data length (%d) must match number of vertices (%d)', ...
                            length(scalarData), size(comp.Vertices, 1));
                    end
                end
            end
            
            % Build scalar payload
            if isempty(scalarData)
                % Clear scalar visualization
                scalarPayload = struct('action', 'clear');
            else
                % Flatten scalar data
                scalarFlat = reshape(scalarData, 1, []);
                
                % setScalar always replaces (mode: 'replace')
                scalarPayload = struct(...
                    'action', 'add', ...
                    'mode', 'replace', ...
                    'data', scalarFlat ...
                );
            end
            
            % Send to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('scalar', scalarPayload);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Scalar data not sent.');
            end
        end
        
        function setVector(comp, vectorData, varargin)
            % setVector - Visualize vector field with line segments or arrows
            %
            % Syntax:
            %   comp.setVector(vectorData)
            %   comp.setVector(vectorData, 'Support', 'vertex')
            %   comp.setVector(vectorData, 'Positions', centroids, 'Normals', normals)
            %   comp.setVector(vectorData, 'Style', 'arrow', 'LengthScale', 1.0)
            %
            % Inputs:
            %   vectorData - [N×3] or [M×3] matrix of vectors
            %                For vertex support: [numVertices×3]
            %                For face support: [numFaces×3]
            %
            % Optional Parameters:
            %   'Support'      - 'face' (default) or 'vertex'
            %   'Positions'    - [N×3] Base positions (centroids for faces, vertices for vertex support)
            %                    If not provided, uses stored vertices for vertex support
            %   'Normals'      - [N×3] Surface normals for tangent projection
            %                    If not provided, no tangent projection
            %   'Style'        - 'arrow' (default) or 'line' - both use 2D line segments
            %   'Stride'       - Draw every Nth vector (default: 1 - all vectors)
            %   'LengthScale'  - Arrow length multiplier (default: 1.5)
            %   'MaxLength'    - Maximum arrow length (default: 10.0)
            %   'MinMagnitude' - Skip vectors below this magnitude (default: 1e-12)
            %   'Color'        - Line segment color as hex (default: 0x0000ff blue)
            %   'LineWidth'    - Line width in pixels (default: 1)
            %
            % Examples:
            %   % Face-based field with pre-computed centroids and normals
            %   geom = M.geometry();
            %   viewer.setVector(X_face, ...
            %       'Support', 'face', ...
            %       'Positions', geom.face.centroids.value, ...
            %       'Normals', geom.face.normals.value, ...
            %       'Style', 'arrow', 'LengthScale', 0.3);
            %
            %   % Vertex vectors (uses stored vertex positions)
            %   viewer.setVector(velocities, 'Support', 'vertex', 'Stride', 10);
            %
            %   % Clear vector visualization
            %   viewer.setVector([]);
            %
            % Notes:
            %   - Pre-computed positions and normals avoid duplicate geometry computation
            %   - 'arrow' style: 2D line segments with V-shaped arrowheads at tips
            %   - 'line' style: Simple 2D line segments without arrowheads (faster)
            
            arguments
                comp (1,1) bct.ui.manifold.Viewer
                vectorData (:,3) double = []
            end
            
            arguments (Repeating)
                varargin
            end
            
            % Parse optional parameters
            p = inputParser();
            p.addParameter('Support', 'face', @(x) ismember(lower(x), {'face', 'vertex'}));
            p.addParameter('Positions', [], @(x) isempty(x) || (isnumeric(x) && size(x,2) == 3));
            p.addParameter('Normals', [], @(x) isempty(x) || (isnumeric(x) && size(x,2) == 3));
            p.addParameter('Style', 'arrow', @(x) ismember(lower(x), {'arrow', 'line'}));
            p.addParameter('Stride', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('LengthScale', 1.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('MaxLength', 10.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('MinMagnitude', 1e-12, @(x) isnumeric(x) && isscalar(x) && x >= 0);
            p.addParameter('Color', 0x0000ff, @(x) isnumeric(x) && isscalar(x));
            p.addParameter('LineWidth', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.parse(varargin{:});
            
            support = lower(p.Results.Support);
            positions = p.Results.Positions;
            normals = p.Results.Normals;
            style = lower(p.Results.Style);
            stride = p.Results.Stride;
            lengthScale = p.Results.LengthScale;
            maxLength = p.Results.MaxLength;
            minMagnitude = p.Results.MinMagnitude;
            
            % Validate vector data
            if ~isempty(vectorData)
                if ~all(isfinite(vectorData(:)))
                    error('bct:ui:manifold:Viewer:InvalidVectorData', ...
                        'Vector data must contain only finite values');
                end
            end
            
            % Get or validate positions
            if ~isempty(vectorData)
                if isempty(positions)
                    % Use stored vertices for vertex support
                    if strcmp(support, 'vertex')
                        if isempty(comp.Vertices)
                            error('bct:ui:manifold:Viewer:NoVertices', ...
                                'No vertex positions available. Call setMesh() first or provide Positions parameter.');
                        end
                        positions = comp.Vertices;
                    else
                        % For face support, positions must be provided
                        error('bct:ui:manifold:Viewer:NoPositions', ...
                            'For face support, you must provide Positions parameter (face centroids).');
                    end
                end
                
                % Validate positions match vector count
                if size(positions, 1) ~= size(vectorData, 1)
                    error('bct:ui:manifold:Viewer:PositionVectorMismatch', ...
                        'Positions rows (%d) must match vector data rows (%d)', ...
                        size(positions, 1), size(vectorData, 1));
                end
                
                % Validate normals if provided
                if ~isempty(normals)
                    if size(normals, 1) ~= size(vectorData, 1)
                        error('bct:ui:manifold:Viewer:NormalVectorMismatch', ...
                            'Normals rows (%d) must match vector data rows (%d)', ...
                            size(normals, 1), size(vectorData, 1));
                    end
                end
            end
            
            % Build vector payload
            if isempty(vectorData)
                % Clear vector visualization
                vectorPayload = struct('action', 'clear');
            else
                % Flatten arrays for transfer
                vectorFlat = reshape(vectorData.', 1, []);      % [vx1 vy1 vz1 ...]
                positionsFlat = reshape(positions.', 1, []);    % [px1 py1 pz1 ...]
                
                vectorPayload = struct(...
                    'action', 'update', ...
                    'data', vectorFlat, ...
                    'positions', positionsFlat, ...
                    'support', support, ...
                    'style', style, ...
                    'stride', stride, ...
                    'lengthScale', lengthScale, ...
                    'maxLength', maxLength, ...
                    'minMagnitude', minMagnitude, ...
                    'color', p.Results.Color, ...
                    'lineWidth', p.Results.LineWidth, ...
                    'frame', 'matlab' ...  % Vectors/positions are in MATLAB Z-up frame
                );
                
                % Add normals if provided
                if ~isempty(normals)
                    normalsFlat = reshape(normals.', 1, []);    % [nx1 ny1 nz1 ...]
                    vectorPayload.normals = normalsFlat;
                end
            end
            
            % Send to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('vector', vectorPayload);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Vector data not sent.');
            end
        end
        
        function addScalar(comp, scalarData, varargin)
            % addScalar - Add/blend scalar field with existing visualization
            %
            % Syntax:
            %   comp.addScalar(scalarData)
            %   comp.addScalar(scalarData, 'Name', 'myfield')
            %   comp.addScalar(scalarData, 'Mode', 'add')
            %
            % Inputs:
            %   scalarData - [N×1] vector of scalar values
            %
            % Optional Parameters:
            %   'Name' - Layer name (default: auto-generated)
            %   'Mode' - Blending mode: 'add', 'replace', 'multiply', 'max', 'min'
            %            (default: 'add')
            %
            % Blending Modes:
            %   'add'      - Add to existing field: result = existing + new
            %   'replace'  - Replace existing field: result = new
            %   'multiply' - Multiply with existing: result = existing * new
            %   'max'      - Take maximum: result = max(existing, new)
            %   'min'      - Take minimum: result = min(existing, new)
            %
            % Examples:
            %   % Replace existing (like setScalar)
            %   viewer.addScalar(field1, 'Mode', 'replace');
            %
            %   % Add two fields together
            %   viewer.addScalar(heatDistanceA, 'Name', 'sourceA');
            %   viewer.addScalar(heatDistanceB, 'Mode', 'add');  % Combines A + B
            %
            %   % Multiply fields
            %   viewer.addScalar(amplitude, 'Mode', 'replace');
            %   viewer.addScalar(mask, 'Mode', 'multiply');  % Result = amplitude * mask
            %
            % Note:
            %   Use setScalar() to always replace the existing field.
            %   Use addScalar() with 'Mode' to combine fields.
            
            p = inputParser();
            p.addParameter('Name', sprintf('scalar_%d', randi(1e6)), @ischar);
            p.addParameter('Mode', 'add', @(x) ismember(x, {'add', 'replace', 'multiply', 'max', 'min'}));
            p.parse(varargin{:});
            
            % Validate scalar data
            if isempty(scalarData)
                warning('bct:ui:manifold:Viewer:EmptyScalarData', 'Empty scalar data provided');
                return;
            end
            
            validateattributes(scalarData, {'double'}, {'real', 'finite', 'vector'}, 'addScalar', 'scalarData');
            
            % Flatten scalar data
            scalarFlat = reshape(scalarData, 1, []);
            
            % Build payload
            scalarPayload = struct(...
                'action', 'add', ...
                'name', p.Results.Name, ...
                'mode', p.Results.Mode, ...
                'data', scalarFlat ...
            );
            
            % Send to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('scalar', scalarPayload);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Scalar data not sent.');
            end
        end
        
        function setColorLimits(comp, limits)
            % setColorLimits - Set color limits for scalar visualization
            %
            % Syntax:
            %   comp.setColorLimits([min, max])
            %   comp.setColorLimits('auto')
            %
            % Inputs:
            %   limits - Either:
            %            [min, max] - Two-element vector specifying color limits
            %            'auto'     - Reset to automatic range
            %
            % Examples:
            %   % Set custom color limits
            %   viewer.setScalar(scalarData);
            %   viewer.setColorLimits([0, 50]);  % Clamp colormap to [0, 50]
            %
            %   % Reset to auto range
            %   viewer.setColorLimits('auto');
            %
            % Notes:
            %   - Affects current and future scalar field visualizations
            %   - Values outside the range are clamped to min/max
            %   - Use 'auto' to return to data-driven range
            %
            % See also: setScalar, addScalar
            
            arguments
                comp (1,1) bct.ui.manifold.Viewer
                limits
            end
            
            % Validate and parse limits
            if ischar(limits) || isstring(limits)
                if ~strcmpi(limits, 'auto')
                    error('bct:ui:manifold:Viewer:InvalidLimits', ...
                        'String input must be ''auto''');
                end
                climPayload = struct('action', 'setClim', 'clim', 'auto');
            elseif isnumeric(limits)
                if numel(limits) ~= 2
                    error('bct:ui:manifold:Viewer:InvalidLimits', ...
                        'Numeric limits must be a two-element vector [min, max]');
                end
                if ~all(isfinite(limits))
                    error('bct:ui:manifold:Viewer:InvalidLimits', ...
                        'Color limits must be finite values');
                end
                if limits(1) >= limits(2)
                    error('bct:ui:manifold:Viewer:InvalidLimits', ...
                        'Color limits must satisfy min < max');
                end
                climPayload = struct('action', 'setClim', 'clim', limits(:)');
            else
                error('bct:ui:manifold:Viewer:InvalidLimits', ...
                    'Limits must be [min, max] or ''auto''');
            end
            
            % Send to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('colorLimits', climPayload);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Color limits not applied.');
            end
        end
        
        function clearScalar(comp, varargin)
            % clearScalar - Clear scalar visualization
            %
            % Syntax:
            %   comp.clearScalar()          % Clear all scalar layers
            %   comp.clearScalar('Name', 'myfield')  % Clear specific layer
            %
            % Examples:
            %   viewer.clearScalar();
            %   viewer.clearScalar('Name', 'curvature');
            
            p = inputParser();
            p.addParameter('Name', '', @ischar);
            p.parse(varargin{:});
            
            % Build payload
            scalarPayload = struct('action', 'clear');
            if ~isempty(p.Results.Name)
                scalarPayload.name = p.Results.Name;
            end
            
            % Send to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('scalar', scalarPayload);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Clear command not sent.');
            end
        end
        
        function addVector(comp, vectorData, varargin)
            % addVector - Add vector field without clearing existing ones
            %
            % Syntax:
            %   comp.addVector(vectorData, 'Positions', positions, ...)
            %   comp.addVector(vectorData, 'Name', 'field1', ...)
            %
            % Inputs:
            %   vectorData - [N×3] matrix of vectors
            %   'Name' - Layer name (default: auto-generated)
            %   (All other parameters same as setVector)
            %
            % Examples:
            %   viewer.addVector(field1, 'Name', 'tangent1', ...
            %       'Positions', centroids, 'Normals', normals);
            %   viewer.addVector(field2, 'Name', 'tangent2', ...
            %       'Positions', centroids, 'Normals', normals);
            
            % Parse parameters (reuse setVector's parameter parsing)
            p = inputParser();
            p.addParameter('Name', sprintf('vector_%d', randi(1e6)), @ischar);
            p.addParameter('Support', 'face', @(x) ismember(lower(x), {'face', 'vertex'}));
            p.addParameter('Positions', [], @(x) isempty(x) || (isnumeric(x) && size(x,2) == 3));
            p.addParameter('Normals', [], @(x) isempty(x) || (isnumeric(x) && size(x,2) == 3));
            p.addParameter('Style', 'arrow', @(x) ismember(lower(x), {'arrow', 'line'}));
            p.addParameter('Stride', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('LengthScale', 1.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('MaxLength', 10.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('MinMagnitude', 1e-12, @(x) isnumeric(x) && isscalar(x) && x >= 0);
            p.addParameter('Color', 0x0000ff, @(x) isnumeric(x) && isscalar(x));
            p.addParameter('LineWidth', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.parse(varargin{:});
            
            % Validate vector data
            if isempty(vectorData)
                warning('bct:ui:manifold:Viewer:EmptyVectorData', 'Empty vector data provided');
                return;
            end
            
            validateattributes(vectorData, {'double'}, {'real', 'finite', 'ncols', 3}, 'addVector', 'vectorData');
            
            % Get positions
            positions = p.Results.Positions;
            if isempty(positions)
                if strcmp(lower(p.Results.Support), 'vertex')
                    if isempty(comp.Vertices)
                        error('bct:ui:manifold:Viewer:NoVertices', ...
                            'No vertex positions available. Call setMesh() first or provide Positions parameter.');
                    end
                    positions = comp.Vertices;
                else
                    error('bct:ui:manifold:Viewer:NoPositions', ...
                        'For face support, you must provide Positions parameter (face centroids).');
                end
            end
            
            % Flatten arrays
            vectorFlat = reshape(vectorData.', 1, []);
            positionsFlat = reshape(positions.', 1, []);
            
            % Build payload
            vectorPayload = struct(...
                'action', 'add', ...
                'name', p.Results.Name, ...
                'data', vectorFlat, ...
                'positions', positionsFlat, ...
                'support', lower(p.Results.Support), ...
                'style', lower(p.Results.Style), ...
                'stride', p.Results.Stride, ...
                'lengthScale', p.Results.LengthScale, ...
                'maxLength', p.Results.MaxLength, ...
                'minMagnitude', p.Results.MinMagnitude, ...
                'color', p.Results.Color, ...
                'lineWidth', p.Results.LineWidth, ...
                'frame', 'matlab' ...
            );
            
            % Add normals if provided
            if ~isempty(p.Results.Normals)
                normalsFlat = reshape(p.Results.Normals.', 1, []);
                vectorPayload.normals = normalsFlat;
            end
            
            % Send to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('vector', vectorPayload);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Vector data not sent.');
            end
        end
        
        function clearVector(comp, varargin)
            % clearVector - Clear vector visualization
            %
            % Syntax:
            %   comp.clearVector()          % Clear all vector layers
            %   comp.clearVector('Name', 'field1')  % Clear specific layer
            %
            % Examples:
            %   viewer.clearVector();
            %   viewer.clearVector('Name', 'tangent1');
            
            p = inputParser();
            p.addParameter('Name', '', @ischar);
            p.parse(varargin{:});
            
            % Build payload
            vectorPayload = struct('action', 'clear');
            if ~isempty(p.Results.Name)
                vectorPayload.name = p.Results.Name;
            end
            
            % Send to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('vector', vectorPayload);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Clear command not sent.');
            end
        end
        
        function setPoint(comp, varargin)
            % setPoint - Visualize point markers (spheres) at vertices/faces
            %
            % Syntax:
            %   comp.setPoint('Positions', positions, ...)
            %   comp.setPoint('Indices', indices, ...)
            %   comp.setPoint('Positions', positions, 'Radius', 2.0, 'Color', 0xff0000)
            %
            % Optional Parameters:
            %   'Action'    - 'set' (default, replace), 'add' (add to layer), or 'clear'
            %   'Positions' - [N×3] Explicit positions for markers
            %   'Indices'   - [M×1] Vertex/face indices to mark
            %   'Radius'    - Sphere radius (default: 1.0)
            %   'Color'     - Hex color or array of colors (default: 0xff0000 red)
            %   'Opacity'   - Opacity 0-1 (default: 1.0)
            %   'Transparent' - Enable transparency (default: false)
            %   'Name'      - Layer name (default: 'default')
            %
            % Examples:
            %   % Mark specific vertices
            %   viewer.setPoint('Indices', [1, 10, 100], 'Radius', 2.0, 'Color', 0x00ff00);
            %
            %   % Mark custom positions
            %   viewer.setPoint('Positions', customPos, 'Radius', 1.5, 'Color', 0xff0000);
            %
            %   % Named layer
            %   viewer.setPoint('Indices', boundaryVerts, 'Name', 'boundaries');
            %
            %   % Clear
            %   viewer.setPoint('Action', 'clear');
            
            p = inputParser();
            p.addParameter('Action', 'set', @(x) ismember(lower(x), {'set', 'add', 'clear'}));
            p.addParameter('Name', 'default', @ischar);
            p.addParameter('Positions', [], @(x) isempty(x) || (isnumeric(x) && size(x,2) == 3));
            p.addParameter('Indices', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
            p.addParameter('Radius', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('Color', 0xff0000, @(x) isnumeric(x));
            p.addParameter('Opacity', 1.0, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1);
            p.addParameter('Transparent', false, @islogical);
            p.parse(varargin{:});
            
            if strcmp(lower(p.Results.Action), 'clear')
                % Clear point cloud
                pointPayload = struct('action', 'clear');
                if ~strcmp(p.Results.Name, 'default')
                    pointPayload.name = p.Results.Name;
                end
            else
                % Set/add point cloud
                action = lower(p.Results.Action);  % 'set' or 'add'
                positions = p.Results.Positions;
                indices = p.Results.Indices;
                
                if isempty(positions) && isempty(indices)
                    error('bct:ui:manifold:Viewer:NoPositionsOrIndices', ...
                        'Either Positions or Indices must be provided');
                end
                
                % Build payload
                pointPayload = struct(...
                    'action', action, ...  % 'set' or 'add'
                    'name', p.Results.Name, ...
                    'radius', p.Results.Radius, ...
                    'color', p.Results.Color, ...
                    'opacity', p.Results.Opacity, ...
                    'transparent', p.Results.Transparent, ...
                    'frame', 'matlab' ...
                );
                
                % Add positions or indices
                if ~isempty(positions)
                    positionsFlat = reshape(positions.', 1, []);
                    pointPayload.positions = positionsFlat;
                elseif ~isempty(indices)
                    % Convert to 0-based indexing for JavaScript
                    pointPayload.indices = double(indices(:)') - 1;
                end
            end
            
            % Send to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('point', pointPayload);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Point data not sent.');
            end
        end
        
        function addPoint(comp, varargin)
            % addPoint - Add point markers without clearing existing ones
            %
            % Syntax:
            %   comp.addPoint('Name', 'markers1', 'Positions', positions, ...)
            %   comp.addPoint('Name', 'markers2', 'Indices', indices, ...)
            %
            % Parameters: Same as setPoint
            %
            % Examples:
            %   viewer.addPoint('Name', 'set1', 'Indices', [1,2,3], 'Color', 0xff0000);
            %   viewer.addPoint('Name', 'set2', 'Indices', [10,20,30], 'Color', 0x00ff00);
            
            % Parse to override action to 'add'
            p = inputParser();
            p.KeepUnmatched = true;
            p.addParameter('Name', sprintf('point_%d', randi(1e6)), @ischar);
            p.parse(varargin{:});
            
            % Create modified varargin with action='add'
            modifiedArgs = [{'Action', 'add'}, varargin];
            
            % Call setPoint with action='add'
            comp.setPoint(modifiedArgs{:});
        end
        
        function clearPoint(comp, varargin)
            % clearPoint - Clear point markers
            %
            % Syntax:
            %   comp.clearPoint()                % Clear all point layers
            %   comp.clearPoint('Name', 'set1')  % Clear specific layer
            %
            % Examples:
            %   viewer.clearPoint();
            %   viewer.clearPoint('Name', 'boundaries');
            
            p = inputParser();
            p.addParameter('Name', '', @ischar);
            p.parse(varargin{:});
            
            % Build payload
            pointPayload = struct('action', 'clear');
            if ~isempty(p.Results.Name)
                pointPayload.name = p.Results.Name;
            end
            
            % Send to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('point', pointPayload);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Clear command not sent.');
            end
        end
        
        function addLine(comp, varargin)
            % addLine - Add arbitrary line segments to the visualization
            %
            % Syntax:
            %   comp.addLine('Segments', segments, ...)
            %   comp.addLine('Start', startPoints, 'End', endPoints, ...)
            %
            % Parameters:
            %   'Name'     - Layer name for management (default: auto-generated)
            %   'Action'   - 'set' (replace), 'add' (keep existing), 'clear' (remove)
            %   'Segments' - [N×6] or [1×6*N] array of endpoints [x1,y1,z1,x2,y2,z2,...]
            %   'Start'    - [N×3] array of start points (alternative to Segments)
            %   'End'      - [N×3] array of end points (alternative to Segments)
            %   'Color'    - Line color as hex (0xRRGGBB) or string (default: 0xff0000)
            %   'LineWidth'- Line width in pixels (default: 2)
            %   'Frame'    - 'matlab' (default, Z-up) or 'threejs' (Y-up)
            %
            % Examples:
            %   % Direct segment specification
            %   segments = [0,0,0, 1,0,0; 1,0,0, 1,1,0];  % 2 line segments
            %   viewer.addLine('Segments', segments, 'Color', 0x00ff00);
            %
            %   % Start/End point specification
            %   startPts = [0,0,0; 1,0,0];
            %   endPts = [1,0,0; 1,1,0];
            %   viewer.addLine('Start', startPts, 'End', endPts, 'LineWidth', 3);
            %
            %   % Clear specific layer
            %   viewer.addLine('Name', 'isolines', 'Action', 'clear');
            %
            %   % Clear all line layers
            %   viewer.addLine('Action', 'clear');
            
            p = inputParser();
            p.addParameter('Name', '', @ischar);  % Empty default - will auto-generate if needed
            p.addParameter('Action', 'set', @(x) ismember(x, {'set', 'add', 'clear'}));
            p.addParameter('Segments', [], @isnumeric);
            p.addParameter('Start', [], @isnumeric);
            p.addParameter('End', [], @isnumeric);
            p.addParameter('Color', 0xff0000, @(x) (isnumeric(x) && isscalar(x)) || ischar(x));
            p.addParameter('LineWidth', 2, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('Frame', 'matlab', @(x) ismember(x, {'matlab', 'threejs'}));
            p.parse(varargin{:});
            
            % Build payload
            linePayload = struct();
            linePayload.action = p.Results.Action;
            linePayload.frame = p.Results.Frame;
            
            % Handle Name parameter
            if ~isempty(p.Results.Name)
                linePayload.name = p.Results.Name;
            elseif ~strcmp(p.Results.Action, 'clear')
                % Auto-generate name only if not clearing
                linePayload.name = sprintf('line_%d', randi(1e6));
            end
            % For 'clear' with no name, don't set linePayload.name (clears all)
            
            if strcmp(p.Results.Action, 'clear')
                % Clear action: send payload immediately
                if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                    comp.HTMLComponent.Data = struct('lines', linePayload);
                else
                    warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                        'HTMLComponent not ready. Clear command not sent.');
                end
                return;
            end
            
            % Generate segments array
            if ~isempty(p.Results.Segments)
                % Direct segment specification
                segments = p.Results.Segments;
                if size(segments, 2) == 6
                    % [N×6] format → reshape to [1×6*N]
                    segments = reshape(segments', 1, []);
                elseif numel(segments) ~= 6 * floor(numel(segments) / 6)
                    error('bct:ui:manifold:Viewer:InvalidSegments', ...
                        'Segments must be N×6 or 1×(6*N) array');
                end
            elseif ~isempty(p.Results.Start) && ~isempty(p.Results.End)
                % Start/End point specification
                startPts = p.Results.Start;
                endPts = p.Results.End;
                
                if size(startPts, 1) ~= size(endPts, 1)
                    error('bct:ui:manifold:Viewer:MismatchedPoints', ...
                        'Start and End must have same number of points');
                end
                
                if size(startPts, 2) ~= 3 || size(endPts, 2) ~= 3
                    error('bct:ui:manifold:Viewer:InvalidPoints', ...
                        'Start and End must be N×3 arrays');
                end
                
                % Interleave start and end points
                N = size(startPts, 1);
                segments = zeros(1, 6 * N);
                for i = 1:N
                    segments((i-1)*6 + 1 : (i-1)*6 + 3) = startPts(i, :);
                    segments((i-1)*6 + 4 : (i-1)*6 + 6) = endPts(i, :);
                end
            else
                error('bct:ui:manifold:Viewer:NoSegments', ...
                    'Must provide either Segments or both Start and End points');
            end
            
            % Add to payload
            linePayload.segments = segments;
            linePayload.color = p.Results.Color;
            linePayload.linewidth = p.Results.LineWidth;
            
            % Send to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('lines', linePayload);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Line data not sent.');
            end
        end
        
        function addCross(comp, crossField, varargin)
            % addCross - Visualize cross field as line segments forming crosses
            %
            % Syntax:
            %   comp.addCross(crossField)
            %   comp.addCross(crossField, 'Scale', 5)
            %   comp.addCross(crossField, 'Color', 0xff0000, 'LineWidth', 2)
            %
            % Inputs:
            %   crossField - Cross field from bct.field.cross() as struct with:
            %                .d1, .d2, .d3, .d4 - [nF×3] direction vectors
            %
            % Parameters:
            %   'Name'      - Layer name (default: auto-generated)
            %   'Scale'     - Length of cross arms (default: 5)
            %   'Color'     - Cross color as hex (default: 0x000000 black)
            %   'LineWidth' - Line width in pixels (default: 1)
            %   'Action'    - 'set' (replace) or 'add' (keep existing)
            %
            % Examples:
            %   % Create and visualize cross field
            %   M = bct.data.load(Dataset="fsaverage6", Hemi="rh", Surface="pial");
            %   dirField = computeDirectionField(M);
            %   cross = bct.field.cross(M, dirField);
            %   
            %   viewer = bct.ui.show(M);
            %   viewer.addCross(cross, 'Scale', 3, 'Color', 0xff0000);
            %   
            %   % Add multiple cross fields with different colors
            %   viewer.addCross(cross1, 'Name', 'principal', 'Color', 0xff0000);
            %   viewer.addCross(cross2, 'Name', 'secondary', 'Color', 0x00ff00, 'Action', 'add');
            %
            % Notes:
            %   - Creates 2 line segments per face (cross arms)
            %   - Much more efficient than 4 separate addVector calls
            %   - Crosses are centered at face centroids
            %   - All crosses rendered as single LineSegments object
            %
            % See also: bct.field.cross, addLine, addVector
            
            p = inputParser();
            p.addParameter('Name', sprintf('cross_%d', randi(1e6)), @ischar);
            p.addParameter('Scale', 5, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('Color', 0x000000, @(x) (isnumeric(x) && isscalar(x)) || ischar(x));
            p.addParameter('LineWidth', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('Action', 'set', @(x) ismember(x, {'set', 'add'}));
            p.parse(varargin{:});
            
            opts = p.Results;
            
            % Validate cross field input
            if ~isstruct(crossField) || ~all(isfield(crossField, {'d1', 'd2', 'd3', 'd4'}))
                error('bct:ui:manifold:Viewer:InvalidCrossField', ...
                    'Cross field must be struct with fields d1, d2, d3, d4 from bct.field.cross()');
            end
            
            % Validate mesh loaded
            if isempty(comp.Vertices)
                error('bct:ui:manifold:Viewer:NoMesh', ...
                    'No mesh loaded. Call setMesh first.');
            end
            
            % Get number of faces
            nF = size(crossField.d1, 1);
            
            % Validate field dimensions
            if size(crossField.d1, 2) ~= 3 || size(crossField.d2, 2) ~= 3
                error('bct:ui:manifold:Viewer:InvalidDimensions', ...
                    'Cross field directions must be [nF×3]');
            end
            
            % Get face centroids from existing mesh
            % Compute centroids from vertices and faces
            V = comp.Vertices;
            F = comp.Faces;
            centroids = (V(F(:,1), :) + V(F(:,2), :) + V(F(:,3), :)) / 3;
            
            if size(centroids, 1) ~= nF
                error('bct:ui:manifold:Viewer:SizeMismatch', ...
                    'Cross field has %d faces but mesh has %d faces', ...
                    nF, size(centroids, 1));
            end
            
            % Create line segments for crosses
            % Each cross = 2 line segments (d1 ↔ d3, d2 ↔ d4)
            % Since d3 = -d1 and d4 = -d2, we create:
            %   Segment 1: center - d1*scale → center + d1*scale
            %   Segment 2: center - d2*scale → center + d2*scale
            
            scale = opts.Scale;
            
            % Extract directions
            d1 = crossField.d1;  % [nF×3]
            d2 = crossField.d2;  % [nF×3]
            
            % Preallocate segments array [N×6] for N = 2*nF segments
            segments = zeros(2 * nF, 6);
            
            % First arm of cross (d1 ↔ -d1)
            segments(1:2:end, 1:3) = centroids - d1 * scale;  % Start points
            segments(1:2:end, 4:6) = centroids + d1 * scale;  % End points
            
            % Second arm of cross (d2 ↔ -d2)
            segments(2:2:end, 1:3) = centroids - d2 * scale;  % Start points
            segments(2:2:end, 4:6) = centroids + d2 * scale;  % End points
            
            % Call addLine with all segments
            comp.addLine(...
                'Name', opts.Name, ...
                'Action', opts.Action, ...
                'Segments', segments, ...
                'Color', opts.Color, ...
                'LineWidth', opts.LineWidth);
        end
        
        function addParticleFlow(comp, vectorField, varargin)
            % addParticleFlow - Visualize flow field with advected particles on surface
            %
            % Syntax:
            %   comp.addParticleFlow(vectorField)
            %   comp.addParticleFlow(vectorField, 'NumParticles', 1000)
            %   comp.addParticleFlow(vectorField, 'ParticleSize', 3, 'Color', 0x00ffff)
            %
            % Inputs:
            %   vectorField - [N×3] vector field (face-based or vertex-based)
            %
            % Parameters:
            %   'Name'         - Layer name (default: auto-generated)
            %   'Support'      - 'face' or 'vertex' (default: 'face')
            %   'NumParticles' - Number of particles (default: 1000)
            %   'StepSize'     - Integration step size (default: 0.1)
            %   'ParticleSize' - Particle size in pixels (default: 2.0)
            %   'Color'        - Particle color as hex (default: 0x00ffff cyan)
            %   'Fade'         - Enable particle fade (default: true)
            %   'FadeTime'     - Fade duration in seconds (default: 2.0)
            %   'Respawn'      - Respawn particles when they fade (default: true)
            %   'AutoStart'    - Start animation immediately (default: true)
            %   'Action'       - 'set' (replace) or 'add' (keep existing)
            %
            % Examples:
            %   % Visualize heat diffusion gradient
            %   M = bct.data.load(Dataset="fsaverage6", Hemi="rh", Surface="pial");
            %   [~, U] = M.eigenmodes(100);
            %   u = U(:, 10);  % Select mode 10
            %   gradU = bct.field.generate.faceGradient(M, u);
            %   
            %   viewer = bct.ui.show(M);
            %   viewer.addParticleFlow(gradU, 'NumParticles', 2000, ...
            %       'ParticleSize', 3, 'Color', 0xff0000);
            %   
            %   % Add multiple particle flows with different fields
            %   viewer.addParticleFlow(field1, 'Name', 'heat', 'Color', 0xff0000);
            %   viewer.addParticleFlow(field2, 'Name', 'wave', 'Color', 0x00ff00, 'Action', 'add');
            %
            % Notes:
            %   - Particles are transported along the vector field
            %   - Integration performed on GPU via three.js animation loop
            %   - Particles stay on mesh surface via tangent plane projection
            %   - Boundary crossing handled via face adjacency
            %   - Fade and respawn create continuous visualization
            %
            % See also: bct.field.generate.faceGradient, addVector
            
            p = inputParser();
            p.addParameter('Name', sprintf('particleFlow_%d', randi(1e6)), @ischar);
            p.addParameter('Support', 'face', @(x) ismember(lower(x), {'face', 'vertex'}));
            p.addParameter('NumParticles', 1000, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('StepSize', 0.1, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('ParticleSize', 2.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('Color', 0x00ffff, @(x) isnumeric(x) && isscalar(x));
            p.addParameter('Fade', true, @islogical);
            p.addParameter('FadeTime', 2.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('Respawn', true, @islogical);
            p.addParameter('AutoStart', true, @islogical);
            p.addParameter('Action', 'set', @(x) ismember(x, {'set', 'add', 'clear'}));
            p.parse(varargin{:});
            
            opts = p.Results;
            
            % Handle clear action
            if strcmp(opts.Action, 'clear')
                particlePayload = struct(...
                    'action', 'clear', ...
                    'name', opts.Name);
                if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                    comp.HTMLComponent.Data = struct('particleFlow', particlePayload);
                end
                return;
            end
            
            % Validate vector field
            if isempty(vectorField)
                warning('bct:ui:manifold:Viewer:EmptyVectorField', 'Empty vector field provided');
                return;
            end
            
            validateattributes(vectorField, {'double'}, {'real', 'finite', 'ncols', 3}, ...
                'addParticleFlow', 'vectorField');
            
            % Validate mesh loaded
            if isempty(comp.Vertices)
                error('bct:ui:manifold:Viewer:NoMesh', ...
                    'No mesh loaded. Call setMesh first.');
            end
            
            % Flatten vector field data
            vectorFlat = reshape(vectorField.', 1, []);
            
            % Build payload
            particlePayload = struct(...
                'action', opts.Action, ...
                'name', opts.Name, ...
                'vectorField', struct(...
                    'support', lower(opts.Support), ...
                    'data', vectorFlat), ...
                'numParticles', opts.NumParticles, ...
                'stepSize', opts.StepSize, ...
                'particleSize', opts.ParticleSize, ...
                'particleColor', opts.Color, ...
                'fade', opts.Fade, ...
                'fadeTime', opts.FadeTime, ...
                'respawn', opts.Respawn, ...
                'autoStart', opts.AutoStart);
            
            % Send to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('particleFlow', particlePayload);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Particle flow data not sent.');
            end
        end
        
        function background(comp, varargin)
            % background - Set scene background color
            %
            % Syntax:
            %   comp.background('Color', color)
            %   comp.background('Color', 'white')
            %   comp.background('Color', 0xffffff)
            %   comp.background('Color', 'none')  % Transparent background
            %
            % Parameters:
            %   'Color' - Color as hex (0xRRGGBB), string ('white', 'black', etc.), or 'none'
            %
            % Examples:
            %   viewer.background('Color', 0xffffff);  % White
            %   viewer.background('Color', 'white');    % White (named)
            %   viewer.background('Color', 0x000000);  % Black
            %   viewer.background('Color', 'none');     % Transparent
            
            p = inputParser();
            p.addParameter('Color', 0xffffff, @(x) (isnumeric(x) && isscalar(x)) || ischar(x));
            p.parse(varargin{:});
            
            colorValue = p.Results.Color;
            
            % Build payload (same format for both char and numeric)
            colorPayload = struct('color', colorValue);
            
            % Send to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('background', colorPayload);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Background command not sent.');
            end
        end
        
        function status = getStatus(comp)
            % getStatus - Diagnostic function to check viewer connection
            %
            % Syntax:
            %   status = viewer.getStatus()
            %
            % Returns:
            %   status - Struct with diagnostic information
            %
            % Example:
            %   viewer = bct.ui.show(M);
            %   status = viewer.getStatus()
            
            status = struct();
            status.HTMLComponentExists = ~isempty(comp.HTMLComponent);
            status.HTMLComponentValid = ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent);
            status.HasMeshData = ~isempty(comp.Vertices) && ~isempty(comp.Faces);
            status.VertexCount = size(comp.Vertices, 1);
            status.FaceCount = size(comp.Faces, 1);
            
            if status.HTMLComponentValid
                status.HTMLSource = comp.HTMLComponent.HTMLSource;
                try
                    % Try to send a test ping (use valid field name without underscore)
                    comp.HTMLComponent.Data = struct('ping', true);
                    status.CanSendData = true;
                catch ME
                    status.CanSendData = false;
                    status.SendError = ME.message;
                end
            else
                status.HTMLSource = 'N/A';
                status.CanSendData = false;
            end
            
            % Display status
            fprintf('\n=== Viewer Status ===\n');
            fprintf('HTMLComponent exists: %d\n', status.HTMLComponentExists);
            fprintf('HTMLComponent valid: %d\n', status.HTMLComponentValid);
            fprintf('Can send data: %d\n', status.CanSendData);
            fprintf('Has mesh data: %d\n', status.HasMeshData);
            fprintf('Vertices: %d\n', status.VertexCount);
            fprintf('Faces: %d\n', status.FaceCount);
            fprintf('HTML source: %s\n', status.HTMLSource);
            if ~status.CanSendData && isfield(status, 'SendError')
                fprintf('Send error: %s\n', status.SendError);
            end
            fprintf('====================\n\n');
        end
    end
end
