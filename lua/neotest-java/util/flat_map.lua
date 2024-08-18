local function flat_map(func, t)
    local result = {}
    for _, v in ipairs(t) do
        local mapped = func(v)
        if type(mapped) == "table" then
            vim.list_extend(result, mapped)
        else
            table.insert(result, mapped)
        end
    end
    return result
end

return flat_map
