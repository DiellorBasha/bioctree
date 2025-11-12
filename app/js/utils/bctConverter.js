/**
 * BCT format converter utilities
 * Handles conversion between BCT graph data and Three.js meshes
 */

import * as THREE from 'three';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';

export class BCTConverter {
    /**
     * Create a BCT-compatible graph structure from mesh data
     */
    static meshToGraph(vertices, faces) {
        const edges = new Map();
        const edgeList = [];
        
        // Extract edges from triangular faces
        for (let i = 0; i < faces.length; i += 3) {
            const v1 = faces[i];
            const v2 = faces[i + 1];
            const v3 = faces[i + 2];
            
            // Add edges (undirected, so we store both directions)
            this.addEdge(edges, edgeList, v1, v2, vertices);
            this.addEdge(edges, edgeList, v2, v3, vertices);
            this.addEdge(edges, edgeList, v3, v1, vertices);
        }
        
        // Convert vertices to coordinates array
        const coords = [];
        for (let i = 0; i < vertices.length; i += 3) {
            coords.push([vertices[i], vertices[i + 1], vertices[i + 2]]);
        }
        
        return {
            nodes: coords,
            edges: edgeList,
            nodeCount: coords.length,
            edgeCount: edgeList.length
        };
    }
    
    static addEdge(edges, edgeList, v1, v2, vertices) {
        const key = `${Math.min(v1, v2)}-${Math.max(v1, v2)}`;
        if (!edges.has(key)) {
            edges.set(key, true);
            
            // Calculate edge weight as Euclidean distance
            const x1 = vertices[v1 * 3], y1 = vertices[v1 * 3 + 1], z1 = vertices[v1 * 3 + 2];
            const x2 = vertices[v2 * 3], y2 = vertices[v2 * 3 + 1], z2 = vertices[v2 * 3 + 2];
            const weight = Math.sqrt((x2-x1)**2 + (y2-y1)**2 + (z2-z1)**2);
            
            edgeList.push({
                i: v1,        // 0-based indexing for BCT format
                j: v2,
                weight: weight
            });
        }
    }
    
    /**
     * Create Three.js geometry from BCT graph data
     */
    static graphToGeometry(bctGraph) {
        const geometry = new THREE.BufferGeometry();
        
        if (!bctGraph.nodes || !bctGraph.faces) {
            throw new Error('BCT graph must contain nodes and faces data');
        }
        
        // Set vertices
        const vertices = new Float32Array(bctGraph.nodes.flat());
        geometry.setAttribute('position', new THREE.BufferAttribute(vertices, 3));
        
        // Set faces
        if (bctGraph.faces) {
            const indices = new Uint32Array(bctGraph.faces.flat());
            geometry.setIndex(new THREE.BufferAttribute(indices, 1));
        }
        
        // Compute normals for proper lighting
        geometry.computeVertexNormals();
        
        return geometry;
    }
    
    /**
     * Create a simple BCT file structure
     */
    static createBCTFile(leftGraph, rightGraph, metadata = {}) {
        return {
            version: '1.0.0',
            metadata: {
                description: 'BCT file generated from fsaverage mesh',
                created: new Date().toISOString(),
                hemisphere: 'bilateral',
                ...metadata
            },
            axes: {
                time_s: [0], // Single timepoint
                node_id: Array.from({length: leftGraph.nodeCount + rightGraph.nodeCount}, (_, i) => i),
                freq_hz: [0] // No frequency data
            },
            graph: {
                nodes: {
                    coords: [
                        ...leftGraph.nodes,
                        ...rightGraph.nodes.map(coord => [coord[0] + 100, coord[1], coord[2]]) // Offset right hemisphere
                    ]
                },
                edges: {
                    coo_i: [...leftGraph.edges.map(e => e.i), ...rightGraph.edges.map(e => e.i + leftGraph.nodeCount)],
                    coo_j: [...leftGraph.edges.map(e => e.j), ...rightGraph.edges.map(e => e.j + leftGraph.nodeCount)],
                    coo_w: [...leftGraph.edges.map(e => e.weight), ...rightGraph.edges.map(e => e.weight)]
                }
            },
            signals: {
                raw: new Array(leftGraph.nodeCount + rightGraph.nodeCount).fill(0) // Placeholder signal data
            }
        };
    }
    
    /**
     * Export Three.js scene to GLB format
     */
    static async exportToGLB(scene) {
        return new Promise((resolve, reject) => {
            const exporter = new GLTFExporter();
            
            exporter.parse(
                scene,
                (result) => {
                    const blob = new Blob([result], { type: 'application/octet-stream' });
                    resolve(blob);
                },
                (error) => {
                    reject(error);
                },
                { binary: true }
            );
        });
    }
    
    /**
     * Download a blob as a file
     */
    static downloadBlob(blob, filename) {
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = filename;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
    }
    
    /**
     * Parse uploaded BCT file (simplified version for demo)
     */
    static async parseBCTFile(file) {
        try {
            const text = await file.text();
            const bctData = JSON.parse(text);
            
            if (!bctData.graph || !bctData.graph.nodes || !bctData.graph.edges) {
                throw new Error('Invalid BCT file format');
            }
            
            return bctData;
        } catch (error) {
            console.error('Error parsing BCT file:', error);
            throw new Error('Failed to parse BCT file. Expected JSON format.');
        }
    }
}