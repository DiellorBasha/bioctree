/**
 * NumPy Loader - Loads binary .npy files containing mesh data
 * Supports the NumPy binary format used by FreeSurfer fsaverage meshes
 */

export class NumpyLoader {
    
    /**
     * Load a .npy file and parse its binary data
     * @param {string} url - URL to the .npy file
     * @returns {Promise<Object>} Parsed NumPy array data
     */
    static async loadNumpyFile(url) {
        try {
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`Failed to load ${url}: ${response.statusText}`);
            }
            
            const buffer = await response.arrayBuffer();
            return this.parseNumpyBuffer(buffer);
            
        } catch (error) {
            console.error('Error loading NumPy file:', error);
            throw error;
        }
    }
    
    /**
     * Parse NumPy binary buffer
     * @param {ArrayBuffer} buffer - Raw .npy file buffer
     * @returns {Object} Parsed array with data, shape, and dtype
     */
    static parseNumpyBuffer(buffer) {
        const view = new DataView(buffer);
        let offset = 0;
        
        // Check magic number
        const magic = new Uint8Array(buffer, 0, 6);
        const magicString = String.fromCharCode(...magic);
        if (magicString !== '\x93NUMPY') {
            throw new Error('Invalid NumPy file: magic number mismatch');
        }
        offset += 6;
        
        // Version
        const majorVersion = view.getUint8(offset++);
        const minorVersion = view.getUint8(offset++);
        
        // Header length
        let headerLength;
        if (majorVersion === 1) {
            headerLength = view.getUint16(offset, true); // little-endian
            offset += 2;
        } else if (majorVersion === 2) {
            headerLength = view.getUint32(offset, true); // little-endian
            offset += 4;
        } else {
            throw new Error(`Unsupported NumPy version: ${majorVersion}.${minorVersion}`);
        }
        
        // Parse header (Python dict as string)
        const headerBytes = new Uint8Array(buffer, offset, headerLength);
        const headerString = String.fromCharCode(...headerBytes);
        const header = this.parseNumpyHeader(headerString);
        offset += headerLength;
        
        // Extract data
        const dataBuffer = buffer.slice(offset);
        const data = this.parseNumpyData(dataBuffer, header);
        
        return {
            data,
            shape: header.shape,
            dtype: header.descr,
            fortranOrder: header.fortran_order
        };
    }
    
    /**
     * Parse NumPy header string (Python dict format)
     * @param {string} headerString - Header as string
     * @returns {Object} Parsed header object
     */
    static parseNumpyHeader(headerString) {
        // Simple parser for NumPy header format
        // Example: "{'descr': '<f4', 'fortran_order': False, 'shape': (163842, 3), }"
        
        try {
            // Clean up the string and make it JSON-parseable
            let cleaned = headerString
                .replace(/'/g, '"')           // Single quotes to double quotes
                .replace(/False/g, 'false')   // Python False to JSON false
                .replace(/True/g, 'true')     // Python True to JSON true
                .replace(/\(/g, '[')          // Tuples to arrays
                .replace(/\)/g, ']')
                .replace(/,\s*}/g, '}')       // Remove trailing commas
                .replace(/,\s*]/g, ']');
            
            // Handle single-element tuples like (1,) -> [1]
            cleaned = cleaned.replace(/\[\s*(\d+)\s*,\s*\]/g, '[$1]');
            
            return JSON.parse(cleaned);
            
        } catch (error) {
            console.error('Failed to parse NumPy header:', headerString);
            throw new Error('Invalid NumPy header format');
        }
    }
    
    /**
     * Parse NumPy data array based on dtype
     * @param {ArrayBuffer} dataBuffer - Raw data buffer
     * @param {Object} header - Parsed header with dtype and shape
     * @returns {TypedArray} Parsed data array
     */
    static parseNumpyData(dataBuffer, header) {
        const { descr, shape, fortran_order } = header;
        
        // Parse dtype (format: endian + type + size)
        const endian = descr[0]; // '<' (little), '>' (big), '=' (native)
        const typeChar = descr[1]; // 'f' (float), 'i' (int), 'u' (uint)
        const typeSize = parseInt(descr.slice(2)); // bytes per element
        
        const isLittleEndian = endian === '<' || (endian === '=' && this.isLittleEndian());
        const totalElements = shape.reduce((a, b) => a * b, 1);
        
        let data;
        
        switch (typeChar + typeSize) {
            case 'f4': // float32
                data = new Float32Array(dataBuffer);
                if (!isLittleEndian) data = this.swapEndian32(data);
                break;
                
            case 'f8': // float64
                data = new Float64Array(dataBuffer);
                if (!isLittleEndian) data = this.swapEndian64(data);
                break;
                
            case 'i4': // int32
                data = new Int32Array(dataBuffer);
                if (!isLittleEndian) data = this.swapEndian32(data);
                break;
                
            case 'u4': // uint32
                data = new Uint32Array(dataBuffer);
                if (!isLittleEndian) data = this.swapEndian32(data);
                break;
                
            case 'i2': // int16
                data = new Int16Array(dataBuffer);
                if (!isLittleEndian) data = this.swapEndian16(data);
                break;
                
            case 'u2': // uint16
                data = new Uint16Array(dataBuffer);
                if (!isLittleEndian) data = this.swapEndian16(data);
                break;
                
            default:
                throw new Error(`Unsupported NumPy dtype: ${descr}`);
        }
        
        if (data.length !== totalElements) {
            throw new Error(`Data length mismatch: expected ${totalElements}, got ${data.length}`);
        }
        
        return data;
    }
    
    /**
     * Load mesh data from fsaverage format (.npy files)
     * @param {string} basePath - Base path to mesh files
     * @param {string} hemisphere - 'left' or 'right'
     * @returns {Promise<Object>} Mesh data with vertices and faces
     */
    static async loadMeshData(basePath, hemisphere) {
        const prefix = hemisphere === 'left' ? 'lh' : 'rh';
        
        const [vertices, faces] = await Promise.all([
            this.loadFloat32Array(`${basePath}/${prefix}_vertices.npy`),
            this.loadUint32Array(`${basePath}/${prefix}_faces.npy`)
        ]);
        
        return {
            vertices: vertices.data,
            faces: faces.data,
            vertexCount: vertices.shape[0],
            faceCount: faces.shape[0]
        };
    }
    
    /**
     * Load a .npy file as Float32Array (for vertex coordinates)
     * @param {string} url - URL to the .npy file
     * @returns {Promise<Object>} Parsed float32 array
     */
    static async loadFloat32Array(url) {
        const result = await this.loadNumpyFile(url);
        
        if (!result.dtype.includes('f')) {
            throw new Error(`Expected float array, got ${result.dtype}`);
        }
        
        // Convert to Float32Array if needed
        let data = result.data;
        if (!(data instanceof Float32Array)) {
            data = new Float32Array(data);
        }
        
        return { ...result, data };
    }
    
    /**
     * Load a .npy file as Uint32Array (for face indices)
     * @param {string} url - URL to the .npy file  
     * @returns {Promise<Object>} Parsed uint32 array
     */
    static async loadUint32Array(url) {
        const result = await this.loadNumpyFile(url);
        
        // Convert to Uint32Array if needed
        let data = result.data;
        if (!(data instanceof Uint32Array)) {
            data = new Uint32Array(data);
        }
        
        return { ...result, data };
    }
    
    // Utility methods
    
    static isLittleEndian() {
        const buffer = new ArrayBuffer(2);
        const uint8 = new Uint8Array(buffer);
        const uint16 = new Uint16Array(buffer);
        uint8[0] = 0xAA;
        uint8[1] = 0xBB;
        return uint16[0] === 0xBBAA;
    }
    
    static swapEndian16(array) {
        const view = new DataView(array.buffer);
        for (let i = 0; i < array.length; i++) {
            array[i] = view.getUint16(i * 2, false); // big-endian
        }
        return array;
    }
    
    static swapEndian32(array) {
        const view = new DataView(array.buffer);
        for (let i = 0; i < array.length; i++) {
            if (array instanceof Float32Array) {
                array[i] = view.getFloat32(i * 4, false); // big-endian
            } else {
                array[i] = view.getUint32(i * 4, false); // big-endian
            }
        }
        return array;
    }
    
    static swapEndian64(array) {
        const view = new DataView(array.buffer);
        for (let i = 0; i < array.length; i++) {
            array[i] = view.getFloat64(i * 8, false); // big-endian
        }
        return array;
    }
    
    /**
     * Create example .npy files for testing (generates synthetic data)
     * @param {string} hemisphere - 'left' or 'right'
     * @returns {Object} Synthetic mesh data
     */
    static createExampleMeshData(hemisphere) {
        // Generate synthetic brain hemisphere mesh
        const vertexCount = hemisphere === 'left' ? 81924 : 81924; // fsaverage vertex counts
        const vertices = new Float32Array(vertexCount * 3);
        
        // Generate hemisphere-shaped vertices
        const radius = 50;
        const xOffset = hemisphere === 'left' ? -radius : radius;
        
        for (let i = 0; i < vertexCount; i++) {
            const phi = (i / vertexCount) * Math.PI * 2;
            const theta = ((i * 7) % vertexCount / vertexCount) * Math.PI;
            
            vertices[i * 3] = xOffset + radius * Math.sin(theta) * Math.cos(phi) * 0.8;
            vertices[i * 3 + 1] = radius * Math.sin(theta) * Math.sin(phi) * 0.6;
            vertices[i * 3 + 2] = radius * Math.cos(theta) * 0.7;
        }
        
        // Generate faces (simple triangulation)
        const faceCount = (vertexCount - 2) * 2; // Approximate for sphere
        const faces = new Uint32Array(faceCount * 3);
        
        for (let i = 0; i < faceCount; i++) {
            faces[i * 3] = i % vertexCount;
            faces[i * 3 + 1] = (i + 1) % vertexCount;
            faces[i * 3 + 2] = (i + 2) % vertexCount;
        }
        
        return {
            vertices,
            faces,
            vertexCount,
            faceCount
        };
    }
}