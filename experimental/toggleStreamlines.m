function toggleStreamlines(val, app)
    if strcmp(val,'On')
        set(app.hStream,'Visible','on')
    else
        delete(app.hStream)
        app.hStream = gobjects(0);
    end
end
