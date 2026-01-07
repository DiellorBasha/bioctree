/**
 * @file visualizationManager.js
 * VisualizationManager - Owns visualization state application and helper visuals
 * Extracted from render.js as part of runtime refactor
 */

import * as THREE from "three";
import { VertexNormalsHelper } from "three/addons/helpers/VertexNormalsHelper.js";
import { VertexTangentsHelper } from "three/addons/helpers/VertexTangentsHelper.js";
import { createDownsampledGeometry, createTransformedMesh } from '../geometry/meshBuilder.js';

/**
 * VisualizationManager - Manages visualization state application and helper visuals
 */
export class VisualizationManager {
  /**
   * @param {Object} viewerCore - ViewerCore instance
   * @param {Object} meshManager - MeshManager instance
   * @param {Object} lightRig - Light rig reference (optional)
   * @param {Object} axesGizmo - Axes gizmo reference (optional)
   */
  constructor(viewerCore, meshManager, lightRig = null, axesGizmo = null) {
    this.viewerCore = viewerCore;
    this.meshManager = meshManager;
    this.lightRig = lightRig;
    this.axesGizmo = axesGizmo;
    
    // Helper visuals owned by this manager
    this.normalsHelper = null;
    this.tangentsHelper = null;
  }

  /**
   * Apply visualization state to the loaded model
   * @param {Object} vizState - Visualization state object
   */
  applyState(vizState) {
    this.updateSurface(vizState);
    this.updateEdges(vizState);
    this.updateHelpers(vizState);
    this.updateScene(vizState);
  }

  /**
   * Called when model changes (load/clear) to rebuild helpers if needed
   */
  onModelChanged() {
    // Dispose any existing helpers
    this.disposeHelpers();
  }

  /**
   * Called on resize (if needed for helper materials)
   * @param {number} w - Width
   * @param {number} h - Height
   */
  onResize(w, h) {
    // Currently no resolution-dependent helpers
    // Add here if needed in future
  }

  /**
   * Dispose of helper visuals
   */
  dispose() {
    this.disposeHelpers();
  }

  /**
   * Update surface properties (visibility, opacity, shading)
   * @private
   */
  updateSurface(vizState) {
    const loadedScene = this.meshManager.getLoadedScene();
    if (!loadedScene) return;

    loadedScene.traverse((obj) => {
      if (!obj.isMesh) return;

      const baseMat = obj.userData.baseMaterial;
      const wireMat = obj.userData.wireMaterial;

      if (!baseMat || !wireMat) return;

      // Apply visibility
      obj.material.visible = vizState.surface.visible;
      
      // Apply opacity
      baseMat.opacity = vizState.surface.opacity;
      baseMat.transparent = vizState.surface.opacity < 1.0;
      
      // Apply shading
      baseMat.flatShading = (vizState.surface.shading === 'flat');
      baseMat.needsUpdate = true;
    });
  }

  /**
   * Update edge/wireframe properties
   * @private
   */
  updateEdges(vizState) {
    const loadedScene = this.meshManager.getLoadedScene();
    if (!loadedScene) return;

    loadedScene.traverse((obj) => {
      if (!obj.isMesh) return;

      const baseMat = obj.userData.baseMaterial;
      const wireMat = obj.userData.wireMaterial;

      if (!baseMat || !wireMat) return;

      // Swap materials based on wireframe state
      if (vizState.surface.visible) {
        obj.material = vizState.edges.wireframe ? wireMat : baseMat;
        obj.material.visible = true;
      } else {
        obj.material.visible = false;
      }
      
      // Update wireframe color
      if (vizState.edges.wireframe) {
        wireMat.color.set(vizState.edges.color);
      }
      
      obj.material.needsUpdate = true;
    });
  }

  /**
   * Update helper visuals (normals, tangents)
   * @private
   */
  updateHelpers(vizState) {
    const loadedScene = this.meshManager.getLoadedScene();
    
    // Update vertex normals
    if (vizState.helpers.vertexNormals) {
      this.syncNormalsVisibility(vizState);
    } else {
      if (this.normalsHelper) {
        this.viewerCore.scene.remove(this.normalsHelper);
        this.normalsHelper = null;
      }
    }
    
    // Update tangents
    if (vizState.helpers.tangents) {
      this.syncTangentsVisibility(vizState);
    } else {
      if (this.tangentsHelper) {
        this.viewerCore.scene.remove(this.tangentsHelper);
        this.tangentsHelper = null;
      }
    }
    
    // Restore mesh visibility if both helpers are off
    if (!vizState.helpers.vertexNormals && !vizState.helpers.tangents) {
      this.restoreMeshVisibility(vizState);
    }
  }

  /**
   * Update scene properties (lighting, axes, background)
   * @private
   */
  updateScene(vizState) {
    // Update lighting visibility
    if (this.lightRig) {
      this.lightRig.visible = vizState.scene.lighting;
    }
    
    // Update axes gizmo
    if (this.axesGizmo) {
      this.axesGizmo.setEnabled(vizState.scene.axes);
    }
    
    // Update background color
    if (this.viewerCore.renderer) {
      this.viewerCore.renderer.setClearColor(vizState.scene.background);
    }
  }

