function out = bct_list_groups(schemaPath)
% out = bct_list_groups(schemaPath)
% Returns only the top-level bct groups declared in the schema's root "groups" object.
% Output: out.groups is a string array of group paths, e.g. ["/signal" "/manifold" "/events" "/scales"]

    txt = fileread(schemaPath);

    %--- extract the substring of the root "groups": { ... } (balanced braces, ignore strings)
    startObj = regexp(txt, '"groups"\s*:\s*\{', 'once');
    if isempty(startObj)
        out = struct('groups', strings(0,1));
        return
    end
    braceStart = startObj + regexp(txt(startObj:end), '\{', 'once') - 1;
    braceEnd   = findMatchingBrace(txt, braceStart);

    grpObj = txt(braceStart+1 : braceEnd-1);  % inside the {...} of root groups

    %--- collect only immediate keys inside this object (depth==0 within grpObj)
    keys = collectImmediateKeys(grpObj);

    out = struct('groups', string(keys(:)));
end

function idx = findMatchingBrace(s, openIdx)
% Find the matching '}' for the '{' at openIdx, ignoring braces inside strings.
    depth = 0; inStr = false; esc = false;
    for i = openIdx:numel(s)
        ch = s(i);
        if inStr
            if esc
                esc = false;
            elseif ch == '\'
                esc = true;
            elseif ch == '"'
                inStr = false;
            end
        else
            if ch == '"'
                inStr = true;
            elseif ch == '{'
                depth = depth + 1;
            elseif ch == '}'
                depth = depth - 1;
                if depth == 0
                    idx = i; return
                end
            end
        end
    end
    error('Unbalanced braces while parsing JSON.');
end

function keys = collectImmediateKeys(objTxt)
% Scan objTxt (content inside {...}) and return keys at depth 0 only.
    keys = {};
    inStr = false; esc = false; depth = 0;
    i = 1; n = numel(objTxt);
    while i <= n
        ch = objTxt(i);
        if inStr
            if esc
                esc = false;
            elseif ch == '\'
                esc = true;
            elseif ch == '"'
                inStr = false;
            end
            i = i + 1;
            continue
        end

        if ch == '"'
            % possible key start only at depth==0
            [strVal, j] = readJSONString(objTxt, i);
            % check next non-space char after string for colon (key:)
            k = j + find(~isspace(objTxt(j+1:end)), 1, 'first');
            if depth == 0 && k <= n && objTxt(k) == ':'
                keys{end+1} = strVal; %#ok<AGROW>
            end
            i = j + 1;
        elseif ch == '{'
            depth = depth + 1; i = i + 1;
        elseif ch == '}'
            depth = depth - 1; i = i + 1;
        else
            i = i + 1;
        end
    end
end

function [val, j] = readJSONString(s, i)
% s(i) must be a double-quote. Returns string value and the index j of closing quote.
    assert(s(i) == '"', 'readJSONString: position must be at opening quote');
    buf = char([]);
    inStr = true; esc = false; j = i;
    i = i + 1;
    while inStr && i <= numel(s)
        ch = s(i);
        if esc
            buf(end+1) = ch; %#ok<AGROW>
            esc = false;
        elseif ch == '\'
            esc = true;
        elseif ch == '"'
            inStr = false; j = i;
            break
        else
            buf(end+1) = ch; %#ok<AGROW>
        end
        i = i + 1;
    end
    val = string(buf);
end
