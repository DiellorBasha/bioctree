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
            %   - When using bct.Manifold, also sends geometry cache:
            %     * Face centroids (for quiver visualization)
            %     * Face normals (for tangent projection)
            %     * Vertex tangents (for future use)
            
            % Parse input arguments
            M_obj = [];
            if nargin == 2 && isa(varargin{1}, 'bct.Manifold')
                % Case 1: bct.Manifold object provided
                M_obj = varargin{1};
                V = M_obj.Vertices;   % Access property (not method)
                F = M_obj.Faces;      % Access property (not method)
                N = M_obj.vertexGeometry().normals;  % Get vertex normals from geometry cache
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
            
            % Add geometry cache data if Manifold object provided
            if ~isempty(M_obj)
                % Get face geometry
                faceGeom = M_obj.faceGeometry();
                
                % Add face centroids [cx1 cy1 cz1 cx2 cy2 cz2 ...]
                meshData.faceCentroids = reshape(faceGeom.centroids.', 1, []);
                
                % Add face normals [nx1 ny1 nz1 nx2 ny2 nz2 ...]
                meshData.faceNormals = reshape(faceGeom.normals.', 1, []);
                
                % Add vertex tangents
                vertexGeom = M_obj.vertexGeometry();
                meshData.vertexTangent1 = reshape(vertexGeom.tangent1.', 1, []);
                meshData.vertexTangent2 = reshape(vertexGeom.tangent2.', 1, []);
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
            % setScalar - Map scalar data to vertex colors
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
            %   - Scalar data must match number of vertices from last setMesh call
            %   - Colormap can be changed via viewer UI controls
            %   - Call without arguments or empty array to clear visualization
            
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
                
                scalarPayload = struct(...
                    'action', 'update', ...
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
            % setVector - Visualize vector field with quiver plot
            %
            % Syntax:
            %   comp.setVector(vectorData)
            %   comp.setVector(vectorData, 'Support', 'vertex')
            %   comp.setVector(vectorData, 'Stride', 5, 'LengthScale', 1.0)
            %
            % Inputs:
            %   vectorData - [N×3] or [M×3] matrix of vectors
            %                For vertex support: [numVertices×3]
            %                For face support: [numFaces×3]
            %
            % Optional Parameters:
            %   'Support'      - 'face' (default) or 'vertex'
            %   'Stride'       - Draw every Nth vector (default: 5)
            %   'LengthScale'  - Arrow length multiplier (default: 1.0)
            %   'MaxLength'    - Maximum arrow length (default: 10.0)
            %   'MinMagnitude' - Skip vectors below this magnitude (default: 1e-12)
            %
            % Examples:
            %   % Visualize face-based gradient field
            %   viewer.setVector(gradients, 'Support', 'face');
            %
            %   % Sparse vertex vectors with custom scaling
            %   viewer.setVector(velocities, 'Support', 'vertex', 'Stride', 10, 'LengthScale', 0.5);
            %
            %   % Clear vector visualization
            %   viewer.setVector([]);
            %
            % Notes:
            %   - Vectors are displayed as 3D arrows (quiver plot)
            %   - For face support, arrows placed at face centroids
            %   - For vertex support, arrows placed at vertex positions
            
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
            p.addParameter('Stride', 5, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('LengthScale', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('MaxLength', 10.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
            p.addParameter('MinMagnitude', 1e-12, @(x) isnumeric(x) && isscalar(x) && x >= 0);
            p.parse(varargin{:});
            
            support = lower(p.Results.Support);
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
                
                % Validate size based on support
                if ~isempty(comp.Vertices) && ~isempty(comp.Faces)
                    expectedSize = size(comp.Faces, 1);
                    if strcmp(support, 'vertex')
                        expectedSize = size(comp.Vertices, 1);
                    end
                    
                    if size(vectorData, 1) ~= expectedSize
                        error('bct:ui:manifold:Viewer:VectorSizeMismatch', ...
                            'Vector data rows (%d) must match %s count (%d)', ...
                            size(vectorData, 1), support, expectedSize);
                    end
                end
            end
            
            % Build vector payload
            if isempty(vectorData)
                % Clear vector visualization
                vectorPayload = struct('action', 'clear');
            else
                % Flatten vector data: [vx1 vy1 vz1 vx2 vy2 vz2 ...]
                vectorFlat = reshape(vectorData.', 1, []);
                
                vectorPayload = struct(...
                    'action', 'update', ...
                    'data', vectorFlat, ...
                    'support', support, ...
                    'stride', stride, ...
                    'lengthScale', lengthScale, ...
                    'maxLength', maxLength, ...
                    'minMagnitude', minMagnitude ...
                );
            end
            
            % Send to JavaScript
            if ~isempty(comp.HTMLComponent) && isvalid(comp.HTMLComponent)
                comp.HTMLComponent.Data = struct('vector', vectorPayload);
            else
                warning('bct:ui:manifold:Viewer:HTMLComponentNotReady', ...
                    'HTMLComponent not ready. Vector data not sent.');
            end
        end
    end
end
