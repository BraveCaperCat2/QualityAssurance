-- Splits a string by a pattern.
function Split(str, delim, maxNb)
    if not str then
        return {}
    end
    if string.find(str, delim) == nil then
        return { str }
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0
    end
    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local nb = 0
    local lastPos
    for part, pos in string.gfind(str, pat) do
        nb = nb + 1
        result[nb] = part
        lastPos = pos
        if nb == maxNb then
            break
        end
    end
    if nb ~= maxNb then
        result[nb + 1] = string.sub(str, lastPos)
    end
    return result
end

-- Converts list of technologies to string of technology names
-- Converts list of technology effects to string of effects
function ListToString(List)
    local result = {}
    if List ~= nil then
        for _,Effect in pairs(List) do
            if Effect.name ~= nil then
                table.insert(result, Effect.name)
            elseif Effect.type ~= nil then
                if Effect.type == "unlock-quality" then
                    table.insert(result, "quality:" .. Effect.quality)
                elseif Effect.type == "unlock-recipe" then
                    table.insert(result, "recipe:" .. Effect.recipe)
                else
                    table.insert(result, "\"" .. Effect.type .. "\"")
                end
            else
                table.insert(result, serpent.block(Effect))
            end
        end
    end
    return table.concat(result, ", ")
end

-- Returns copy of array without nil entries
function CleanNils(t)
    local ans = {}
    for _,v in pairs(t) do
      ans[ #ans+1 ] = v
    end
    return ans
end

function Empty(f)
    return f == nil or f == {} or f == ""
end