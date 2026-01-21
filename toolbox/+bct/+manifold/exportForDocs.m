function exportForDocs(M, baseName, options)
%EXPORTFORDOCS Export manifold and geometric data for documentation viewer
%
% Exports manifold geometry and associated data for use in the mkdocs
% three.js viewer component. Creates .obj file for mesh and .json file
% for geometric/topological data.
%
% Syntax:
%   bct.manifold.exportForDocs(M, baseName)
%   bct.manifold.exportForDocs(M, baseName, Name=Value)
%
% Inputs:
%   M        - bct.Manifold object
%   baseName - Base name for output files (without extension)
%              e.g., 'docs/docs/assets/models/fsaverage_rh_pial'
%
% Name-Value Arguments:
%   OutputDir      - Output directory (default: 'docs/docs/assets/')
%   ExportNormals  - Include vertex and face normals (default: true)
%   ExportTangents - Include tangent frames (default: true)
%   ExportTopology - Include topology data (edges, adjacency) (default: false)
%   ExportMetric   - Include metric information (default: true)
%
% Outputs:
%   Creates two files:
%     - {baseName}.obj  - Wavefront OBJ mesh file
%     - {baseName}.json - JSON with geometric/topological data
%
% JSON Structure:
%   {
%     "metadata": {
%       "manifoldId": "...",
%       "numVertices": N,
%       "numFaces": F,
%       "numEdges": E,
%       "format": "bioctree-docs-v1"
%     },
%     "metric": {
%       "unit": "m",
%       "rescaled": true/false
%     },
%     "geometry": {
%       "vertex": {
%         "normals": [[nx,ny,nz], ...],
%         "tangent1": [[tx,ty,tz], ...],
%         "tangent2": [[tx,ty,tz], ...]
%       },
%       "face": {
%         "areas": [a1, a2, ...],
%         "normals": [[nx,ny,nz], ...],
%         "centroids": [[cx,cy,cz], ...],
%         "tangent1": [[tx,ty,tz], ...],
%         "tangent2": [[tx,ty,tz], ...]
%       }
%     },
%     "topology": {  // optional
%       "edges": [[i,j], ...],
%       "boundaries": [...]
%     }
%   }
%
% Examples:
%   % Export fsaverage mesh for documentation
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   bct.manifold.exportForDocs(M, 'fsaverage_rh_pial', ...
%       'OutputDir', 'docs/docs/assets/models');
%
%   % Export with full topology data
%   bct.manifold.exportForDocs(M, 'mesh_full', ...
%       'ExportTopology', true);
%
%   % Minimal export (just normals)
%   bct.manifold.exportForDocs(M, 'mesh_minimal', ...
%       'ExportTangents', false, 'ExportMetric', false);
%
% See also: bct.manifold.write, bct.field.exportForDocs

arguments
    M bct.Manifold
    baseName string
    options.OutputDir string = "docs/docs/assets/models"
    options.ExportNormals (1,1) logical = true
    options.ExportTangents (1,1) logical = true
    options.ExportTopology (1,1) logical = false
    options.ExportMetric (1,1) logical = true
end

% Ensure output directory exists
if ~isfolder(options.OutputDir)
    mkdir(options.OutputDir);
end

% Construct full paths
objPath = fullfile(options.OutputDir, baseName + ".obj");
jsonPath = fullfile(options.OutputDir, baseName + ".json");

fprintf('Exporting manifold for documentation viewer...\n');
fprintf('  Output directory: %s\n', options.OutputDir);
fprintf('  Base name: %s\n', baseName);

% =========================================================================
% Export OBJ file (mesh geometry)
% =========================================================================
fprintf('  Writing OBJ file: %s\n', objPath);
bct.manifold.write(M, objPath);

% =========================================================================
% Build JSON data structure
% =========================================================================
data = struct();

% Metadata
data.metadata = struct();
data.metadata.manifoldId = char(M.Header.ID);
data.metadata.numVertices = M.numVertices();
data.metadata.numFaces = M.numFaces();
data.metadata.numEdges = M.numEdges();
data.metadata.format = 'bioctree-docs-v1';
data.metadata.exportDate = datestr(now, 'yyyy-mm-dd HH:MM:SS');

