/**
 * pointCloud.js
 * 
 * Point cloud rendering utilities for marking vertices/faces.
 * Creates sphere markers similar to experimental/gp-trivialconnections.html
 * 
 * Responsibilities:
 * - Generate sphere markers at specified positions
 * - Support per-point colors and sizes
 * - Use InstancedMesh for performance with many points
 * - Support individual spheres for small counts
 */

import * as THREE from "three";

/**
 * Create a point cloud visualization with sphere markers
 * 
 * @param {Object} config - Configuration object
 * @param {Float32Array|Array} config.positions - Positions [x,y,z,x,y,z,...] (flat array)
 * @param {number} [config.radius=1.0] - Sphere radius (uniform for all points)
 * @param {number|Array} [config.color=0xff0000] - Color (hex or array of hex values)
 * @param {number} [config.opacity=1.0] - Opacity (0-1)
 * @param {boolean} [config.transparent=false] - Enable transparency
 * @param {number} [config.widthSegments=16] - Sphere geometry width segments
 * @param {number} [config.heightSegments=12] - Sphere geometry height segments
 * @param {boolean} [config.useInstancing=true] - Use InstancedMesh for performance
 * 
 * @returns {THREE.Object3D} Group or InstancedMesh containing the point markers
 */
export function createPointCloud(config) {
  const {
    positions,
    radius = 1.0,
    color = 0xff0000,
    opacity = 1.0,
    transparent = false,
    widthSegments = 16,
    heightSegments = 12,
    useInstancing = false
  } = config;

  if (!positions || positions.length === 0) {
    console.error('[createPointCloud] No positions provided');
    return new THREE.Group();
  }

  const numPoints = positions.length / 3;

  // Create sphere geometry (shared for all instances)
  const sphereGeometry = new THREE.SphereGeometry(radius, widthSegments, heightSegments);

  // Check if we have per-point colors
  const hasPerPointColors = Array.isArray(color) && color.length > 1;
  
  if (useInstancing && !hasPerPointColors) {
    // Use InstancedMesh for performance (uniform color)
    const material = new THREE.MeshStandardMaterial({
      color: Array.isArray(color) ? color[0] : color,
      opacity: opacity,
      transparent: transparent,
      roughness: 0.5,
      metalness: 0.1
    });

    const instancedMesh = new THREE.InstancedMesh(sphereGeometry, material, numPoints);
    
    // Set instance transform matrices
    const matrix = new THREE.Matrix4();
    const position = new THREE.Vector3();

    for (let i = 0; i < numPoints; i++) {
      position.set(
        positions[i * 3],
        positions[i * 3 + 1],
        positions[i * 3 + 2]
      );
      
      matrix.setPosition(position);
      instancedMesh.setMatrixAt(i, matrix);
    }

    instancedMesh.instanceMatrix.needsUpdate = true;
    instancedMesh.userData.pointCount = numPoints;
    instancedMesh.userData.type = 'pointCloud';

    return instancedMesh;
  } else {
    // Use individual meshes (supports per-point colors or small counts)
    const group = new THREE.Group();
    group.userData.pointCount = numPoints;
    group.userData.type = 'pointCloud';

    for (let i = 0; i < numPoints; i++) {
      const position = new THREE.Vector3(
        positions[i * 3],
        positions[i * 3 + 1],
        positions[i * 3 + 2]
      );

      // Get color for this point
      const pointColor = hasPerPointColors ? color[i] : color;

      const material = new THREE.MeshStandardMaterial({
        color: pointColor,
        opacity: opacity,
        transparent: transparent,
        roughness: 0.5,
        metalness: 0.1
      });

      const sphere = new THREE.Mesh(sphereGeometry.clone(), material);
      sphere.position.copy(position);
      sphere.userData.pointIndex = i;

      group.add(sphere);
    }

    return group;
  }
}

/**
 * Create point cloud from vertex indices
 * 
 * @param {Object} config - Configuration object
 * @param {Float32Array|Array} config.vertices - All vertices [x,y,z,...] (flat array)
 * @param {Array<number>} config.indices - Vertex indices to mark
 * @param {number} [config.radius=1.0] - Sphere radius
 * @param {number|Array} [config.color=0xff0000] - Color (hex or array of hex values)
 * @param {number} [config.opacity=1.0] - Opacity (0-1)
 * @param {boolean} [config.transparent=false] - Enable transparency
 * 
 * @returns {THREE.Object3D} Group or InstancedMesh containing the point markers
 */
export function createPointCloudFromVertexIndices(config) {
  const {
    vertices,
    indices,
    radius = 1.0,
    color = 0xff0000,
    opacity = 1.0,
    transparent = false
  } = config;

  if (!vertices || vertices.length === 0) {
    console.error('[createPointCloudFromVertexIndices] No vertices provided');
    return new THREE.Group();
  }

  if (!indices || indices.length === 0) {
    console.error('[createPointCloudFromVertexIndices] No indices provided');
    return new THREE.Group();
  }

  // Extract positions for the specified indices
  const positions = new Float32Array(indices.length * 3);
  
  for (let i = 0; i < indices.length; i++) {
    const vertexIndex = indices[i];
    positions[i * 3] = vertices[vertexIndex * 3];
    positions[i * 3 + 1] = vertices[vertexIndex * 3 + 1];
    positions[i * 3 + 2] = vertices[vertexIndex * 3 + 2];
  }

  return createPointCloud({
    positions: positions,
    radius: radius,
    color: color,
    opacity: opacity,
    transparent: transparent
  });
}

/**
 * Update point cloud positions (for animation)
 * 
 * @param {THREE.Object3D} pointCloud - Point cloud object (Group or InstancedMesh)
 * @param {Float32Array|Array} newPositions - New positions [x,y,z,...]
 * @returns {boolean} True if update succeeded
 */
export function updatePointCloudPositions(pointCloud, newPositions) {
  if (!pointCloud || !newPositions) {
    console.error('[updatePointCloudPositions] Invalid arguments');
    return false;
  }

  const numPoints = newPositions.length / 3;

  if (pointCloud.isInstancedMesh) {
    // Update InstancedMesh matrices
    if (numPoints !== pointCloud.count) {
      console.error('[updatePointCloudPositions] Position count mismatch');
      return false;
    }

    const matrix = new THREE.Matrix4();
    const position = new THREE.Vector3();

    for (let i = 0; i < numPoints; i++) {
      position.set(
        newPositions[i * 3],
        newPositions[i * 3 + 1],
        newPositions[i * 3 + 2]
      );
      
      pointCloud.getMatrixAt(i, matrix);
      matrix.setPosition(position);
      pointCloud.setMatrixAt(i, matrix);
    }

    pointCloud.instanceMatrix.needsUpdate = true;
    return true;
  } else if (pointCloud.isGroup) {
    // Update individual mesh positions
    if (numPoints !== pointCloud.children.length) {
      console.error('[updatePointCloudPositions] Position count mismatch');
      return false;
    }

    for (let i = 0; i < numPoints; i++) {
      const sphere = pointCloud.children[i];
      sphere.position.set(
        newPositions[i * 3],
        newPositions[i * 3 + 1],
        newPositions[i * 3 + 2]
      );
    }

    return true;
  }

  return false;
}
