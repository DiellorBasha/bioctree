function wrapped = wrapFieldOperator(spec, implFn, ctx)
%WRAPFIELDOPERATOR Create Field-aware wrapper for operator implementation
%
% Syntax:
%   wrapped = bct.runtime.operators.wrapFieldOperator(spec, implFn, ctx)
%
% Inputs:
%   spec    - Operator spec with Field signatures (input/output or inputs/output)
%   implFn  - Implementation function handle (accepts raw arrays)
%   ctx     - Runtime context with Manifold and representations
%
% Returns:
%   wrapped - Function handle that accepts/returns Fields
%
% The wrapper performs:
%   1. Input validation (Field schema, meshId, support/valueType matching)
%   2. Time policy enforcement
%   3. Raw value extraction
%   4. Implementation call
%   5. Output Field packaging with provenance
%
% Example:
%   spec = struct with .input and .output Field signatures
%   impl = @(ctx, X) someComputation(X);
%   wrapped = wrapFieldOperator(spec, impl, ctx);
%   outputField = wrapped(inputField);
%
% See also: bct.fields.validate, bct.fields.make

% Determine if single input or multiple inputs
multiInput = isfield(spec, 'inputs');

% Create wrapper function
wrapped = @wrapperFunction;

    function Fout = wrapperFunction(varargin)
        % Parse inputs
        if multiInput
            % Multiple inputs expected
            if nargin ~= length(spec.inputs)
                error('bct:runtime:WrongArity', ...
                    'Operator "%s" expects %d inputs, got %d', ...
                    spec.id, length(spec.inputs), nargin);
            end
            Fins = varargin;
        else
            % Single input expected
            if nargin ~= 1
                error('bct:runtime:WrongArity', ...
                    'Operator "%s" expects 1 input, got %d', ...
                    spec.id, nargin);
            end
            Fins = {varargin{1}};
        end
        
        % Validate and extract raw values
        rawInputs = cell(size(Fins));
        timeStructs = cell(size(Fins));
        
        for i = 1:length(Fins)
            F = Fins{i};
            
            % Get expected signature
            if multiInput
                sigSpec = spec.inputs(i);
            else
                sigSpec = spec.input;
            end
            
            % Validate Field
            if ~isstruct(F)
                error('bct:runtime:InvalidInput', ...
                    'Input %d to operator "%s" must be a Field struct', i, spec.id);
            end
            
            % Validate against schema
            bct.fields.validate(F);
            
            % Validate with Manifold if meshId present
            if isfield(F, 'meshId')
                if ~strcmp(F.meshId, ctx.Manifold.ID)
                    error('bct:runtime:MismatchedMeshId', ...
                        'Field meshId "%s" does not match context Manifold.ID "%s"', ...
                        F.meshId, ctx.Manifold.ID);
                end
            end
            
            % Validate support matches signature
            if ~strcmp(F.support, sigSpec.support)
                error('bct:runtime:SupportMismatch', ...
                    'Input %d to operator "%s": expected support "%s", got "%s"', ...
                    i, spec.id, sigSpec.support, F.support);
            end
            
            % Validate valueType matches signature
            if ~strcmp(F.valueType, sigSpec.valueType)
                error('bct:runtime:ValueTypeMismatch', ...
                    'Input %d to operator "%s": expected valueType "%s", got "%s"', ...
                    i, spec.id, sigSpec.valueType, F.valueType);
            end
            
            % Validate time policy
            isTimeVarying = bct.fields.isTimeVarying(F);
            if strcmp(sigSpec.time, 'require') && ~isTimeVarying
                error('bct:runtime:TimeRequired', ...
                    'Input %d to operator "%s" must be time-varying', i, spec.id);
            end
            
            % Extract raw value
            rawInputs{i} = F.value;
            
            % Store time struct for preservation
            if isfield(F, 'time')
                timeStructs{i} = F.time;
            else
                timeStructs{i} = [];
            end
        end
        
        % Handle time alignment for multi-input operators
        if multiInput && length(Fins) > 1
            for i = 1:length(spec.inputs)
                if strcmp(spec.inputs(i).time, 'align')
                    % Check all time-varying inputs have same nSamples
                    for j = (i+1):length(Fins)
                        if bct.fields.isTimeVarying(Fins{i}) && ...
                           bct.fields.isTimeVarying(Fins{j})
                            if size(Fins{i}.value, ndims(Fins{i}.value)) ~= ...
                               size(Fins{j}.value, ndims(Fins{j}.value))
                                error('bct:runtime:TimeMismatch', ...
                                    'Time-varying inputs to operator "%s" must have aligned time samples', ...
                                    spec.id);
                            end
                        end
                    end
                end
            end
        end
        
        % Call implementation
        if multiInput
            rawOutput = implFn(ctx, rawInputs{:});
        else
            rawOutput = implFn(ctx, rawInputs{1});
        end
        
        % Package output as Field
        Fout = packageOutput(rawOutput, timeStructs);
    end

    function Fout = packageOutput(rawValue, inputTimeStructs)
        % Determine time handling
        outputTime = [];
        inputIsTimeVarying = false;
        
        % Check if any input was time-varying
        for i = 1:length(inputTimeStructs)
            if ~isempty(inputTimeStructs{i})
                inputIsTimeVarying = true;
                outputTime = inputTimeStructs{i};
                break;
            end
        end
        
        % Apply time policy
        if strcmp(spec.output.time, 'drop')
            outputTime = [];
        elseif strcmp(spec.output.time, 'preserve') && inputIsTimeVarying
            % Keep input time
        else
            % 'optional' or 'require' - use natural time
            if ndims(rawValue) > 2 || ...
               (ndims(rawValue) == 2 && strcmp(spec.output.valueType, 'scalar') && size(rawValue, 2) > 1)
                % Output is time-varying but no input time available
                if isempty(outputTime)
                    % Create default time struct
                    if strcmp(spec.output.valueType, 'scalar')
                        nT = size(rawValue, 2);
                    else
                        nT = size(rawValue, 3);
                    end
                    outputTime = struct('t0', 0, 'dt', 1, 'unit', 's', ...
                                       'samples', 0:nT-1);
                end
            end
        end
        
        % Create Field
        makeArgs = {'support', spec.output.support, ...
                   'valueType', spec.output.valueType, ...
                   'value', rawValue};
        
        if ~isempty(outputTime)
            makeArgs = [makeArgs, {'time', outputTime}];
        end
        
        % Add meshId
        makeArgs = [makeArgs, {'meshId', ctx.Manifold.ID}];
        
        % Add provenance metadata
        meta = struct();
        meta.operatorId = spec.id;
        meta.operatorName = spec.name;
        meta.domain = spec.domain;
        meta.backend = spec.representation;
        meta.timestamp = datetime('now');
        
        makeArgs = [makeArgs, {'metadata', meta}];
        
        % Create Field
        Fout = bct.fields.make(makeArgs{:});
    end
end
