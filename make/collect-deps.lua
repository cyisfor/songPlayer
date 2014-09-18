local deps = {}

local function collect(src)
    if deps[src] then return end
    deps[src] = true
    src = src:sub(1,-2)..'c'
    local inp = io.popen("gcc -MM "..src)
    local line = inp:read('*a')
    if not inp:close() then return end

    for dep in line:gmatch("[^ :\\]+%.[ch]") do
        if dep ~= src then
            collect(dep)
        end
    end
end

collect(arg[1])

for src,_ in pairs(deps) do
    local obj = 'o/'..src:sub(1,-2)..'o'
    io.write(obj..' ')
end

io.write('\n')
local first = true
for src in pairs(deps) do
    if first then
        first = false
    else
        io.write(' ')
    end
    local obj = 'o/'..src:sub(1,-2)..'o'
    io.write(obj)
end

io.write(": make/config.mk | o/\n")

