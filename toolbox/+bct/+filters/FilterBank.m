classdef FilterBank < handle
  % FilterBank - Collection of filters for multi-band analysis
  %
  % FilterBank manages a collection of Filter objects, providing methods
  % for batch operations, evaluation, and organization.
  %
  % Properties:
  %   Filters - Array of bct.filters.Filter objects
  %   Labels  - Cell array of filter labels
  %
  % Methods:
  %   FilterBank()              - Constructor
  %   add(filter)               - Add filter to bank
  %   remove(index_or_label)    - Remove filter from bank
  %   get(index_or_label)       - Get filter by index or label
  %   list()                    - Display filter information
  %   evaluateAll()             - Evaluate all filters
  %   clear()                   - Remove all filters
  %   length()                  - Number of filters in bank
  %
  % Example:
  %   B = bct();
  %   B.Time = bct.Time(0:0.01:1, 100);
  %   B.Omega = B.Time.dual;
  %   
  %   designer = bct.filters.FilterDesigner(B);
  %   bank = bct.filters.FilterBank();
  %   
  %   % Add filters for different frequency bands
  %   bank.add(designer.temporal('gaussian', 'center', 8, 'sigma', 1, 'label', 'theta'));
  %   bank.add(designer.temporal('gaussian', 'center', 12, 'sigma', 1, 'label', 'alpha'));
  %   bank.add(designer.temporal('gaussian', 'center', 30, 'sigma', 2, 'label', 'beta'));
  %   
  %   % List all filters
  %   bank.list();
  %   
  %   % Evaluate all
  %   responses = bank.evaluateAll();
  %
  % See also: bct.filters.Filter, bct.filters.FilterDesigner
  
  properties
    Filters = bct.filters.Filter.empty()  % Array of Filter objects
  end
  
  properties (Dependent)
    Labels   % Cell array of filter labels
  end
  
  methods
    function obj = FilterBank()
      % Constructor
      %
      % Syntax:
      %   bank = FilterBank()
      
      obj.Filters = bct.filters.Filter.empty();
    end
    
    function add(obj, filter)
      % Add filter to bank
      %
      % Syntax:
      %   bank.add(filter)
      %
      % Inputs:
      %   filter - bct.filters.Filter object
      
      if ~isa(filter, 'bct.filters.Filter')
        error('FilterBank:InvalidFilter', ...
          'Input must be a bct.filters.Filter object');
      end
      
      % Check for duplicate label
      if ~isempty(filter.Label) && any(strcmp(obj.Labels, filter.Label))
        warning('FilterBank:DuplicateLabel', ...
          'Filter with label "%s" already exists', filter.Label);
      end
      
      obj.Filters(end+1) = filter;
    end
    
    function remove(obj, index_or_label)
      % Remove filter from bank
      %
      % Syntax:
      %   bank.remove(index)
      %   bank.remove('label')
      %
      % Inputs:
      %   index_or_label - Numeric index or string label
      
      if isnumeric(index_or_label)
        % Remove by index
        idx = index_or_label;
        if idx < 1 || idx > length(obj.Filters)
          error('FilterBank:InvalidIndex', ...
            'Index %d out of range [1, %d]', idx, length(obj.Filters));
        end
      else
        % Remove by label
        idx = find(strcmp(obj.Labels, index_or_label), 1);
        if isempty(idx)
          error('FilterBank:LabelNotFound', ...
            'Filter with label "%s" not found', index_or_label);
        end
      end
      
      obj.Filters(idx) = [];
    end
    
    function filt = get(obj, index_or_label)
      % Get filter by index or label
      %
      % Syntax:
      %   filt = bank.get(index)
      %   filt = bank.get('label')
      %
      % Inputs:
      %   index_or_label - Numeric index or string label
      %
      % Returns:
      %   filt - bct.filters.Filter object
      
      if isnumeric(index_or_label)
        % Get by index
        idx = index_or_label;
        if idx < 1 || idx > length(obj.Filters)
          error('FilterBank:InvalidIndex', ...
            'Index %d out of range [1, %d]', idx, length(obj.Filters));
        end
        filt = obj.Filters(idx);
      else
        % Get by label
        idx = find(strcmp(obj.Labels, index_or_label), 1);
        if isempty(idx)
          error('FilterBank:LabelNotFound', ...
            'Filter with label "%s" not found', index_or_label);
        end
        filt = obj.Filters(idx);
      end
    end
    
    function list(obj)
      % Display filter information
      %
      % Syntax:
      %   bank.list()
      
      if isempty(obj.Filters)
        fprintf('FilterBank is empty\n');
        return;
      end
      
      fprintf('\nFilterBank contains %d filter(s):\n', length(obj.Filters));
      fprintf('%-5s %-15s %-15s %-20s\n', 'Index', 'Label', 'Kernel', 'Domain');
      fprintf('%s\n', repmat('-', 1, 60));
      
      for i = 1:length(obj.Filters)
        filt = obj.Filters(i);
        
        % Get label
        if isempty(filt.Label)
          label_str = '-';
        else
          label_str = char(filt.Label);
        end
        
        % Get kernel name
        kernel_str = char(filt.KernelName);
        
        % Get domain info
        domain_str = class(filt.Domain);
        % Remove 'bct.' prefix
        if startsWith(domain_str, 'bct.')
          domain_str = domain_str(5:end);
        end
        
        fprintf('%-5d %-15s %-15s %-20s\n', i, label_str, kernel_str, domain_str);
      end
      fprintf('\n');
    end
    
    function responses = evaluateAll(obj)
      % Evaluate all filters in bank
      %
      % Syntax:
      %   responses = bank.evaluateAll()
      %
      % Returns:
      %   responses - Cell array of filter responses
      
      responses = cell(length(obj.Filters), 1);
      
      for i = 1:length(obj.Filters)
        responses{i} = obj.Filters(i).evaluate();
      end
    end
    
    function clear(obj)
      % Remove all filters from bank
      %
      % Syntax:
      %   bank.clear()
      
      obj.Filters = bct.filters.Filter.empty();
    end
    
    function n = length(obj)
      % Get number of filters in bank
      %
      % Syntax:
      %   n = bank.length()
      %
      % Returns:
      %   n - Number of filters
      
      n = length(obj.Filters);
    end
    
    %% Dependent Properties
    
    function labels = get.Labels(obj)
      % Get cell array of filter labels
      labels = cell(length(obj.Filters), 1);
      for i = 1:length(obj.Filters)
        labels{i} = obj.Filters(i).Label;
      end
    end
  end
end
