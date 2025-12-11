classdef Import
  methods (Static)
    function B = fromFreeSurfer(path)
      warning('bct:io:DeprecatedAPI', ...
          'bct.io.graph.Import is deprecated. Use bct.io.import.graph() instead:\n  B = bct.io.import.graph(''%s'')', path);
      B = bct.io.import.graph(path, 'Format', 'FreeSurfer');
    end
    function B = fromBrainstorm(path, varargin)
      warning('bct:io:DeprecatedAPI', ...
          'bct.io.graph.Import is deprecated. Use bct.io.import.graph() instead:\n  B = bct.io.import.graph(''%s'', ''Format'', ''Brainstorm'')', path);
      B = bct.io.import.graph(path, 'Format', 'Brainstorm');
    end

    function B = fromFile(path, varargin)
      warning('bct:io:DeprecatedAPI', ...
          'bct.io.graph.Import is deprecated. Use bct.io.import.graph() instead:\n  B = bct.io.import.graph(''%s'')', path);
      B = bct.io.import.graph(path);
    end

    % Optional aliases
    function B = FreeSurfer(path, varargin), B = bct.io.graph.Import.fromFreeSurfer(path, varargin{:}); end
    function B = Brainstorm(path, varargin), B = bct.io.graph.Import.fromBrainstorm(path, varargin{:}); end
  end
end
