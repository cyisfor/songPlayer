pcall(require,'luarocks.loader')
local l = require('lpeg')

local eol = -l.P(1)
local dependency = l.C((1 - l.S(' :\\.'))^1 * '.' * l.S('ch')) * (l.S' \n' + -1)
local dependencies = l.Ct(l.P{dependency + 1 * l.V(1)}^0)

local deps = {}

cflags="-pthread -I/usr/include/gtk-2.0 -I/usr/lib/gtk-2.0/include -I/usr/include/pango-1.0 -I/usr/include/atk-1.0 -I/usr/include/cairo -I/usr/include/pixman-1 -I/usr/include/libdrm -I/usr/include/gdk-pixbuf-2.0 -I/usr/include/libpng16 -I/usr/include/pango-1.0 -I/usr/include/freetype2 -I/usr/include/libpng16 -I/usr/include/harfbuzz -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include -I/usr/include/freetype2 -I/usr/include/libpng16 -I/usr/include/harfbuzz -I/usr/include/gio-unix-2.0/ -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include"

local function collect(src)
    if deps[src] then return end
    deps[src] = true
    src = src:sub(1,-2)..'c'
    local inp = io.popen("gcc -MM "..cflags.." "..src)
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
-- hax
io.write(": o/.rebuild | o/\n")

