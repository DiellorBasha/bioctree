/**
 * layerManager.js
 * 
 * Manages labeled data layers for visualization (scalars, vectors, points).
 * 
 * Responsibilities:
 * - Track named layers by type (scalar/vector/point)
 * - Support add/set/clear operations with labels
 * - Provide access to layer data and metadata
 * - Manage layer disposal and cleanup
 * 
 * Layer Types:
 * - scalar: Vertex color mapping
 * - vector: LineSegments-based vector field visualizations
 * - point: Sphere/marker visualizations
 */

export class LayerManager {
  constructor() {
    // Storage: Map<layerName, layerData>
    this.scalarLayers = new Map();
    this.vectorLayers = new Map();
    this.pointLayers = new Map();
    this.lineLayers = new Map();
  }

  /* -------------------- Scalar Layers -------------------- */

  /**
   * Add or update a scalar layer
   * @param {string} name - Layer name
   * @param {Object} config - Layer configuration
   * @param {Float32Array|Array} config.data - Scalar values
   * @param {THREE.Object3D} config.meshObject - Three.js mesh object
   * @param {Object} config.metadata - Optional metadata (colormap, range, etc.)
   */
  setScalarLayer(name, config) {
    // Dispose old layer if exists
    if (this.scalarLayers.has(name)) {
      this.clearScalarLayer(name);
    }

    this.scalarLayers.set(name, {
      type: 'scalar',
      name: name,
      data: config.data,
      meshObject: config.meshObject,
      metadata: config.metadata || {},
      timestamp: Date.now()
    });
  }

  /**
   * Get a scalar layer by name
   * @param {string} name - Layer name
   * @returns {Object|null} Layer data or null if not found
   */
  getScalarLayer(name) {
    return this.scalarLayers.get(name) || null;
  }

  /**
   * Get all scalar layer names
   * @returns {string[]} Array of layer names
   */
  getScalarLayerNames() {
    return Array.from(this.scalarLayers.keys());
  }

  /**
   * Clear a specific scalar layer
   * @param {string} name - Layer name
   * @returns {boolean} True if layer was found and cleared
   */
  clearScalarLayer(name) {
    const layer = this.scalarLayers.get(name);
    if (!layer) return false;

    // Cleanup would go here (e.g., restore original mesh colors)
    // For now just remove from map
    this.scalarLayers.delete(name);
    return true;
  }

  /**
   * Clear all scalar layers
   */
  clearAllScalarLayers() {
    this.scalarLayers.forEach((layer, name) => {
      this.clearScalarLayer(name);
    });
  }

  /* -------------------- Vector Layers -------------------- */

  /**
   * Add or update a vector layer
   * @param {string} name - Layer name
   * @param {Object} config - Layer configuration
   * @param {THREE.Object3D} config.quiverObject - Three.js vector visualization (LineSegments)
   * @param {Object} config.metadata - Optional metadata (style, scale, etc.)
   */
  setVectorLayer(name, config) {
    // Dispose old layer if exists
    if (this.vectorLayers.has(name)) {
      this.clearVectorLayer(name);
    }

    this.vectorLayers.set(name, {
      type: 'vector',
      name: name,
      quiverObject: config.quiverObject,
      metadata: config.metadata || {},
      timestamp: Date.now()
    });
  }

  /**
   * Get a vector layer by name
   * @param {string} name - Layer name
   * @returns {Object|null} Layer data or null if not found
   */
  getVectorLayer(name) {
    return this.vectorLayers.get(name) || null;
  }

  /**
   * Get all vector layer names
   * @returns {string[]} Array of layer names
   */
  getVectorLayerNames() {
    return Array.from(this.vectorLayers.keys());
  }

  /**
   * Clear a specific vector layer
   * @param {string} name - Layer name
   * @returns {boolean} True if layer was found and cleared
   */
  clearVectorLayer(name) {
    const layer = this.vectorLayers.get(name);
    if (!layer) return false;

    // Dispose three.js objects
    const obj = layer.quiverObject;
    if (obj) {
      if (obj.parent) {
        obj.parent.remove(obj);
      }
      obj.geometry?.dispose();
      obj.material?.dispose();
    }

    this.vectorLayers.delete(name);
    return true;
  }

  /**
   * Clear all vector layers
   */
  clearAllVectorLayers() {
    this.vectorLayers.forEach((layer, name) => {
      this.clearVectorLayer(name);
    });
  }

