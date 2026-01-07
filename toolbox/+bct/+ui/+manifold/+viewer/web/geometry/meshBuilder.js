/**
 * meshBuilder.js
 * 
 * Geometry construction utilities for BufferGeometry creation,
 * attribute synthesis, and geometry preprocessing.
 * 
 * Responsibilities:
 * - Default normal/UV computation when missing
 * - Spherical UV parameterization
 * - Tangent computation
 * - Geometry downsampling for helper visualization
 * 
 * Rules:
 * - No material creation
 * - No scene modification
 * - Pure geometry operations
 */

import * as THREE from 'three';

/**
 * Synthesize spherical UVs for a geometry if UVs are missing.
 * Uses bounding sphere center for stable parameterization.
 * 
 * @param {THREE.BufferGeometry} geometry - Geometry to add UVs to
 */
export function addSphericalUVs(geometry) {
  const pos = geometry.attributes.position;
  if (!pos) return;

  // Use bounding sphere center for stable parameterization
  geometry.computeBoundingSphere();
  const c = geometry.boundingSphere?.center ?? new THREE.Vector3();

  const uvs = new Float32Array(pos.count * 2);
  const v = new THREE.Vector3();

  for (let i = 0; i < pos.count; i++) {
    v.fromBufferAttribute(pos, i).sub(c).normalize();

    // longitude/latitude on unit sphere
    const lon = Math.atan2(v.z, v.x);  // [-pi, pi]
    const lat = Math.asin(v.y);        // [-pi/2, pi/2]

    const u = (lon + Math.PI) / (2 * Math.PI);
    const t = (lat + Math.PI / 2) / Math.PI;

    uvs[2 * i + 0] = u;
    uvs[2 * i + 1] = t;
  }

  geometry.setAttribute("uv", new THREE.BufferAttribute(uvs, 2));
  geometry.attributes.uv.needsUpdate = true;
  console.log('[meshBuilder] Synthesized spherical UVs');
}

/**
 * Ensure a geometry has normals, UVs, and tangents (if possible).
 * Computes missing attributes using default strategies.
 * 
 * @param {THREE.BufferGeometry} geometry - Geometry to process
 * @returns {Object} Status object with flags: { hasNormals, hasUVs, hasTangents }
 */
export function ensureGeometryAttributes(geometry) {
  const status = {
    hasNormals: false,
    hasUVs: false,
    hasTangents: false
  };

  if (!geometry) return status;

  // Ensure normals exist
  if (!geometry.attributes.normal) {
    geometry.computeVertexNormals();
    if (geometry.attributes.normal) {
      geometry.attributes.normal.needsUpdate = true;
      console.log('[meshBuilder] Computed vertex normals');
    }
  }
  status.hasNormals = !!geometry.attributes.normal;

  // Ensure UVs exist (synthesize spherical UVs if missing)
  if (!geometry.attributes.uv) {
    addSphericalUVs(geometry);
  }
  status.hasUVs = !!geometry.attributes.uv;

  // Compute tangents if we have all required attributes
  if (!geometry.attributes.tangent) {
    const hasRequiredAttrs = 
      geometry.index && 
      geometry.attributes.position && 
      geometry.attributes.normal && 
      geometry.attributes.uv;
    
    if (hasRequiredAttrs) {
      try {
        geometry.computeTangents();
        console.log('[meshBuilder] Computed tangents');
        status.hasTangents = true;
      } catch (err) {
        console.warn('[meshBuilder] Failed to compute tangents:', err.message);
      }
    }
  } else {
    status.hasTangents = true;
  }

  return status;
}

/**
 * Create a downsampled copy of a geometry for helper visualization.
 * Downsamples positions, normals, and optionally tangents.
 * 
 * @param {THREE.BufferGeometry} geometry - Source geometry
 * @param {number} downsampleFactor - Factor to downsample by (e.g., 100 = every 100th vertex)
 * @param {boolean} includeTangents - Whether to include tangent attribute
 * @returns {THREE.BufferGeometry|null} Downsampled geometry or null if invalid
 */
export function createDownsampledGeometry(geometry, downsampleFactor = 1, includeTangents = false) {
  if (!geometry) return null;

  const positions = geometry.attributes.position;
  const normals = geometry.attributes.normal;
  
  if (!positions || !normals) {
    console.warn('[meshBuilder] Cannot downsample: missing positions or normals');
    return null;
  }

  const downsampledPositions = [];
  const downsampledNormals = [];
  const downsampledTangents = includeTangents ? [] : null;

  // Check if tangents are available when requested
  const tangents = includeTangents ? geometry.attributes.tangent : null;
  if (includeTangents && !tangents) {
    console.warn('[meshBuilder] Tangents requested but not available');
    return null;
  }

  // Downsample attributes
  for (let i = 0; i < positions.count; i += downsampleFactor) {
    downsampledPositions.push(
      positions.getX(i),
      positions.getY(i),
      positions.getZ(i)
    );
    downsampledNormals.push(
      normals.getX(i),
      normals.getY(i),
      normals.getZ(i)
    );
    
    if (includeTangents && tangents) {
      downsampledTangents.push(
        tangents.getX(i),
        tangents.getY(i),
        tangents.getZ(i),
        tangents.getW(i)
      );
    }
  }

  // Create sparse geometry
  const sparseGeometry = new THREE.BufferGeometry();
  sparseGeometry.setAttribute('position', new THREE.Float32BufferAttribute(downsampledPositions, 3));
  sparseGeometry.setAttribute('normal', new THREE.Float32BufferAttribute(downsampledNormals, 3));
  
  if (includeTangents && downsampledTangents) {
    sparseGeometry.setAttribute('tangent', new THREE.Float32BufferAttribute(downsampledTangents, 4));
  }

  console.log(`[meshBuilder] Created downsampled geometry: ${downsampledPositions.length / 3} vertices (factor: ${downsampleFactor})`);
  
  return sparseGeometry;
}

/**
 * Create a temporary mesh with world transforms copied from a source mesh.
 * Useful for creating helper visualization meshes that match source transforms.
 * 
 * @param {THREE.BufferGeometry} geometry - Geometry for the mesh
 * @param {THREE.Mesh} sourceMesh - Source mesh to copy transforms from
 * @returns {THREE.Mesh} Temporary mesh with copied transforms
 */
export function createTransformedMesh(geometry, sourceMesh) {
  const tempMesh = new THREE.Mesh(geometry, sourceMesh.material);
  tempMesh.position.copy(sourceMesh.position);
  tempMesh.rotation.copy(sourceMesh.rotation);
  tempMesh.scale.copy(sourceMesh.scale);
  tempMesh.matrixWorld.copy(sourceMesh.matrixWorld);
  return tempMesh;
}
