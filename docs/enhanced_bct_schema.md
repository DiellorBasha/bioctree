# Enhanced BCT Schema Documentation

## Overview

The enhanced BCT (BioCTree) schema extends the original node-based signal storage format to include comprehensive metadata, preprocessing capabilities, and feature extraction support. This makes it suitable for advanced biosignal analysis workflows.

## Key Enhancements

### 1. **Subject-Level Metadata**
```json
"root_attributes_optional": ["subject_name", "session_id", "recording_date"]
```

**Purpose**: Store experimental and subject information at the file level.

**Usage**:
```matlab
h5writeatt(filename, '/', 'subject_name', 'SUBJ001');
h5writeatt(filename, '/', 'session_id', 'SES01');
h5writeatt(filename, '/', 'recording_date', '2025-11-05');
```

### 2. **Node Descriptors**
```json
"node_descriptors": {
  "node_name":     {"path": "/node_info/node_name",     "dtype": "string",  "rank": 1},
  "node_type":     {"path": "/node_info/node_type",     "dtype": "string",  "rank": 1},
  "node_position": {"path": "/node_info/node_position", "dtype": "float32", "rank": 2},
  "node_units":    {"path": "/node_info/node_units",    "dtype": "string",  "rank": 1},
  "channel_name":  {"path": "/node_info/channel_name",  "dtype": "string",  "rank": 1}
}
```

**Purpose**: Provide rich metadata for each node/channel in the N dimension.

**Applications**:
- **EEG/MEG**: Store electrode names ("Fp1", "C3"), positions, types ("EEG", "EOG")
- **fMRI**: Store ROI names, anatomical labels, coordinates
- **Graph signals**: Store node attributes, community labels, centrality measures

**Usage**:
```matlab
% Store channel names for EEG data
channel_names = ["Fp1", "Fp2", "C3", "C4", "O1", "O2"];
h5write(filename, '/node_info/channel_name', channel_names);

% Store 3D electrode positions
positions = [...];  % Nx3 matrix
h5write(filename, '/node_info/node_position', positions);
```

### 3. **Preprocessed Signals**
```json
"/signals/preproc": {
  "shape": ["T","N"], 
  "dtype_any_of": ["float32"], 
  "dim_scales": ["time_s","node_id"], 
  "attributes": ["sampling_rate_hz", "preprocessing_steps"]
}
```

**Purpose**: Store cleaned/filtered signals alongside raw data.

**Benefits**:
- Compare raw vs. processed signals
- Document preprocessing pipeline
- Enable reproducible analysis

**Usage**:
```matlab
% Store preprocessed signals
h5write(filename, '/signals/preproc', preproc_data);
h5writeatt(filename, '/signals/preproc', 'sampling_rate_hz', 256);
h5writeatt(filename, '/signals/preproc', 'preprocessing_steps', 
    'bandpass_filter:1-50Hz,notch_filter:60Hz,artifact_removal');
```

### 4. **Feature Extraction Framework**

#### **Chunk Descriptors**
```json
"chunk_descriptors": {
  "path": "/features/chunks",
  "datasets": {
    "chunk_id":         {"dtype": "int32",   "rank": 1},
    "node_id":          {"dtype": "int32",   "rank": 1},
    "start_time_s":     {"dtype": "float64", "rank": 1},
    "end_time_s":       {"dtype": "float64", "rank": 1},
    "center_time_s":    {"dtype": "float64", "rank": 1},
    "sample_start":     {"dtype": "int32",   "rank": 1},
    "sample_end":       {"dtype": "int32",   "rank": 1}
  }
}
```

**Purpose**: Enable chunk-based feature extraction with precise temporal indexing.

**Applications**:
- **4-second analysis windows** with 50% overlap
- **Event-related analysis** around stimuli/responses
- **Sliding window spectral analysis**
- **Artifact detection** in specific time segments

#### **Feature Matrix**
```json
"feature_matrix": {
  "datasets": {
    "feature_matrix":   {"dtype": "float32", "rank": 2, "shape": ["chunks", "features"]},
    "feature_names":    {"dtype": "string",  "rank": 1},
    "chunk_ids":        {"dtype": "int32",   "rank": 1}
  }
}
```

**Purpose**: Store extracted features in ML-ready format.

**Features Supported**:
- **Time-domain**: RMS, peak value, standard deviation
- **Frequency-domain**: Spectral centroid, rolloff, entropy
- **Band powers**: Delta, Theta, Alpha, Beta, Gamma
- **Derived metrics**: Alpha/Beta ratio, complexity measures