  /* -------------------- Point Layers -------------------- */

  /**
   * Add or update a point layer
   * @param {string} name - Layer name
   * @param {Object} config - Layer configuration
   * @param {THREE.Object3D} config.pointObject - Three.js points/spheres object
   * @param {Object} config.metadata - Optional metadata (size, color, etc.)
   */
  setPointLayer(name, config) {
    // Dispose old layer if exists
    if (this.pointLayers.has(name)) {
      this.clearPointLayer(name);
    }

    this.pointLayers.set(name, {
      type: 'point',
      name: name,
      pointObject: config.pointObject,
      metadata: config.metadata || {},
      timestamp: Date.now()
    });
  }

  /**
   * Get a point layer by name
   * @param {string} name - Layer name
   * @returns {Object|null} Layer data or null if not found
   */
  getPointLayer(name) {
    return this.pointLayers.get(name) || null;
  }

  /**
   * Get all point layer names
   * @returns {string[]} Array of layer names
   */
  getPointLayerNames() {
    return Array.from(this.pointLayers.keys());
  }

  /**
   * Clear a specific point layer
   * @param {string} name - Layer name
   * @returns {boolean} True if layer was found and cleared
   */
  clearPointLayer(name) {
    const layer = this.pointLayers.get(name);
    if (!layer) return false;

    // Dispose three.js objects
    const obj = layer.pointObject;
    if (obj) {
      if (obj.parent) {
        obj.parent.remove(obj);
      }
      obj.geometry?.dispose();
      obj.material?.dispose();
    }

    this.pointLayers.delete(name);
    return true;
  }

  /**
   * Clear all point layers
   */
  clearAllPointLayers() {
    this.pointLayers.forEach((layer, name) => {
      this.clearPointLayer(name);
    });
  }

  /* -------------------- Line Layers -------------------- */

  /**
   * Add or update a line layer
   * @param {string} name - Layer name
   * @param {Object} config - Layer configuration
   * @param {THREE.LineSegments2} config.lineObject - Three.js line segments object
   * @param {Object} config.metadata - Optional metadata (segmentCount, color, linewidth, etc.)
   */
  setLineLayer(name, config) {
    // Dispose old layer if exists
    if (this.lineLayers.has(name)) {
      this.clearLineLayer(name);
    }

    this.lineLayers.set(name, {
      type: 'line',
      name: name,
      lineObject: config.lineObject,
      metadata: config.metadata || {},
      timestamp: Date.now()
    });
  }

  /**
   * Get a line layer by name
   * @param {string} name - Layer name
   * @returns {Object|null} Layer data or null if not found
   */
  getLineLayer(name) {
    return this.lineLayers.get(name) || null;
  }

  /**
   * Get all line layer names
   * @returns {string[]} Array of layer names
   */
  getLineLayerNames() {
    return Array.from(this.lineLayers.keys());
  }

  /**
   * Clear a specific line layer
   * @param {string} name - Layer name
   * @returns {boolean} True if layer was found and cleared
   */
  clearLineLayer(name) {
    const layer = this.lineLayers.get(name);
    if (!layer) return false;

    // Dispose three.js objects
    const obj = layer.lineObject;
    if (obj) {
      if (obj.parent) {
        obj.parent.remove(obj);
      }
      obj.geometry?.dispose();
      obj.material?.dispose();
    }

    this.lineLayers.delete(name);
    return true;
  }

  /**
   * Clear all line layers
   */
  clearAllLineLayers() {
    this.lineLayers.forEach((layer, name) => {
      this.clearLineLayer(name);
    });
  }

  /* -------------------- Global Operations -------------------- */

  /**
   * Clear all layers (scalars, vectors, points, lines)
   */
  clearAll() {
    this.clearAllScalarLayers();
    this.clearAllVectorLayers();
    this.clearAllPointLayers();
    this.clearAllLineLayers();
  }

  /**
   * Get summary of all layers
   * @returns {Object} Summary with counts and names
   */
  getSummary() {
    return {
      scalars: {
        count: this.scalarLayers.size,
        names: this.getScalarLayerNames()
      },
      vectors: {
        count: this.vectorLayers.size,
        names: this.getVectorLayerNames()
      },
      points: {
        count: this.pointLayers.size,
        names: this.getPointLayerNames()
      },
      lines: {
        count: this.lineLayers.size,
        names: this.getLineLayerNames()
      }
    };
  }
}
