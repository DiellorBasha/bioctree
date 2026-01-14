/**
 * quiver.js
 * 
 * Vector field visualization using instanced arrow glyphs.
 * 
 * Responsibilities:
 * - Create 3D arrow glyphs for vector fields
 * - Support face-centered and vertex-centered vectors
 * - Handle tangent plane projection for surface vectors
 * - Efficient rendering via InstancedMesh
 */

import * as THREE from 'three';

/**
 * Create an InstancedMesh showing vectors as 3D arrows
 *
 * @param {Object} options - Configuration options
 * @param {Float32Array} options.positions - Base positions [x1,y1,z1,x2,y2,z2,...]
 * @param {Float32Array} options.vectors - Vector components [vx1,vy1,vz1,vx2,vy2,vz2,...]
 * @param {Float32Array} [options.normals] - Surface normals for tangent projection
 * @param {number} [options.stride=5] - Draw every Nth vector
 * @param {number} [options.lengthScale=1.0] - Global arrow length scaling
 * @param {number} [options.maxLength=10.0] - Maximum arrow length (world units)
 * @param {number} [options.minMagnitude=1e-12] - Skip vectors below this magnitude
 * @param {number} [options.shaftRadius=0.15] - Arrow shaft thickness
 * @param {number} [options.headRadius=0.35] - Arrow head cone radius
 * @param {number} [options.headLength=0.9] - Arrow head cone height
 * @param {number} [options.color=0xff6600] - Arrow color
 * @returns {THREE.InstancedMesh} Instanced mesh with arrow glyphs
 */
export function createVectorQuiver({
  positions,
  vectors,
  normals = null,
  stride = 5,
  lengthScale = 1.0,
  maxLength = 10.0,
  minMagnitude = 1e-12,
  shaftRadius = 0.15,
  headRadius = 0.35,
  headLength = 0.9,
  color = 0xff6600
}) {
  const numVectors = positions.length / 3;
  const instanceCapacity = Math.ceil(numVectors / stride);

  // Create arrow geometry oriented along +Y axis
  // Make shaft the dominant visual element (defines vector length/direction)
  const shaftLength = 0.8;   // Most of arrow length
  const shaftRadiusActual = 0.08;  // Visible but not too thick
  
  // Shaft: cylinder from origin to most of length
  const shaftGeom = new THREE.CylinderGeometry(
    shaftRadiusActual, shaftRadiusActual, shaftLength, 8
  );
  shaftGeom.translate(0, shaftLength * 0.5, 0);

  // Head: cone at top of shaft (small tip to indicate direction)
  const headLengthActual = 0.2;  // Small tip
  const headRadiusActual = 0.15;  // Slightly wider than shaft
  const headGeom = new THREE.ConeGeometry(headRadiusActual, headLengthActual, 8);
  headGeom.translate(0, shaftLength + headLengthActual * 0.5, 0);

  // Merge shaft and head geometries
  const arrowGeom = new THREE.BufferGeometry();
  arrowGeom.setAttribute('position', 
    mergeBufferAttributes([
      shaftGeom.getAttribute('position'),
      headGeom.getAttribute('position')
    ])
  );
  
  // Merge indices
  const shaftIndex = shaftGeom.getIndex();
  const headIndex = headGeom.getIndex();
  const shaftVertexCount = shaftGeom.getAttribute('position').count;
  
  const mergedIndices = new Uint16Array(shaftIndex.count + headIndex.count);
  mergedIndices.set(shaftIndex.array, 0);
  for (let i = 0; i < headIndex.count; i++) {
    mergedIndices[shaftIndex.count + i] = headIndex.array[i] + shaftVertexCount;
  }
  arrowGeom.setIndex(new THREE.BufferAttribute(mergedIndices, 1));
  
  // Compute normals for proper lighting
  arrowGeom.computeVertexNormals();

  // Material
  const material = new THREE.MeshStandardMaterial({ 
    color: color,
    metalness: 0.3,
    roughness: 0.6
  });

  // Create instanced mesh
  const instanced = new THREE.InstancedMesh(
    arrowGeom, 
    material, 
    instanceCapacity
  );
  instanced.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
  instanced.frustumCulled = false;

  // Helpers for vector math
  const baseAxis = new THREE.Vector3(0, 1, 0);
  const pos = new THREE.Vector3();
  const vec = new THREE.Vector3();
  const norm = new THREE.Vector3();
  const quat = new THREE.Quaternion();
  const dummy = new THREE.Object3D();

  let count = 0;

  // Create arrow instance for each vector (with striding)
  for (let i = 0; i < numVectors; i += stride) {
    const idx = 3 * i;

    // Get position
    pos.set(
      positions[idx],
      positions[idx + 1],
      positions[idx + 2]
    );

    // Get vector
    vec.set(
      vectors[idx],
      vectors[idx + 1],
      vectors[idx + 2]
    );

    // Optional: project to tangent plane (subtract normal component)
    if (normals) {
      norm.set(
        normals[idx],
        normals[idx + 1],
        normals[idx + 2]
      ).normalize();
      
      const normalComponent = vec.dot(norm);
      vec.addScaledVector(norm, -normalComponent);
    }

    // Check magnitude
    const mag = vec.length();
    if (mag < minMagnitude) continue;

    // Normalize direction
    vec.multiplyScalar(1.0 / mag);

    // Compute rotation from +Y to vector direction
    quat.setFromUnitVectors(baseAxis, vec);

    // Compute scaled length
    const length = Math.min(maxLength, mag * lengthScale);

    // Set transform
    dummy.position.copy(pos);
    dummy.quaternion.copy(quat);
    dummy.scale.set(1.0, length, 1.0); // Anisotropic: stretch along Y
    dummy.updateMatrix();

    // Store instance matrix
    instanced.setMatrixAt(count, dummy.matrix);
    count++;
    
    if (count >= instanceCapacity) break;
  }

  // Update actual count and mark for GPU update
  instanced.count = count;
  instanced.instanceMatrix.needsUpdate = true;
  
  // Add name for identification
  instanced.name = 'vectorQuiver';

  return instanced;
}