% Metric information
if options.ExportMetric
    data.metric = struct();
    data.metric.unit = char(M.Header.Metric.unit);
    data.metric.rescaled = M.Header.Metric.rescale.applied;
    if data.metric.rescaled
        data.metric.fromUnit = char(M.Header.Metric.rescale.fromUnit);
        data.metric.factor = M.Header.Metric.rescale.factor;
        data.metric.timestamp = char(M.Header.Metric.rescale.timestamp);
    end
end

% Geometry data
data.geometry = struct();

% Vertex geometry
if options.ExportNormals || options.ExportTangents
    fprintf('  Computing vertex geometry...\n');
    vg = M.vertexGeometry();
    data.geometry.vertex = struct();
    
    if options.ExportNormals
        data.geometry.vertex.normals = vg.normals;
    end
    
    if options.ExportTangents
        data.geometry.vertex.tangent1 = vg.tangent1;
        data.geometry.vertex.tangent2 = vg.tangent2;
    end
end

% Face geometry
if options.ExportNormals || options.ExportTangents
    fprintf('  Computing face geometry...\n');
    fg = M.faceGeometry();
    data.geometry.face = struct();
    
    data.geometry.face.areas = fg.areas;
    data.geometry.face.centroids = fg.centroids;
    
    if options.ExportNormals
        data.geometry.face.normals = fg.normals;
    end
    
    if options.ExportTangents
        data.geometry.face.tangent1 = fg.tangent1;
        data.geometry.face.tangent2 = fg.tangent2;
    end
end

% Topology data (optional, can be large)
if options.ExportTopology
    fprintf('  Computing topology data...\n');
    topo = M.topology();
    data.topology = struct();
    
    % Edges (already in M)
    data.topology.edges = M.Edges;
    
    % Boundary information if available
    if isfield(topo, 'halfedge') && isfield(topo.halfedge, 'isBoundary')
        boundaryHalfedges = find(topo.halfedge.isBoundary);
        if ~isempty(boundaryHalfedges)
            data.topology.hasBoundary = true;
            data.topology.boundaryVertices = unique(topo.halfedge.v(boundaryHalfedges));
        else
            data.topology.hasBoundary = false;
        end
    end
end

% =========================================================================
% Write JSON file
% =========================================================================
fprintf('  Writing JSON file: %s\n', jsonPath);

% Write with nice formatting
jsonStr = jsonencode(data);

% Pretty print JSON (add newlines and indentation)
jsonStr = prettifyJSON(jsonStr);

fid = fopen(jsonPath, 'w');
if fid == -1
    error('bct:manifold:exportForDocs:CannotWriteFile', ...
        'Cannot write to file: %s', jsonPath);
end
fprintf(fid, '%s', jsonStr);
fclose(fid);

fprintf('Export complete!\n');
fprintf('  OBJ:  %s (%d vertices, %d faces)\n', objPath, ...
    data.metadata.numVertices, data.metadata.numFaces);
fprintf('  JSON: %s (%.2f KB)\n', jsonPath, ...
    length(jsonStr) / 1024);

end

function pretty = prettifyJSON(jsonStr)
    %PRETTIFYJSON Add indentation and newlines to JSON string
    
    % Simple prettification for readability
    % Replace certain patterns with newlines and spaces
    pretty = jsonStr;
    
    % Add newlines after { and before }
    pretty = strrep(pretty, '{', sprintf('{\n  '));
    pretty = strrep(pretty, '}', sprintf('\n}'));
    
    % Add newlines after commas in objects
    pretty = strrep(pretty, ',"', sprintf(',\n  "'));
    
    % Add newlines after : in arrays (basic formatting)
    pretty = strrep(pretty, ':[', sprintf(':\n  ['));
    
    % This is basic - for full pretty printing, consider using a JSON library
    % or MATLAB's jsonencode with 'PrettyPrint' if available in your version
end
