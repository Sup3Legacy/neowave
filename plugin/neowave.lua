function print_data(parser)
    print("Name " .. (parser.name or ""))
    print("Version " .. (parser.version or ""))
    print("Comment " .. (parser.comment or ""))
    print("Variables ")
    for _, v in pairs(parser.variables) do
        print("  " .. v.typ .. " " .. v.width .. " " .. v.symbol .. " " .. v.name)
    end
end

function parse(data)
    fh, err = io.open(data.args)
    if err then 
        print("File not found.")
        return
    end
    parser = {
        variables = {},
        initial_values = {},
        timestamps = {},
        initials = {}
    }
    pending_timestamp = {}
    pending_timestamp_val = nil
    initial = true
    is_dumpvars = false
    is_tag = false
    while true do
        line = fh:read()
        if line == nil then
            break;
        end
        _words = {}
        for str in string.gmatch(line, "[^ ]+") do 
            table.insert(_words, str)
        end
        timestamp = line:match("#(%d+)")
        if _words[1] == "$var" then
            -- Variable declaration
            if #_words ~= 6 or _words[6] ~= "$end" then
                print("Ill-formed variable declaration")
                return
            end
            parser.variables[#(parser.variables) + 1] = {
                typ = _words[2],
                width = _words[3],
                symbol = _words[4],
                name = _words[5],
            }
        elseif _words[1] == "$dumpvars" then 
            is_dumpvars = true
        elseif (_words[1] == "$end") and (is_dumpvars) then 
            is_dumpvars = false
        elseif _words[#_words] == "$end" then 
            -- No need to do anything for now
            is_tag = false
        elseif timestamp then
            -- Save all pending 
            if pending_timestamp_val then 
                parser.timestamps[pending_timestamp_val] = pending_timestamp 
            end
            pending_timestamp_val = timestamp
            pending_timestamp = {}
        elseif _words[1]:sub(1, 1) == "$" then 
            -- A tag that is ignored for now
            -- print("Ignored unused tag " .. _words[1])
            is_tag = true
        elseif not is_tag then 
            -- Most probably a value
            found = false
            for _, var in pairs(parser.variables) do 
                match = line:find(var.symbol, 1, true)
                if match ~= nil then
                    -- Found the variable associated with the Value
                    pos,_ = match 
                    if pending_timestamp[var.symbol] ~= nil then 
                        print("Found duplicate value for " .. var.name .. " at timestamp " .. (pending_timestamp_val or "Initialization") .. "at pos " .. pos)
                    else
                        pending_timestamp[var.symbol] = line:sub(1, pos - 1)
                    end
                    found = true
                    break
                end
            end 
            if not found then
                print("Could not parse assumed value " .. line)
            end
        end
        -- print(line)
    end
    print_data(parser)
    return parser;
end

vim.api.nvim_create_user_command('NeowaveTest', parse, {nargs=1, complete="file"})
