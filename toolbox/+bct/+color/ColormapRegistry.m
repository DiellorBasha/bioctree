classdef ColormapRegistry < handle
    % ColormapRegistry
    %
    % Singleton registry for all colormaps known to the toolbox.
    % Acts as a semantic contract between data, UI, and rendering.

    properties (Access = private)
        Maps containers.Map
    end

    methods (Static)
        function reg = instance()
            persistent singleton
            if isempty(singleton)
                singleton = bct.color.ColormapRegistry();
                singleton.initialize();
            end
            reg = singleton;
        end
    end

    methods (Access = private)
        function initialize(obj)
            obj.Maps = containers.Map('KeyType','char','ValueType','any');

            defs = bct.color.colormapTable();
            for i = 1:numel(defs)
                def = bct.color.ColormapDefinition(defs(i));
                obj.register(def);
            end
        end
    end

    methods
        function register(obj, def)
            arguments
                obj
                def (1,1) bct.color.ColormapDefinition
            end
            key = char(def.Name);
            obj.Maps(key) = def;
        end

        function def = get(obj, name)
            name = char(name);
            assert(obj.Maps.isKey(name), ...
                'ColormapRegistry:UnknownColormap "%s"', name);
            def = obj.Maps(name);
        end

        function names = list(obj, category)
            keys = obj.Maps.keys;
            names = {};
            for i = 1:numel(keys)
                def = obj.Maps(keys{i});
                if nargin < 2 || def.Category == category
                    names{end+1} = char(def.Name); %#ok<AGROW>
                end
            end
        end
        
        function defs = listByCategory(obj)
            % Return struct with colormap names organized by category
            cats = enumeration('bct.color.enum.ColormapCategory');
            defs = struct();
            for i = 1:numel(cats)
                cat = cats(i);
                catName = char(cat);
                defs.(catName) = obj.list(cat);
            end
        end
        
        function tf = has(obj, name)
            % Check if colormap exists
            name = char(name);
            tf = obj.Maps.isKey(name);
        end
    end
end
