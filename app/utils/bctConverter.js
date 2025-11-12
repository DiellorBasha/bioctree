/**
 * BCT Converter - Bidirectional conversion between BCT graph format and Three.js meshes
 * Supports the BCT HDF5 format as defined in the MATLAB bct class
 */

import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import * as THREE from 'three';

export class BCTConverter {
    
    /**
     * Convert a Three.js mesh to BCT graph format
     * @param {Float32Array} vertices - vertex positions [x, y, z, ...]
     * @param {Uint32Array} faces - face indices [i, j, k, ...]
     * @returns {Object} BCT graph structure
     */
    static meshToGraph(vertices, faces) {
        const nodeCount = vertices.length / 3;
        const coords = [];
        
        // Extract coordinates
        for (let i = 0; i < nodeCount; i++) {
            coords.push([
                vertices[i * 3],
                vertices[i * 3 + 1], 
                vertices[i * 3 + 2]
            ]);
        }
        
        // Build adjacency from faces (mesh connectivity)
        const adjacency = new Map();
        const faceCount = faces.length / 3;
        
        for (let f = 0; f < faceCount; f++) {
            const i = faces[f * 3];
            const j = faces[f * 3 + 1];
            const k = faces[f * 3 + 2];
            
            // Add edges for triangle (undirected)
            this._addEdge(adjacency, i, j);
            this._addEdge(adjacency, j, k);
            this._addEdge(adjacency, k, i);
        }
        
        // Convert adjacency map to COO format
        const edges = this._adjacencyToCOO(adjacency, coords);
        
        return {
            nodeCount,
            edgeCount: edges.i.length,
            coords,
            edges
        };
    }
    
    /**
     * Convert BCT graph to Three.js mesh geometry
     * @param {Object} bctGraph - BCT graph structure
     * @returns {Object} Three.js compatible mesh data
     */
    static graphToMesh(bctGraph) {
        const coords = bctGraph.graph.nodes.coords;
        const edges = bctGraph.graph.edges;
        
        // For brain connectivity, we typically visualize as:
        // 1. Nodes as spheres at coordinate positions
        // 2. Edges as lines between connected nodes
        // 3. Optional: generate surface from convex hull or Delaunay triangulation
        
        const nodeGeometry = this._createNodeGeometry(coords);
        const edgeGeometry = this._createEdgeGeometry(coords, edges);
        
        return {
            nodes: nodeGeometry,
            edges: edgeGeometry,
            surface: this._generateSurfaceFromNodes(coords) // Optional surface mesh
        };
    }
    
    /**
     * Create a complete BCT file structure from graph data
     * @param {Object} leftGraph - Left hemisphere graph
     * @param {Object} rightGraph - Right hemisphere graph
     * @param {Object} metadata - File metadata
     * @returns {Object} Complete BCT file structure
     */
    static createBCTFile(leftGraph, rightGraph, metadata = {}) {
        // Combine left and right hemisphere data
        const totalNodes = leftGraph.nodeCount + rightGraph.nodeCount;
        const totalEdges = leftGraph.edgeCount + rightGraph.edgeCount;
        
        // Offset right hemisphere node indices
        const rightOffset = leftGraph.nodeCount;
        const rightEdgesOffset = {
            i: rightGraph.edges.i.map(idx => idx + rightOffset),
            j: rightGraph.edges.j.map(idx => idx + rightOffset),
            w: rightGraph.edges.w
        };
        
        // Combine coordinates and edges
        const allCoords = [...leftGraph.coords, ...rightGraph.coords];
        const allEdges = {
            i: [...leftGraph.edges.i, ...rightEdgesOffset.i],
            j: [...leftGraph.edges.j, ...rightEdgesOffset.j], 
            w: [...leftGraph.edges.w, ...rightEdgesOffset.w]
        };
        
        return {
            format: "bct",
            version: "1.0",
            metadata: {
                description: metadata.description || "BCT graph data",
                created: new Date().toISOString().split('T')[0],
                vertices_left: leftGraph.nodeCount,
                vertices_right: rightGraph.nodeCount,
                edges_left: leftGraph.edgeCount,
                edges_right: rightGraph.edgeCount,
                total_vertices: totalNodes,
                total_edges: totalEdges,
                ...metadata
            },
            graph: {
                nodes: {
                    count: totalNodes,
                    coords: allCoords
                },
                edges: {
                    count: totalEdges,
                    coo_i: allEdges.i,
                    coo_j: allEdges.j,
                    coo_w: allEdges.w
                }
            }
        };
    }
    
    /**
     * Convert BCT HDF5-style data to Three.js format
     * This matches the structure used by the MATLAB bct class
     * @param {Object} hdf5Data - Data structure matching MATLAB bct format
     * @returns {Object} Three.js compatible data
     */
    static bctHDF5ToThreeJS(hdf5Data) {
        // Extract graph data (matches bct.read_graph_gsp format)
        const coords = hdf5Data.coords || [];
        const W = hdf5Data.W; // Sparse weight matrix
        
        if (!W || !coords.length) {
            throw new Error('Invalid BCT HDF5 data: missing coordinates or weight matrix');
        }
        
        // Convert sparse matrix to COO format
        const edges = this._sparseMatrixToCOO(W);
        
        return {
            nodes: this._createNodeGeometry(coords),
            edges: this._createEdgeGeometry(coords, edges),
            coords: coords,
            adjacency: edges
        };
    }
    