/**
 * Merge multiple buffer attributes into one
 * @param {Array<THREE.BufferAttribute>} attributes - Attributes to merge
 * @returns {THREE.BufferAttribute} Merged attribute
 */
function mergeBufferAttributes(attributes) {
  let totalLength = 0;
  const itemSize = attributes[0].itemSize;
  
  for (const attr of attributes) {
    totalLength += attr.count * itemSize;
  }
  
  const merged = new Float32Array(totalLength);
  let offset = 0;
  
  for (const attr of attributes) {
    merged.set(attr.array, offset);
    offset += attr.count * itemSize;
  }
  
  return new THREE.BufferAttribute(merged, itemSize);
}

/**
 * Compute face centroids from vertices and faces
 * @param {Float32Array} vertices - Vertex positions [x1,y1,z1,...]
 * @param {Uint32Array} faces - Face indices [i1,i2,i3,...]
 * @returns {Float32Array} Face centroids [cx1,cy1,cz1,...]
 */
export function computeFaceCentroids(vertices, faces) {
  const numFaces = faces.length / 3;
  const centroids = new Float32Array(numFaces * 3);
  
  for (let f = 0; f < numFaces; f++) {
    const i0 = faces[3 * f] * 3;
    const i1 = faces[3 * f + 1] * 3;
    const i2 = faces[3 * f + 2] * 3;
    
    // Average vertex positions
    centroids[3 * f] = (vertices[i0] + vertices[i1] + vertices[i2]) / 3;
    centroids[3 * f + 1] = (vertices[i0 + 1] + vertices[i1 + 1] + vertices[i2 + 1]) / 3;
    centroids[3 * f + 2] = (vertices[i0 + 2] + vertices[i1 + 2] + vertices[i2 + 2]) / 3;
  }
  
  return centroids;
}

/**
 * Compute face normals from vertices and faces
 * @param {Float32Array} vertices - Vertex positions [x1,y1,z1,...]
 * @param {Uint32Array} faces - Face indices [i1,i2,i3,...]
 * @returns {Float32Array} Face normals [nx1,ny1,nz1,...]
 */
export function computeFaceNormals(vertices, faces) {
  const numFaces = faces.length / 3;
  const normals = new Float32Array(numFaces * 3);
  
  const v0 = new THREE.Vector3();
  const v1 = new THREE.Vector3();
  const v2 = new THREE.Vector3();
  const e1 = new THREE.Vector3();
  const e2 = new THREE.Vector3();
  const normal = new THREE.Vector3();
  
  for (let f = 0; f < numFaces; f++) {
    const i0 = faces[3 * f] * 3;
    const i1 = faces[3 * f + 1] * 3;
    const i2 = faces[3 * f + 2] * 3;
    
    // Get vertices
    v0.set(vertices[i0], vertices[i0 + 1], vertices[i0 + 2]);
    v1.set(vertices[i1], vertices[i1 + 1], vertices[i1 + 2]);
    v2.set(vertices[i2], vertices[i2 + 1], vertices[i2 + 2]);
    
    // Compute normal via cross product
    e1.subVectors(v1, v0);
    e2.subVectors(v2, v0);
    normal.crossVectors(e1, e2).normalize();
    
    // Store
    normals[3 * f] = normal.x;
    normals[3 * f + 1] = normal.y;
    normals[3 * f + 2] = normal.z;
  }
  
  return normals;
}
