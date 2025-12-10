function demo_tailwind_ui_elements()
    %DEMO_TAILWIND_UI_ELEMENTS Show all UI elements in MATLAB figure
    %
    %   This demo displays the complete UI elements showcase in a MATLAB
    %   figure using the uihtml component with absolute file paths.
    
    % Get paths - use new portable structure (no package)
    thisFile = mfilename('fullpath');
    tailwindPath = fileparts(thisFile);  % ui/tailwind
    uiPath = fileparts(tailwindPath);     % ui
    distPath = fullfile(tailwindPath, 'dist');
    elementsPath = fullfile(tailwindPath, 'components', 'elements');
    
    % Verify files exist
    cssFile = fullfile(distPath, 'bct-ui.css');
    jsFile = fullfile(distPath, 'bct-ui.js');
    
    if ~isfile(cssFile)
        error('CSS file not found: %s\nRun: cd toolbox/+bct/+ui/tailwind && npm run build', cssFile);
    end
    
    % Read the original HTML file
    htmlFile = fullfile(elementsPath, 'ui-elements.html');
    if ~isfile(htmlFile)
        error('HTML file not found: %s', htmlFile);
    end
    
    % Read and modify HTML to use absolute paths
    html = fileread(htmlFile);
    
    % Replace relative paths with absolute file:// URLs
    html = strrep(html, '../dist/bct-ui.css', sprintf('file:///%s', strrep(cssFile, '\', '/')));
    html = strrep(html, '../dist/bct-ui.js', sprintf('file:///%s', strrep(jsFile, '\', '/')));
    
    % Create figure
    fig = uifigure('Name', 'BCT Tailwind UI Elements', 'Position', [100 100 1200 800]);
    
    % Create HTML component
    htmlControl = uihtml(fig);
    htmlControl.Position = [10 10 1180 780];
    htmlControl.HTMLSource = html;
    
    fprintf('UI Elements showcase loaded!\n');
    fprintf('Scroll through the page to see all available components.\n');
    fprintf('This is a reference for all Tailwind UI elements you can use.\n');
end
