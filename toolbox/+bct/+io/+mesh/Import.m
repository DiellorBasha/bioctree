classdef Import
  methods (Static)
    function B = fromFreeSurfer(path)
      warning('bct:io:DeprecatedAPI', ...
          'bct.io.mesh.Import is deprecated. Use bct.io.import.mesh() instead:\n  B = bct.io.import.mesh(''%s'')', path);
      B = bct.io.import.mesh(path, 'Format', 'FreeSurfer');
    end
    function B = fromBrainstorm(path, varargin)
      warning('bct:io:DeprecatedAPI', ...
          'bct.io.mesh.Import is deprecated. Use bct.io.import.mesh() instead:\n  B = bct.io.import.mesh(''%s'', ''Format'', ''Brainstorm'')', path);
      B = bct.io.import.mesh(path, 'Format', 'Brainstorm');
    end

    function B = fromFile(path, varargin)
      warning('bct:io:DeprecatedAPI', ...
          'bct.io.mesh.Import is deprecated. Use bct.io.import.mesh() instead:\n  B = bct.io.import.mesh(''%s'')', path);
      B = bct.io.import.mesh(path);
    end

    % Optional aliases
    function B = FreeSurfer(path, varargin), B = bct.io.mesh.Import.fromFreeSurfer(path, varargin{:}); end
    function B = Brainstorm(path, varargin), B = bct.io.mesh.Import.fromBrainstorm(path, varargin{:}); end
  end
end
