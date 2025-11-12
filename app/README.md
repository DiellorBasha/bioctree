# BCT Viewer - Brain Connectivity Toolkit Visualization

A simple Three.js-based web application for visualizing brain connectivity data in BCT (Brain Connectivity Toolkit) format, integrated within the bioctree project.

## Features

- **3D Brain Visualization**: Load and display brain mesh data from fsaverage templates
- **BCT Format Support**: Import and visualize brain connectivity data in BCT JSON format
- **Multiple View Modes**: 
  - Brain surface mesh visualization
  - Sphere coordinate mapping
  - Node and edge connectivity display
- **Interactive Controls**: 
  - Orbit controls for 3D navigation
  - Hemisphere selection (left, right, both)
  - Mesh type selection (brain surface, sphere)
- **Export Capabilities**: Export scenes to GLB format for external use
- **Real-time Statistics**: View vertex count, face count, and FPS metrics

## Project Structure

```
bioctree/app/
├── index.html              # Main HTML interface
├── main.js                 # Application entry point and event handling
├── package.json            # Node.js dependencies and scripts
├── vite.config.js         # Vite development server configuration
├── js/
│   └── bctViewer.js       # Main BCT viewer class with Three.js integration
├── utils/
│   ├── numpyLoader.js     # NumPy .npy file loader for mesh data
│   └── bctConverter.js    # BCT format converter utilities
├── css/
│   └── styles.css         # Application styling
└── test-data/
    └── example.bct        # Example BCT connectivity file
```

## Getting Started

### Prerequisites

- Node.js (v16 or higher)
- Modern web browser with WebGL support

### Installation

1. Navigate to the app directory:
   ```bash
   cd bioctree/app
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start development server:
   ```bash
   npm run dev
   ```

4. Open your browser to `http://localhost:5173`

### Usage

#### Loading Mesh Data

1. **Fsaverage Mesh**: Click "Load Fsaverage" to load default brain surface mesh
2. **Mesh Type**: Select between "brain" (cortical surface) or "sphere" (spherical mapping)
3. **Hemisphere**: Choose "left", "right", or "both" hemispheres to display

#### BCT File Loading

1. Click "Choose File" and select a `.bct` JSON file
2. The viewer will display nodes as spheres and edges as lines
3. Use "Create Example" to generate a synthetic BCT file for testing

#### Navigation Controls

- **Mouse**: Left-click and drag to rotate the view
- **Zoom**: Mouse wheel to zoom in/out
- **Pan**: Right-click and drag to pan the view
- **View Buttons**: Quick camera positioning (Front, Back, Left, Right, Top, Bottom)

#### Export Options

- **GLB Export**: Export the current scene to GLB format for use in other applications
- **Clear Scene**: Remove all objects from the 3D scene

## BCT File Format

The BCT format is a JSON structure containing brain connectivity data:

```json
{
    "format": "bct",
    "version": "1.0",
    "metadata": {
        "description": "Brain connectivity data",
        "vertices_left": 100,
        "vertices_right": 100,
        "total_vertices": 200,
        "total_edges": 300
    },
    "graph": {
        "nodes": {
            "count": 200,
            "coords": [[x, y, z], ...]  // 3D coordinates for each node
        },
        "edges": {
            "count": 300,
            "coo_i": [0, 1, 2, ...],    // Source node indices
            "coo_j": [1, 2, 3, ...],    // Target node indices  
            "coo_w": [0.8, 0.6, ...]   // Edge weights
        }
    }
}
```

## Data Sources

The viewer expects mesh data in NumPy binary format (.npy files):

- `lh_vertices.npy` / `rh_vertices.npy`: Vertex coordinates
- `lh_faces.npy` / `rh_faces.npy`: Face triangulation indices
- `lh_sphere_coords.npy` / `rh_sphere_coords.npy`: Spherical coordinates (optional)

These files should be placed in `test-data/mesh/fsaverage/` directory.

## Integration with bioctree

This BCT viewer is designed to work alongside the broader bioctree MATLAB toolkit:

- **Data Pipeline**: MATLAB scripts in bioctree can export BCT format files
- **Mesh Processing**: Utilizes fsaverage brain templates from FreeSurfer
- **Workflow Integration**: Supports the bioctree analysis workflows

## Development

### Building

```bash
npm run build
```

### Development Server

```bash
npm run dev
```

The development server supports hot reloading for rapid development.

### Extending the Viewer

Key areas for extension:

1. **Additional Mesh Formats**: Extend `NumpyLoader` to support other mesh formats
2. **Connectivity Metrics**: Add brain connectivity analysis tools
3. **Animation**: Implement time-series connectivity visualization
4. **Filtering**: Add node/edge filtering based on connectivity strength

## Dependencies

- **Three.js**: 3D graphics library
- **Vite**: Build tool and development server
- Core utilities for NumPy binary format parsing and GLB export

## Performance Notes

- **Edge Rendering**: Large connectivity graphs limit edge display to 1000 edges for performance
- **Mesh Resolution**: fsaverage meshes contain ~150K vertices per hemisphere
- **Memory Usage**: Large BCT files may require chunked loading for very dense connectivity matrices

## License

This BCT viewer is part of the bioctree project. See the main project repository for license information.

## Contributing

This viewer is designed as a simple, integrated solution for BCT visualization. For major enhancements, consider the broader bioctree project architecture and MATLAB integration requirements.