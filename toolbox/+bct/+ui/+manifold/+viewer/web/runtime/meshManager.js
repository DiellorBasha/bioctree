/**
 * @file meshManager.js
 * MeshManager - Owns mesh/model lifecycle: load, attach, clear, dispose
 * Extracted from render.js as part of runtime refactor
 */

import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { ensureGeometryAttributes } from '../geometry/meshBuilder.js';
import { loadJSONGeometry } from '../loaders/jsonGeometryLoader.js';
import { disposeObject3D } from '../utils/dispose.js';

const BASE_COLOR_HEX = 0x999999; // [0.6 0.6 0.6]

/**
 * MeshManager - Manages mesh/model loading and lifecycle
 */
export class MeshManager {
  /**
   * @param {Object} viewerCore - ViewerCore instance
   */
  constructor(viewerCore) {
    this.viewerCore = viewerCore;
    this.modelRoot = null;
    this.loadedScene = null;
  }

  /**
   * Load model from URL - detects file type and uses appropriate loader
   * @param {string} url - Path to model file (.glb, .gltf, or .json)
   * @returns {Promise<THREE.Group>} - The loaded scene
   */
  async loadModelFromUrl(url) {
    const ext = url.split('.').pop().toLowerCase();
    
    if (ext === 'glb' || ext === 'gltf') {
      return this.loadGLB(url);
    } else if (ext === 'json') {
      return this.loadJSON(url);
    } else {
      throw new Error(`Unsupported file format: ${ext}`);
    }
  }

  /**
   * Load GLB/GLTF file
   * @param {string} url - Path to GLB file
   * @returns {Promise<THREE.Group>} - The loaded scene
   */
  async loadGLB(url) {
    // Clear any existing model
    this.clearModel();

    const manager = new THREE.LoadingManager();
    manager.onError = (u) => console.error("Loading error:", u);

    const loader = new GLTFLoader(manager);
    const gltf = await new Promise((resolve, reject) => {
      loader.load(url, resolve, null, reject);
    });

    this.modelRoot = new THREE.Group();
    this.loadedScene = gltf.scene;

    // Apply defaults to all meshes
    this.loadedScene.traverse((obj) => {
      if (!obj.isMesh) return;

      const geom = obj.geometry;
      if (geom) {
        // Use meshBuilder to ensure all geometry attributes
        ensureGeometryAttributes(geom);
      }

      // Create and cache both base and wireframe materials
      const baseMat = new THREE.MeshStandardMaterial({
        color: BASE_COLOR_HEX,
        roughness: 0.85,
        metalness: 0.0,
        side: THREE.DoubleSide,
      });

      const wireMat = new THREE.MeshBasicMaterial({
        color: 0xffffff,
        wireframe: true,
        side: THREE.DoubleSide,
      });

      obj.userData.baseMaterial = baseMat;
      obj.userData.wireMaterial = wireMat;

      // Start in base mode
      obj.material = baseMat;
    });

    this.modelRoot.add(this.loadedScene);

    // IMPORTANT: Add GLB to threejs frame root (identity transform)
    // GLB files are already Y-up from MATLAB export, no transform needed
    this.viewerCore.roots.threejs.add(this.modelRoot);

    console.log('[MeshManager.loadGLB] Added to scene. modelRoot:', this.modelRoot);
    console.log('[MeshManager.loadGLB] Scene children:', this.viewerCore.roots.threejs.children.length);

    return this.loadedScene;
  }

  /**
   * Load JSON geometry file
   * @param {string} url - Path to JSON geometry file
   * @returns {Promise<THREE.Group>} - The loaded scene
   */
  async loadJSON(url) {
    // Clear any existing model
    this.clearModel();

    const geometry = await loadJSONGeometry(url);

    // Ensure all geometry attributes (same as GLB loading)
    ensureGeometryAttributes(geometry);

    // Create materials (match GLB loading exactly)
    const baseMat = new THREE.MeshStandardMaterial({
      color: BASE_COLOR_HEX,
      roughness: 0.85,
      metalness: 0.0,
      side: THREE.DoubleSide,
    });

    const wireMat = new THREE.MeshBasicMaterial({
      color: 0xffffff,
      wireframe: true,
      side: THREE.DoubleSide,
    });

    // Create mesh with base material
    const mesh = new THREE.Mesh(geometry, baseMat);
    
    // Store materials in userData
    mesh.userData.baseMaterial = baseMat;
    mesh.userData.wireMaterial = wireMat;

    // Setup model root and loaded scene (match GLB structure)
    this.modelRoot = new THREE.Group();
    this.loadedScene = new THREE.Group();
    this.loadedScene.add(mesh);
    this.modelRoot.add(this.loadedScene);

    // IMPORTANT: Add JSON to MATLAB frame root (applies Z-up → Y-up transform)
    // Raw JSON data is in MATLAB Z-up coordinates and needs conversion
    this.viewerCore.roots.matlab.add(this.modelRoot);

    console.log('[MeshManager.loadJSON] Added to scene. modelRoot:', this.modelRoot);
    console.log('[MeshManager.loadJSON] Scene children:', this.viewerCore.roots.matlab.children.length);

    return this.loadedScene;
  }

  /**
   * Clear the current model and dispose of resources
   */
  clearModel() {
    console.log('[MeshManager.clearModel] Clearing model. Current modelRoot:', this.modelRoot);
    if (this.modelRoot) {
      // Remove from both possible frame roots (could be in either depending on file type)
      this.viewerCore.roots.threejs.remove(this.modelRoot);
      this.viewerCore.roots.matlab.remove(this.modelRoot);
      disposeObject3D(this.modelRoot);
      console.log('[MeshManager.clearModel] Model removed and disposed');
    }
    this.modelRoot = null;
    this.loadedScene = null;
  }

  /**
   * Get the loaded scene (for picking, visualization, etc.)
   * @returns {THREE.Group|null}
   */
  getLoadedScene() {
    return this.loadedScene;
  }

  /**
   * Get the model root group
   * @returns {THREE.Group|null}
   */
  getModelRoot() {
    return this.modelRoot;
  }

  /**
   * Get the bounds of the loaded model
   * @returns {Object} - { radius: number, box: THREE.Box3, center: THREE.Vector3 }
   */
  getBounds() {
    if (!this.modelRoot) {
      return { radius: 100, box: null, center: new THREE.Vector3() };
    }

    const box = new THREE.Box3().setFromObject(this.modelRoot);
    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    const radius = Math.max(size.x, size.y, size.z) / 2;

    return { radius, box, center };
  }
}
