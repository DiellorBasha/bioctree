/**
 * lineSegments3D.js
 * 
 * Arbitrary line segment visualization (not direction-indicating vectors)
 * 
 * Responsibilities:
 * - Create line segments from endpoint pairs
 * - Support polylines and disconnected segments
 * - Efficient rendering via LineSegments2
 * 
 * Use cases:
 * - Isolines/contour lines
 * - Geodesic paths
 * - Streamlines
 * - Graph edges
 * - Arbitrary geometric curves
 */

import * as THREE from 'three';
import { LineSegments2 } from 'three/addons/lines/LineSegments2.js';
import { LineSegmentsGeometry } from 'three/addons/lines/LineSegmentsGeometry.js';
import { LineMaterial } from 'three/addons/lines/LineMaterial.js';

/**
 * Create arbitrary line segments from endpoint pairs
 * 
 * @param {Object} options - Configuration options
 * @param {Float32Array} options.segments - Flat array [x1,y1,z1, x2,y2,z2, ...] of segment endpoints
 * @param {number} [options.color=0x000000] - Line color (default: black)
 * @param {number} [options.linewidth=1] - Line width in pixels (default: 1)
 * @returns {THREE.LineSegments2} Line segments mesh
 */
export function createLineSegments3D({
  segments,
  color = 0x000000,
  linewidth = 1
}) {
  // Create LineSegments2 geometry
  const geometry = new LineSegmentsGeometry();
  geometry.setPositions(segments);
  
  // Create LineMaterial (supports actual line width)
  const material = new LineMaterial({
    color: color,
    linewidth: linewidth,  // Line width in pixels
    worldUnits: false,     // Use pixel units for linewidth
    vertexColors: false,
    dashed: false,
    alphaToCoverage: true  // Better antialiasing
  });
  
  // Set resolution (will be updated by renderer)
  material.resolution.set(window.innerWidth, window.innerHeight);
  
  // Create LineSegments2 mesh
  const lineSegments = new LineSegments2(geometry, material);
  lineSegments.name = 'customLineSegments';
  lineSegments.computeLineDistances();  // Required for dashed lines
  
  // Store metadata
  lineSegments.userData.segmentCount = segments.length / 6;
  
  return lineSegments;
}
