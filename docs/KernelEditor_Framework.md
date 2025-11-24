# KernelEditor Framework

## Overview

The `KernelEditor` framework provides an object-oriented interface for **interactive filter parameter manipulation** in the Bct system. It bridges GUI controls (sliders, buttons, scrubbers) to `Filter` objects, enabling smooth real-time parameter updates.

## Architecture

```
bct.filters.KernelEditor (Abstract Base Class)
├── Properties: Center, Width, Domain, Filter
├── Methods: shiftForward(), shiftBackward(), expand(), contract()
└── Abstract: computeKernel()

Concrete Implementations:
├── TimeWindowEditor      → Time domain (temporal windowing)
├── LambdaBandEditor      → Lambda domain (spectral frequency bands)
└── FrequencyBandEditor   → Omega domain (temporal frequency bands)
```

## Design Principles

1. **Domain Binding**: Each editor is bound to a specific `bct.Domain` (Time, Lambda, Omega)
2. **Filter Control**: Editors modify `bct.filters.Filter` parameters automatically
3. **Event System**: `KernelChanged` event fires on parameter updates for GUI synchronization
4. **Navigation**: Common interface for parameter adjustment (shift, expand, contract)
5. **Extensibility**: Abstract base class allows custom domain-specific implementations

## Use Cases

### 1. Time Scrubber (TimeWindowEditor)

**Problem**: Navigate through long temporal signals with a moving analysis window

```matlab
% Setup
B.Time = bct.Time(0:0.001:10, 1000);  % 10s at 1kHz
timeFilt = bct.filters.Filter(B.Time, 'gaussian', 'center', 5.0, 'sigma', 0.1);

% Create editor
editor = bct.filters.TimeWindowEditor(B.Time, timeFilt, 5.0, 0.1);

% GUI callbacks
editor.setCenter(sliderValue);      % Slider moves window
editor.shiftForward();              % Right arrow key
editor.shiftBackward();             % Left arrow key
editor.expand();                    % '+' key widens window
editor.contract();                  % '-' key narrows window
```

**Window Types**: `'gaussian'`, `'hann'`, `'hamming'`, `'tukey'`

### 2. Spectral Band Selector (LambdaBandEditor)

**Problem**: Select spectral frequency bands on Lambda (eigenvalue) domain

```matlab
% Setup (requires eigenbasis)
B = bct.bct.fromMesh(V, F);
B.Lambda = B.Lambda.eigenbasis(B.Manifold.MassMatrix, ...
                                 B.Manifold.CotangentMatrix, 500);

spatialFilt = bct.filters.Filter(B.Lambda, 'gaussian', 'center', 50, 'sigma', 10);
editor = bct.filters.LambdaBandEditor(B.Lambda, spatialFilt, 50, 10);

% Presets
editor.setLowPass(30);           % Smooth spatial patterns (modes 1-30)
editor.setBandPass(50, 150);     % Medium frequencies
editor.setHighPass(200);         % Fine details

% Navigation
editor.shiftForward();           % Higher spatial frequencies
editor.shiftBackward();          % Lower spatial frequencies
```

**Kernel Types**: `'gaussian'`, `'heat'`, `'mexican_hat'`

### 3. Frequency Band Editor (FrequencyBandEditor)

**Problem**: Interactively select temporal frequency bands for spectral analysis

```matlab
% Setup
B.Time = bct.Time(0:0.001:10, 1000);
B.Omega = B.Time.dual;

freqFilt = bct.filters.Filter(B.Omega, 'gaussian', 'center', 10, 'sigma', 2);
editor = bct.filters.FrequencyBandEditor(B.Omega, freqFilt, 10, 2);

% Standard EEG/MEG bands
editor.setDelta();      % 1-4 Hz
editor.setTheta();      % 4-8 Hz
editor.setAlpha();      % 8-12 Hz
editor.setBeta();       % 12-30 Hz
editor.setGamma();      % 30-100 Hz
editor.setHighGamma();  % 60-120 Hz

% Custom band
editor.setBand(40, 60);  % 40-60 Hz bandpass
```

**Band Types**: `'gaussian'`, `'butterworth'`, `'ideal'`

## GUI Integration Pattern

### Event Listener Setup

