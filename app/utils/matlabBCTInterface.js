/**
 * MATLAB BCT Interface - Utilities for working with MATLAB bct class data
 * Provides conversion between MATLAB bct HDF5 format and JavaScript BCT format
 */

import { BCTConverter } from './bctConverter.js';

export class MatlabBCTInterface {
    
    /**
     * Convert MATLAB bct.read_graph_gsp() output to JavaScript BCT format
     * @param {Object} gspGraph - Graph from MATLAB bct.read_graph_gsp()
     * @returns {Object} JavaScript BCT format
     */
    static gspGraphToBCT(gspGraph) {
        const { W, N, coords, lmax } = gspGraph;
        
        // Convert sparse matrix W to COO format
        const edges = this._sparseMatrixToCOO(W);
        
        return {
            format: "bct",
            version: "1.0",
            metadata: {
                description: "Converted from MATLAB GSP graph",
                created: new Date().toISOString().split('T')[0],
                total_vertices: N,
                total_edges: edges.coo_i.length,
                lmax: lmax || null,
                source: "matlab_gsp"
            },
            graph: {
                nodes: {
                    count: N,
                    coords: coords || []
                },
                edges: {
                    count: edges.coo_i.length,
                    coo_i: edges.coo_i,
                    coo_j: edges.coo_j,
                    coo_w: edges.coo_w
                }
            }
        };
    }
    
    /**
     * Create MATLAB-compatible graph structure from BCT data
     * @param {Object} bctData - JavaScript BCT format data
     * @returns {Object} MATLAB GSP-compatible graph structure
     */
    static bctToGSPGraph(bctData) {
        const nodes = bctData.graph.nodes;
        const edges = bctData.graph.edges;
        
        // Build sparse adjacency matrix
        const W = this._cooToSparseMatrix(edges, nodes.count);
        
        return {
            W: W,
            N: nodes.count,
            coords: nodes.coords,
            type: 'undirected'
        };
    }
    
    /**
     * Generate HDF5-compatible data structure for MATLAB bct class
     * @param {Object} bctData - JavaScript BCT format
     * @returns {Object} Structure matching MATLAB bct HDF5 schema
     */
    static toBCTHDF5Format(bctData) {
        const nodes = bctData.graph.nodes;
        const edges = bctData.graph.edges;
        
        return {
            // Axes (required by bct schema)
            axes: {
                node_id: Array.from({ length: nodes.count }, (_, i) => i),
                time_s: [], // Empty if no time series data
                layer_id: [0], // Default layer
                freq_hz: [] // Empty if no frequency data
            },
            
            // Graph structure
            graph: {
                nodes: {
                    coords: nodes.coords
                },
                edges: {
                    coo_i: edges.coo_i,
                    coo_j: edges.coo_j,
                    coo_w: edges.coo_w
                }
            },
            
            // Metadata attributes
            attributes: {
                indexing: 'zero_based',
                lap_type: 'combinatorial',
                type: 'undirected',
                fs_hz: null
            }
        };
    }
    
    /**
     * Convert from MATLAB bct HDF5 structure to JavaScript BCT
     * @param {Object} hdf5Data - Data from MATLAB bct file
     * @returns {Object} JavaScript BCT format
     */
    static fromBCTHDF5Format(hdf5Data) {
        const nodeIds = hdf5Data.axes.node_id || [];
        const coords = hdf5Data.graph?.nodes?.coords || [];
        const edges = hdf5Data.graph?.edges || {};
        
        return {
            format: "bct",
            version: "1.0",
            metadata: {
                description: "Converted from MATLAB BCT HDF5",
                created: new Date().toISOString().split('T')[0],
                total_vertices: nodeIds.length,
                total_edges: edges.coo_i ? edges.coo_i.length : 0,
                indexing: hdf5Data.attributes?.indexing || 'zero_based',
                source: "matlab_hdf5"
            },
            graph: {
                nodes: {
                    count: nodeIds.length,
                    coords: coords
                },
                edges: {
                    count: edges.coo_i ? edges.coo_i.length : 0,
                    coo_i: edges.coo_i || [],
                    coo_j: edges.coo_j || [],
                    coo_w: edges.coo_w || []
                }
            }
        };
    }
    
    /**
     * Generate MATLAB script to export BCT data to JavaScript format
     * @param {string} bctVariableName - Name of MATLAB bct object variable
     * @param {string} outputPath - Output path for JSON file
     * @returns {string} MATLAB script
     */
    static generateMatlabExportScript(bctVariableName = 'b', outputPath = 'bct_export.json') {
        return `
% Export BCT data to JavaScript-compatible JSON format
% Usage: Run this script after loading your bct object

if ~exist('${bctVariableName}', 'var')
    error('BCT object "${bctVariableName}" not found in workspace');
end

% Extract graph data
try
    G = ${bctVariableName}.read_graph_gsp();
catch
    error('Failed to read graph data from BCT object');
end

% Extract coordinates if available
coords = ${bctVariableName}.read_coords();
if isempty(coords)
    coords = [];
else
    coords = double(coords);
end

% Convert sparse matrix to COO format
[i, j, w] = find(G.W);
i = double(i) - 1; % Convert to 0-based indexing
j = double(j) - 1;
w = double(w);

% Create JavaScript-compatible structure
js_data = struct();
js_data.format = 'bct';
js_data.version = '1.0';
js_data.metadata = struct();
js_data.metadata.description = 'Exported from MATLAB BCT';
js_data.metadata.created = datestr(now, 'yyyy-mm-dd');
js_data.metadata.total_vertices = G.N;
js_data.metadata.total_edges = length(i);
js_data.metadata.source = 'matlab_export';

js_data.graph = struct();
js_data.graph.nodes = struct();
js_data.graph.nodes.count = G.N;
js_data.graph.nodes.coords = coords;

js_data.graph.edges = struct();
js_data.graph.edges.count = length(i);
js_data.graph.edges.coo_i = i;
js_data.graph.edges.coo_j = j;
js_data.graph.edges.coo_w = w;

% Write to JSON file
json_str = jsonencode(js_data);
fid = fopen('${outputPath}', 'w');
if fid == -1
    error('Failed to open output file: ${outputPath}');
end
fprintf(fid, '%s', json_str);
fclose(fid);

fprintf('BCT data exported to: ${outputPath}\\n');
fprintf('Vertices: %d, Edges: %d\\n', G.N, length(i));
`;
    }
    
