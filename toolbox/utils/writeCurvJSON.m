function writeCurvJSON(name, values)
% values: N×1 double (one per vertex), NaN allowed to mark NoData
vals = single(values(:));                    % Float32
fid = fopen([name '.bin'],'w'); fwrite(fid, vals, 'single'); fclose(fid);

meta = struct('count', numel(vals), ...
              'dtype','float32','endianness','little', ...
              'nan_is_nodata', true, ...
              'min', min(vals,[],'omitnan'), ...
              'max', max(vals,[],'omitnan'), ...
              'name', name);
str = jsonencode(meta, 'PrettyPrint', true);
fid = fopen([name '.json'],'w'); fwrite(fid, str); fclose(fid);
end

% Example:
% writeScalar('lh_curv',  curvature_L);   % N×1
% writeScalar('lh_thick', thickness_L);
% writeScalar('lh_sulc',  sulcal_L);