```matlab
% Create editor
editor = bct.filters.TimeWindowEditor(B.Time, filt, 1.0, 0.05);

% Add listener for GUI updates
addlistener(editor, 'KernelChanged', @(src, evt) updatePlot(src));

function updatePlot(editor)
    % Recompute filtered signal
    H = editor.Filter.Response;
    
    % Update plot
    set(hPlot, 'YData', H);
    set(hMarker, 'XData', editor.Center);  % Update position marker
    drawnow;
end
```

### Slider Callback

```matlab
% Slider callback
function sliderCallback(sliderHandle, ~, editor)
    newCenter = sliderHandle.Value;
    editor.setCenter(newCenter);
    % KernelChanged event automatically fires → plot updates
end
```

### Keyboard Navigation

```matlab
% Key press callback
function keyPressCallback(~, event, editor)
    switch event.Key
        case 'rightarrow'
            editor.shiftForward();
        case 'leftarrow'
            editor.shiftBackward();
        case 'uparrow'
            editor.expand();
        case 'downarrow'
            editor.contract();
    end
end
```

## Extending KernelEditor

### Custom Implementation

To create a custom editor for a new domain or kernel type:

```matlab
classdef MyCustomEditor < bct.filters.KernelEditor
    properties
        CustomParameter
    end
    
    methods
        function obj = MyCustomEditor(domain, filter, center, width)
            % Call superclass constructor
            obj@bct.filters.KernelEditor(domain, filter, center, width);
            
            % Initialize custom properties
            obj.CustomParameter = someValue;
        end
        
        function kernel = computeKernel(obj)
            % Implement domain-specific kernel computation
            x = obj.Domain.axis;
            kernel = myCustomKernelFunction(x, obj.Center, obj.Width, ...
                                             obj.CustomParameter);
        end
    end
    
    methods (Access = protected)
        function updateFilter(obj, kernel)
            % Override if filter needs special parameter handling
            obj.Filter.setParameter('customParam', obj.CustomParameter);
            updateFilter@bct.filters.KernelEditor(obj, kernel);
        end
    end
end
```

## API Reference

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `Center` | double | Current center position (domain coordinates) |
| `Width` | double | Current width/bandwidth (domain units) |
| `Domain` | bct.Domain | Associated domain object |
| `Filter` | bct.filters.Filter | Associated filter object |
| `StepSize` | double | Navigation step size (auto-computed from domain) |

### Methods

| Method | Description |
|--------|-------------|
| `shiftForward(nSteps)` | Move center forward by n steps (default: 1) |
| `shiftBackward(nSteps)` | Move center backward by n steps (default: 1) |
| `expand(factor)` | Increase width by factor or step (default: +1 step) |
| `contract(factor)` | Decrease width by factor or step (default: -1 step) |
| `setCenter(value)` | Set center position directly |
| `setWidth(value)` | Set width/bandwidth directly |
| `setStepSize(value)` | Set navigation step size |
| `update()` | Recompute kernel and update filter |
| `computeKernel()` | **Abstract** - Compute kernel values on domain |

### Events

| Event | When Fired | Use Case |
|-------|------------|----------|
| `KernelChanged` | After any parameter update | Synchronize GUI plots/displays |

## Examples

See `examples/demo_kernel_editors.m` for comprehensive demonstrations including:

- Time scrubber for signal navigation
- Spectral band selection on Lambda domain (eigenvalue spectrum)
- Frequency band analysis with standard EEG bands
- Event listener integration for GUIs
- Window type comparison (Gaussian, Hann, Hamming, Tukey)
- Lambda kernel comparison (Gaussian, Heat, Mexican Hat)

## Benefits

✅ **Separation of Concerns**: GUI logic separate from filter mathematics  
✅ **Reusability**: Same editor works across different GUI frameworks  
✅ **Consistency**: Uniform interface for all domain types  
✅ **Extensibility**: Easy to add new kernel types or domains  
✅ **Event-Driven**: Automatic propagation of parameter changes  
✅ **Domain-Aware**: Navigation respects domain spacing and units  

## Related Classes

- `bct.filters.Filter` - Filter class with kernel evaluation
- `bct.Domain` - Abstract domain base class
- `bct.Signal` - Signal class (lives on domain, can be filtered)
- `bct.filters.FilterDesigner` - Complete filter design GUI (uses KernelEditor)

---

**See Also**: Filter.m, Domain.m, Signal.m, FilterDesigner