    /**
     * Generate MATLAB script to import JavaScript BCT data
     * @param {string} jsonPath - Path to JavaScript BCT JSON file
     * @param {string} bctOutputPath - Output path for MATLAB BCT file
     * @returns {string} MATLAB script
     */
    static generateMatlabImportScript(jsonPath = 'bct_data.json', bctOutputPath = 'imported.bct') {
        return `
% Import JavaScript BCT JSON data to MATLAB bct format
% Usage: Run this script to convert JSON BCT data to MATLAB

if ~exist('${jsonPath}', 'file')
    error('JSON file not found: ${jsonPath}');
end

% Read JSON data
json_str = fileread('${jsonPath}');
js_data = jsondecode(json_str);

% Extract graph data
nodes = js_data.graph.nodes;
edges = js_data.graph.edges;

% Convert to MATLAB indexing (1-based)
i = double(edges.coo_i) + 1;
j = double(edges.coo_j) + 1;
w = double(edges.coo_w);

% Create sparse adjacency matrix
W = sparse(i, j, w, nodes.count, nodes.count);
W = max(W, W'); % Ensure symmetry

% Create graph structure
G = struct();
G.W = W;
G.N = nodes.count;
if ~isempty(nodes.coords)
    G.coords = double(nodes.coords);
end

% Create BCT object
b = bct.create('${bctOutputPath}');

% Write graph data
b.write_graph(struct('E', [i j w], 'coords', G.coords));

fprintf('JavaScript BCT data imported to: ${bctOutputPath}\\n');
fprintf('Vertices: %d, Edges: %d\\n', G.N, length(i));
fprintf('Use: b = bct.open(''${bctOutputPath}'') to load the data\\n');
`;
    }
    
    // Private helper methods
    
    static _sparseMatrixToCOO(W) {
        // Convert various sparse matrix representations to COO
        const edges = { coo_i: [], coo_j: [], coo_w: [] };
        
        if (W.i && W.j && W.w) {
            // Already in COO format
            return {
                coo_i: Array.from(W.i),
                coo_j: Array.from(W.j),
                coo_w: Array.from(W.w)
            };
        }
        
        // If W is represented as dense 2D array
        if (Array.isArray(W) && Array.isArray(W[0])) {
            for (let i = 0; i < W.length; i++) {
                for (let j = i; j < W[i].length; j++) { // Upper triangle
                    if (W[i][j] !== 0) {
                        edges.coo_i.push(i);
                        edges.coo_j.push(j);
                        edges.coo_w.push(W[i][j]);
                        
                        // Add symmetric entry if not diagonal
                        if (i !== j) {
                            edges.coo_i.push(j);
                            edges.coo_j.push(i);
                            edges.coo_w.push(W[i][j]);
                        }
                    }
                }
            }
        }
        
        return edges;
    }
    
    static _cooToSparseMatrix(edges, nodeCount) {
        // Create a sparse matrix representation
        const matrix = Array(nodeCount).fill().map(() => Array(nodeCount).fill(0));
        
        for (let k = 0; k < edges.coo_i.length; k++) {
            const i = edges.coo_i[k];
            const j = edges.coo_j[k];
            const w = edges.coo_w[k];
            
            matrix[i][j] = w;
            matrix[j][i] = w; // Ensure symmetry
        }
        
        return matrix;
    }
    
    /**
     * Validate BCT data compatibility with MATLAB format
     * @param {Object} bctData - JavaScript BCT data
     * @returns {Object} Validation result with warnings/errors
     */
    static validateMatlabCompatibility(bctData) {
        const result = {
            valid: true,
            warnings: [],
            errors: []
        };
        
        // Check required fields
        if (!bctData.graph || !bctData.graph.nodes || !bctData.graph.edges) {
            result.errors.push('Missing required graph structure');
            result.valid = false;
        }
        
        // Check node coordinates
        const coords = bctData.graph.nodes.coords;
        if (coords && coords.length > 0) {
            if (!Array.isArray(coords[0]) || coords[0].length !== 3) {
                result.errors.push('Node coordinates must be 3D (x, y, z)');
                result.valid = false;
            }
        }
        
        // Check edge indices
        const edges = bctData.graph.edges;
        if (edges.coo_i && edges.coo_j) {
            const maxIndex = Math.max(...edges.coo_i, ...edges.coo_j);
            if (maxIndex >= bctData.graph.nodes.count) {
                result.errors.push('Edge indices exceed node count');
                result.valid = false;
            }
        }
        
        // Warnings for missing optional data
        if (!coords || coords.length === 0) {
            result.warnings.push('No node coordinates provided - visualization may be limited');
        }
        
        if (!bctData.metadata) {
            result.warnings.push('No metadata provided');
        }
        
        return result;
    }
}