#### **Extraction Metadata**
```json
"extraction_metadata": {
  "attributes": ["extraction_time", "frame_size_samples", "hop_size_samples"],
  "datasets": {
    "feature_descriptions": {"dtype": "string", "rank": 1},
    "frequency_bands":      {"dtype": "float32", "rank": 2}
  }
}
```

**Purpose**: Document feature extraction parameters for reproducibility.

### 5. **Sampling Rate Attributes**

**Purpose**: Store sampling rate with each signal type for proper temporal analysis.

**Implementation**:
```matlab
h5writeatt(filename, '/signals/raw', 'sampling_rate_hz', 256);
h5writeatt(filename, '/signals/preproc', 'sampling_rate_hz', 256);
```

## Data Flow Architecture

```
Raw Signals (N×T)
       ↓
Node Descriptors ←→ Preprocessing → Preprocessed Signals (N×T)
       ↓                                    ↓
Feature Extraction ←────────────────────────┘
       ↓
Chunk Descriptors + Feature Matrix
       ↓
Analysis & Machine Learning
```

## Query Capabilities

### **Channel-Based Queries**
```matlab
% Find specific channels
target_channels = ["Fp1", "O1", "C3"];
node_ids = find_node_ids_by_channel_names(filename, target_channels);

% Get data for these channels
data = h5read(filename, '/signals/preproc');
channel_data = data(:, node_ids);
```

### **Time-Based Queries**
```matlab
% Find chunks in time range
chunk_times = h5read(filename, '/features/chunks/center_time_s');
time_mask = chunk_times >= 10 & chunk_times <= 20;
selected_chunks = find(time_mask);
```

### **Feature-Based Queries**
```matlab
% Find high-alpha chunks
features = h5read(filename, '/features/matrix/feature_matrix');
feature_names = h5read(filename, '/features/matrix/feature_names');
alpha_idx = find(strcmp(feature_names, "AlphaPower"));
high_alpha_chunks = find(features(:, alpha_idx) > threshold);
```

## Integration with Existing Tools

### **Compatible with bstSigFeatures**
The enhanced schema directly supports the feature extraction pipeline:

```matlab
% Extract features using enhanced BCT format
bstSigFeaturesH5('enhanced_bct_file.h5', ...
    'frameSize', 4, 'hopSize', 2);

% Features are stored in /features/ group
```

### **MATLAB Integration**
```matlab
% Load as BCT object
bct_obj = bct.open('enhanced_file.h5');

% Access enhanced properties
subject = h5readatt(bct_obj.fn, '/', 'subject_name');
channels = h5read(bct_obj.fn, '/node_info/channel_name');
```

## Use Cases

### **1. EEG/MEG Analysis**
- Store electrode names, positions, and types
- Compare raw vs. artifact-cleaned signals
- Extract canonical frequency band features
- Query by brain region or frequency content

### **2. Graph Signal Processing**
- Store node attributes (community, centrality)
- Track signal evolution on graph structure
- Feature extraction for graph neural networks

### **3. Multimodal Integration**
- Subject-level metadata enables cross-modal alignment
- Standardized time axis for temporal synchronization
- Feature matrices ready for ML fusion approaches

### **4. Clinical Applications**
- Subject tracking across sessions
- Biomarker extraction and monitoring
- Reproducible preprocessing pipelines

## Migration Path

### **From Original BCT**
1. **Backward compatible**: Existing `/signals/raw` structure unchanged
2. **Gradual enhancement**: Add node descriptors and preprocessing incrementally
3. **Feature addition**: Existing analysis code continues to work

### **From H5 Biosignal Files**
1. **Direct mapping**: `/preproc/F` → `/signals/preproc`
2. **Metadata preservation**: Channel info → node descriptors
3. **Feature integration**: Existing features → `/features/` group

## Best Practices

### **File Organization**
```
enhanced_study.h5
├── / (subject_name, session_id)
├── /axes/ (time_s, node_id)
├── /node_info/ (channel_name, positions, types)
├── /signals/ (raw, preproc with sampling_rate_hz)
└── /features/ (chunks, matrix, metadata)
```

### **Naming Conventions**
- **Subjects**: `SUBJ001`, `SUBJ002`, etc.
- **Sessions**: `SES01`, `SES02`, etc.
- **Channels**: Standard nomenclature ("Fp1", "C3") or descriptive names
- **Features**: Descriptive names ("AlphaPower", "SpectralCentroid")

### **Performance Optimization**
- **Chunked storage**: Use HDF5 chunking for large datasets
- **Compression**: Apply gzip compression for feature matrices
- **Indexing**: Create indices for common query patterns

This enhanced schema provides a comprehensive foundation for modern biosignal analysis while maintaining compatibility with existing BCT workflows.