  /**
   * Sync normals helper visibility
   * @private
   */
  syncNormalsVisibility(vizState) {
    const loadedScene = this.meshManager.getLoadedScene();
    if (!loadedScene) return;

    // Remove existing helper if present
    if (this.normalsHelper) {
      this.viewerCore.scene.remove(this.normalsHelper);
      this.normalsHelper = null;
    }

    // Hide mesh only if wireframe is NOT active
    if (loadedScene && !vizState.edges.wireframe) {
      this.hideMeshMaterials();
    }

    // Create vertex normals helpers for all meshes
    let meshCount = 0;
    
    loadedScene.traverse((obj) => {
      if (!obj.isMesh) return;
      meshCount++;

      const downsampleFactor = 1; // Testing: no downsampling (was 100)
      const geometry = obj.geometry;
      
      console.log(`[Manifold3] Normals - Mesh ${meshCount}: has geometry=${!!geometry}`);
      
      // Create downsampled geometry using meshBuilder
      const sparseGeometry = createDownsampledGeometry(geometry, downsampleFactor, false);
      if (!sparseGeometry) return;
      
      // Create temporary mesh with transforms copied from source
      const tempMesh = createTransformedMesh(sparseGeometry, obj);
      
      // Create normals helper (red)
      const helper = new VertexNormalsHelper(tempMesh, 2, 0xff0000);
      
      if (!this.normalsHelper) {
        this.normalsHelper = new THREE.Group();
        this.viewerCore.scene.add(this.normalsHelper);
      }
      
      this.normalsHelper.add(helper);
    });
    
    console.log(`[Manifold3] Normals: ${meshCount} meshes`);
  }

  /**
   * Sync tangents helper visibility
   * @private
   */
  syncTangentsVisibility(vizState) {
    const loadedScene = this.meshManager.getLoadedScene();
    if (!loadedScene) return;

    // Remove existing helper if present
    if (this.tangentsHelper) {
      this.viewerCore.scene.remove(this.tangentsHelper);
      this.tangentsHelper = null;
    }

    // Hide mesh only if wireframe is NOT active
    if (loadedScene && !vizState.edges.wireframe) {
      this.hideMeshMaterials();
    }

    // Create vertex tangents helpers for all meshes
    let meshCount = 0;
    let tangentCount = 0;
    
    loadedScene.traverse((obj) => {
      if (!obj.isMesh) return;
      meshCount++;

      const downsampleFactor = 1; // Testing: no downsampling (was 100)
      const geometry = obj.geometry;
      const positions = geometry.attributes.position;
      const normals = geometry.attributes.normal;
      const tangents = geometry.attributes.tangent;
      const uvs = geometry.attributes.uv;
      
      console.log(`[Manifold3] Tangents - Mesh ${meshCount}: positions=${!!positions}, normals=${!!normals}, tangents=${!!tangents}, uvs=${!!uvs}`);
      
      if (!positions || !normals || !tangents) return;

      tangentCount++;

      // Create downsampled geometry with tangents using meshBuilder
      const sparseGeometry = createDownsampledGeometry(geometry, downsampleFactor, true);
      if (!sparseGeometry) return;
      
      // Create temporary mesh with transforms copied from source
      const tempMesh = createTransformedMesh(sparseGeometry, obj);
      
      // Create tangents helper (cyan)
      const helper = new VertexTangentsHelper(tempMesh, 2, 0x00ffff);
      
      if (!this.tangentsHelper) {
        this.tangentsHelper = new THREE.Group();
        this.viewerCore.scene.add(this.tangentsHelper);
      }
      
      this.tangentsHelper.add(helper);
      console.log(`[Manifold3] Created tangents helper for mesh ${meshCount}`);
    });
    
    console.log(`[Manifold3] Tangents: ${meshCount} meshes, ${tangentCount} with tangents`);
  }

  /**
   * Hide mesh materials (for helper display)
   * @private
   */
  hideMeshMaterials() {
    const loadedScene = this.meshManager.getLoadedScene();
    if (!loadedScene) return;
    loadedScene.traverse((obj) => {
      if (obj.isMesh && obj.material) {
        obj.material.visible = false;
      }
    });
  }

  /**
   * Restore mesh visibility
   * @private
   */
  restoreMeshVisibility(vizState) {
    const loadedScene = this.meshManager.getLoadedScene();
    if (!loadedScene) return;
    loadedScene.traverse((obj) => {
      if (!obj.isMesh) return;
      const baseMat = obj.userData.baseMaterial;
      const wireMat = obj.userData.wireMaterial;
      if (!baseMat || !wireMat) return;
      
      // Restore appropriate material based on wireframe toggle
      obj.material = vizState.edges.wireframe ? wireMat : baseMat;
      obj.material.visible = vizState.surface.visible;
    });
  }

  /**
   * Dispose of all helper visuals
   * @private
   */
  disposeHelpers() {
    if (this.normalsHelper) {
      this.viewerCore.scene.remove(this.normalsHelper);
      this.normalsHelper = null;
    }
    
    if (this.tangentsHelper) {
      this.viewerCore.scene.remove(this.tangentsHelper);
      this.tangentsHelper = null;
    }
  }

  /**
   * Update normals helpers in render loop (if needed)
   */
  updateNormalsHelpers() {
    if (this.normalsHelper && this.normalsHelper.children) {
      this.normalsHelper.children.forEach(helper => {
        if (helper.update) helper.update();
      });
    }
  }

  /**
   * Update tangents helpers in render loop (if needed)
   */
  updateTangentsHelpers() {
    if (this.tangentsHelper && this.tangentsHelper.children) {
      this.tangentsHelper.children.forEach(helper => {
        if (helper.update) helper.update();
      });
    }
  }
}