    /**
     * Export Three.js scene to GLB format
     * @param {THREE.Scene} scene - Three.js scene to export
     * @returns {Promise<Blob>} GLB file blob
     */
    static async exportToGLB(scene) {
        return new Promise((resolve, reject) => {
            const exporter = new GLTFExporter();
            
            exporter.parse(
                scene,
                (gltf) => {
                    const blob = new Blob([gltf], { type: 'application/octet-stream' });
                    resolve(blob);
                },
                (error) => reject(error),
                { binary: true }
            );
        });
    }
    
    /**
     * Download a blob as a file
     * @param {Blob} blob - File blob
     * @param {string} filename - Download filename
     */
    static downloadBlob(blob, filename) {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }
    
    // Private helper methods
    
    static _addEdge(adjacency, i, j) {
        if (!adjacency.has(i)) adjacency.set(i, new Set());
        if (!adjacency.has(j)) adjacency.set(j, new Set());
        adjacency.get(i).add(j);
        adjacency.get(j).add(i);
    }
    
    static _adjacencyToCOO(adjacency, coords) {
        const edges = { i: [], j: [], w: [] };
        
        for (const [nodeI, neighbors] of adjacency) {
            for (const nodeJ of neighbors) {
                if (nodeI < nodeJ) { // Avoid duplicates in undirected graph
                    const weight = this._calculateEdgeWeight(coords[nodeI], coords[nodeJ]);
                    edges.i.push(nodeI);
                    edges.j.push(nodeJ);
                    edges.w.push(weight);
                }
            }
        }
        
        return edges;
    }
    
    static _calculateEdgeWeight(coord1, coord2) {
        // Euclidean distance as edge weight
        const dx = coord1[0] - coord2[0];
        const dy = coord1[1] - coord2[1];
        const dz = coord1[2] - coord2[2];
        return Math.sqrt(dx * dx + dy * dy + dz * dz);
    }
    
    static _createNodeGeometry(coords) {
        const geometry = new THREE.SphereGeometry(0.5, 8, 6);
        const positions = new Float32Array(coords.length * 3);
        
        coords.forEach((coord, i) => {
            positions[i * 3] = coord[0];
            positions[i * 3 + 1] = coord[1];
            positions[i * 3 + 2] = coord[2];
        });
        
        return {
            geometry,
            positions,
            count: coords.length
        };
    }
    
    static _createEdgeGeometry(coords, edges) {
        const positions = [];
        const weights = [];
        
        const edgeCount = Math.min(edges.coo_i.length, 1000); // Limit for performance
        
        for (let i = 0; i < edgeCount; i++) {
            const startCoord = coords[edges.coo_i[i]];
            const endCoord = coords[edges.coo_j[i]];
            
            positions.push(
                startCoord[0], startCoord[1], startCoord[2],
                endCoord[0], endCoord[1], endCoord[2]
            );
            
            weights.push(edges.coo_w[i]);
        }
        
        const geometry = new THREE.BufferGeometry();
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
        
        return {
            geometry,
            weights,
            count: edgeCount
        };
    }
    
    static _generateSurfaceFromNodes(coords) {
        // Simple convex hull approximation
        // For brain data, you might want to use more sophisticated surface reconstruction
        
        if (coords.length < 4) return null;
        
        // Create a simple mesh by connecting nearby nodes
        const geometry = new THREE.BufferGeometry();
        const vertices = [];
        const indices = [];
        
        coords.forEach(coord => {
            vertices.push(coord[0], coord[1], coord[2]);
        });
        
        // Simple triangulation (Delaunay would be better)
        for (let i = 0; i < coords.length - 2; i++) {
            if (i % 3 === 0) {
                indices.push(i, i + 1, i + 2);
            }
        }
        
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
        geometry.setIndex(indices);
        geometry.computeVertexNormals();
        
        return geometry;
    }
    
    static _sparseMatrixToCOO(W) {
        // Convert MATLAB-style sparse matrix to COO format
        // This would need to be implemented based on how the sparse matrix is represented
        // in the JavaScript context (likely already converted from MATLAB)
        
        const edges = { coo_i: [], coo_j: [], coo_w: [] };
        
        if (W.i && W.j && W.w) {
            // Already in COO format
            return {
                coo_i: W.i,
                coo_j: W.j, 
                coo_w: W.w
            };
        }
        
        // If W is a dense matrix representation, convert it
        if (Array.isArray(W) && Array.isArray(W[0])) {
            for (let i = 0; i < W.length; i++) {
                for (let j = i + 1; j < W[i].length; j++) { // Upper triangle only
                    if (W[i][j] !== 0) {
                        edges.coo_i.push(i);
                        edges.coo_j.push(j);
                        edges.coo_w.push(W[i][j]);
                    }
                }
            }
        }
        
        return edges;
    }
    
    /**
     * Convert MATLAB bct object data to BCT file format
     * @param {Object} bctData - Data from MATLAB bct.read_graph_gsp()
     * @returns {Object} BCT file structure
     */
    static matlabBCTToBCTFile(bctData) {
        const coords = bctData.coords || [];
        const W = bctData.W; // Sparse weight matrix
        const N = bctData.N || coords.length;
        
        // Convert sparse matrix to COO
        const edges = this._sparseMatrixToCOO(W);
        
        return {
            format: "bct",
            version: "1.0", 
            metadata: {
                description: "Converted from MATLAB BCT format",
                created: new Date().toISOString().split('T')[0],
                total_vertices: N,
                total_edges: edges.coo_i.length,
                source: "matlab_bct"
            },
            graph: {
                nodes: {
                    count: N,
                    coords: coords
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
}