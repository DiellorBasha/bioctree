function cmap = getMap(name, n)
    name = lower(string(name));
    switch name
        case "parula"
            cmap = parula(n);
        case "turbo"
            cmap = turbo(n);
        case "hot"
            cmap = hot(n);
        case "cool"
            cmap = cool(n);
        case "jet"
            cmap = jet(n);
        otherwise
            error("Colormap '%s' not implemented in getMap().", name);
    end
end
