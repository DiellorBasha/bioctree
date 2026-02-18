/**
 * lineSegments.js
 * 
 * Vector field visualization using lightweight 2D line segments.
 * 
 * Responsibilities:
 * - Create line-based arrow glyphs for vector fields (faster than 3D arrows)
 * - Support face-centered and vertex-centered vectors
 * - Handle tangent plane projection for surface vectors
 * - Efficient rendering via LineSegments2 geometry with proper line width support
 * 
 * Inspired by geometry-processing-js trivial connections demo
 */

import * as THREE from 'three';
import { LineSegments2 } from 'three/addons/lines/LineSegments2.js';
import { LineSegmentsGeometry } from 'three/addons/lines/LineSegmentsGeometry.js';
import { LineMaterial } from 'three/addons/lines/LineMaterial.js';

/**
 * Create a LineSegments mesh showing vectors as 2D lines or arrows
 * 
 * When style='arrow', each vector is rendered as 3 line segments:
 *   - Main line from base to tip
 *   - Two arrow head lines forming a V-shape at the tip
 * 
 * When style='line', each vector is rendered as a single line segment from base to tip.
 * 
 * This is much faster than instanced 3D arrows for large vector fields.
 *
 * @param {Object} options - Configuration options
 * @param {Float32Array} options.positions - Base positions [x1,y1,z1,x2,y2,z2,...]
 * @param {Float32Array} options.vectors - Vector components [vx1,vy1,vz1,vx2,vy2,vz2,...]
 * @param {Float32Array} [options.normals] - Surface normals for tangent projection
 * @param {string} [options.style='arrow'] - Visualization style: 'arrow' or 'line'
 * @param {number} [options.stride=5] - Draw every Nth vector
 * @param {number} [options.lengthScale=1.0] - Global arrow length scaling
 * @param {number} [options.maxLength=10.0] - Maximum arrow length (world units)
 * @param {number} [options.minMagnitude=1e-12] - Skip vectors below this magnitude
 * @param {number} [options.headAngle=0.4] - Arrow head angle in radians (~23 degrees)
 * @param {number} [options.headLength=0.2] - Arrow head length as fraction of total length
 * @param {number} [options.color=0x000000] - Line color (default: black)
 * @param {number} [options.linewidth=1] - Line width (default: 1)
 * @returns {THREE.LineSegments} Line segments mesh with arrow glyphs
 */
export function createVectorLineSegments({
  positions,
  vectors,
  normals = null,
  style = 'arrow',        // 'arrow' or 'line'
  stride = 5,
  lengthScale = 1.0,
  maxLength = 10.0,
  minMagnitude = 1e-12,
  headAngle = 0.4,        // ~23 degrees
  headLength = 0.2,       // 20% of arrow length
  color = 0x000000,       // Black by default
  linewidth = 1
}) {
  const numVectors = positions.length / 3;
  
  // Pre-allocate for maximum possible vectors
  // Arrow style: 3 line segments = 6 vertices = 18 floats
  // Line style: 1 line segment = 2 vertices = 6 floats
  const maxVectors = Math.ceil(numVectors / stride);
  const floatsPerVector = (style === 'line') ? 6 : 18;
  const linePositions = new Float32Array(maxVectors * floatsPerVector);

  // Helpers for vector math
  const pos = new THREE.Vector3();
  const vec = new THREE.Vector3();
  const norm = new THREE.Vector3();
  const vecNormalized = new THREE.Vector3();
  const tangent1 = new THREE.Vector3();
  const tangent2 = new THREE.Vector3();
  
  let vectorCount = 0;

  // Create line segment for each vector (with striding)
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

    // Normalize direction and compute scaled length
    vecNormalized.copy(vec).multiplyScalar(1.0 / mag);
    const length = Math.min(maxLength, mag * lengthScale);
    
    // Compute vector endpoints (vector starts at base position, extends to tip)
    const base = pos.clone();
    const tip = pos.clone().addScaledVector(vecNormalized, length);
    
    const offset = vectorCount * floatsPerVector;
    
    // Main segment: base → tip
    linePositions[offset + 0] = base.x;
    linePositions[offset + 1] = base.y;
    linePositions[offset + 2] = base.z;
    linePositions[offset + 3] = tip.x;
    linePositions[offset + 4] = tip.y;
    linePositions[offset + 5] = tip.z;
    
    // Add arrow head if style is 'arrow'
    if (style === 'arrow') {
      // Compute arrow head vectors
      // Find two orthogonal vectors in the tangent plane
      if (normals) {
        // Use surface normal to create orthogonal frame
        norm.set(
          normals[idx],
          normals[idx + 1],
          normals[idx + 2]
        ).normalize();
        
        tangent1.crossVectors(norm, vecNormalized).normalize();
        tangent2.crossVectors(vecNormalized, tangent1);
      } else {
        // Fallback: arbitrary orthogonal vectors
        // Find a vector not parallel to vecNormalized
        const arbitrary = Math.abs(vecNormalized.y) < 0.9 
          ? new THREE.Vector3(0, 1, 0) 
          : new THREE.Vector3(1, 0, 0);
        tangent1.crossVectors(vecNormalized, arbitrary).normalize();
        tangent2.crossVectors(vecNormalized, tangent1);
      }
      
      // Arrow head geometry
      const headLen = length * headLength;
      const headBase = tip.clone().addScaledVector(vecNormalized, -headLen);
      const headOffset = headLen * Math.tan(headAngle);
      
      const head1 = headBase.clone().addScaledVector(tangent1, headOffset);
      const head2 = headBase.clone().addScaledVector(tangent1, -headOffset);
      
      // Segment 2: tip → head1 (first arrow flank)
      linePositions[offset + 6] = tip.x;
      linePositions[offset + 7] = tip.y;
      linePositions[offset + 8] = tip.z;
      linePositions[offset + 9] = head1.x;
      linePositions[offset + 10] = head1.y;
      linePositions[offset + 11] = head1.z;
      
      // Segment 3: tip → head2 (second arrow flank)
      linePositions[offset + 12] = tip.x;
      linePositions[offset + 13] = tip.y;
      linePositions[offset + 14] = tip.z;
      linePositions[offset + 15] = head2.x;
      linePositions[offset + 16] = head2.y;
      linePositions[offset + 17] = head2.z;
    }
    
    vectorCount++;
    
    if (vectorCount >= maxVectors) break;
  }

  // Trim array to actual count
  const actualPositions = linePositions.slice(0, vectorCount * floatsPerVector);
  
  // Create LineSegments2 geometry
  const geometry = new LineSegmentsGeometry();
  geometry. setPositions(actualPositions);
  
  // Create LineMaterial (supports actual line width)
  const material = new LineMaterial({
    color: color,
    linewidth: linewidth,  // Line width in pixels (actually works with LineMaterial!)
    worldUnits: false,     // Use pixel units for linewidth
    vertexColors: false,
    dashed: false,
    alphaToCoverage: true  // Better antialiasing
  });
  
  // Set resolution (will be updated by renderer)
  // Default to a reasonable viewport size; should be updated dynamically
  material.resolution.set(window.innerWidth, window.innerHeight);
  
  // Create LineSegments2 mesh (replaces THREE.LineSegments)
  const lineSegments = new LineSegments2(geometry, material);
  lineSegments.name = 'vectorLineSegments';
  lineSegments.computeLineDistances();  // Required for dashed lines (not used here but good practice)
  
  // Store metadata for reference
  lineSegments.userData.vectorCount = vectorCount;
  lineSegments.userData.style = style;
  
  return lineSegments;
}
