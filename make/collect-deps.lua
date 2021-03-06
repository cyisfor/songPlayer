pcall(require,'luarocks.loader')
local l = require('lpeg')

local eol = -l.P(1)
local dependency = l.C((1 - l.S(' :\\.'))^1 * '.' * l.S('ch')) * (l.S' \n' + -1)
local dependencies = l.Ct(l.P{dependency + 1 * l.V(1)}^0)

local deps = {}

local function collect(src)
    if deps[src] then return end
    deps[src] = true
		print(src,"ture")
    src = src:sub(1,-2)..'c'
    local inp = io.popen("gcc '-DGLIB_CHECK_VERSION(a,b,c)' -MM "..src)
    local line = inp:read('*a')
    if not inp:close() then return end

    for _,dep in ipairs(dependencies:match(line)) do
        if dep ~= src then
            collect(dep)
        end
    end
end

collect(arg[1])

for src,_ in pairs(deps) do
    local obj = 'o/'..src:sub(5,-2)..'o'
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
    local obj = 'o/'..src:sub(5,-2)..'o'
    io.write(obj)
end
-- hax
io.write(": o/.rebuild | o/\n")

