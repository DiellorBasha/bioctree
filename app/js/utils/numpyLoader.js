/**
 * NumPy file reader for loading mesh data from .npy files
 */

export class NumpyLoader {
    static async loadFloat32Array(url) {
        try {
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`Failed to load ${url}: ${response.statusText}`);
            }
            
            const buffer = await response.arrayBuffer();
            const view = new DataView(buffer);
            
            // Parse NPY header
            const magic = String.fromCharCode(...new Uint8Array(buffer, 0, 6));
            if (magic !== '\x93NUMPY') {
                throw new Error('Invalid NPY file format');
            }
            
            const majorVersion = view.getUint8(6);
            const minorVersion = view.getUint8(7);
            
            // Read header length
            let headerLength;
            if (majorVersion === 1) {
                headerLength = view.getUint16(8, true);
            } else if (majorVersion === 2) {
                headerLength = view.getUint32(8, true);
            } else {
                throw new Error(`Unsupported NPY version: ${majorVersion}.${minorVersion}`);
            }
            
            const headerStart = majorVersion === 1 ? 10 : 12;
            const headerBytes = new Uint8Array(buffer, headerStart, headerLength);
            const headerStr = String.fromCharCode(...headerBytes);
            
            // Parse shape and dtype from header
            const shapeMatch = headerStr.match(/'shape':\s*\(([^)]+)\)/);
            const dtypeMatch = headerStr.match(/'descr':\s*'([^']+)'/);
            
            if (!shapeMatch || !dtypeMatch) {
                throw new Error('Could not parse NPY header');
            }
            
            const shape = shapeMatch[1].split(',').map(s => parseInt(s.trim())).filter(n => !isNaN(n));
            const dtype = dtypeMatch[1];
            
            // Calculate data start position
            const dataStart = headerStart + headerLength;
            
            // Read data based on dtype
            let data;
            if (dtype === '<f4' || dtype === '<f8') {
                // Little-endian float32 or float64
                const isFloat64 = dtype === '<f8';
                const bytesPerElement = isFloat64 ? 8 : 4;
                const totalElements = shape.reduce((a, b) => a * b, 1);
                
                data = new Float32Array(totalElements);
                const dataView = new DataView(buffer, dataStart);
                
                for (let i = 0; i < totalElements; i++) {
                    if (isFloat64) {
                        data[i] = dataView.getFloat64(i * bytesPerElement, true);
                    } else {
                        data[i] = dataView.getFloat32(i * bytesPerElement, true);
                    }
                }
            } else if (dtype === '<i4' || dtype === '<i8') {
                // Little-endian int32 or int64
                const isInt64 = dtype === '<i8';
                const bytesPerElement = isInt64 ? 8 : 4;
                const totalElements = shape.reduce((a, b) => a * b, 1);
                
                data = new Int32Array(totalElements);
                const dataView = new DataView(buffer, dataStart);
                
                for (let i = 0; i < totalElements; i++) {
                    if (isInt64) {
                        // For int64, we'll just take the lower 32 bits
                        data[i] = dataView.getInt32(i * bytesPerElement, true);
                    } else {
                        data[i] = dataView.getInt32(i * bytesPerElement, true);
                    }
                }
            } else {
                throw new Error(`Unsupported dtype: ${dtype}`);
            }
            
            return { data, shape, dtype };
            
        } catch (error) {
            console.error('Error loading NPY file:', error);
            throw error;
        }
    }
    
    static async loadMeshData(basePath, hemisphere) {
        const prefix = hemisphere === 'left' ? 'lh' : 'rh';
        
        try {
            const [coordsResult, facesResult] = await Promise.all([
                this.loadFloat32Array(`${basePath}/${prefix}_coords.npy`),
                this.loadFloat32Array(`${basePath}/${prefix}_faces.npy`)
            ]);
            
            return {
                vertices: coordsResult.data,
                faces: facesResult.data,
                vertexCount: coordsResult.shape[0],
                faceCount: facesResult.shape[0]
            };
        } catch (error) {
            console.error(`Error loading mesh data for ${hemisphere} hemisphere:`, error);
            throw error;
        }
    }
}