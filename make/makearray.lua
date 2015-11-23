local name=arg[1]
local file=arg[2]
assert(file)

local lfs = require('lfs')
local size = lfs.attributes(file,'size')

local function printthing(...)
    for i,v in ipairs({...}) do
        io.write('\t')
        if v then io.write(v) end
    end
    io.write('\n')
end

printthing('.file','"iter.c"')
printthing('.data')
local function globl(name,align)
    printthing('.globl',name)
    if(align) then
        printthing(".align",align)
    end
    printthing('.type',name..', @object')
    printthing('.size',name..', '..tostring(size))
    print (name..':')
end

globl(name)
local inp = io.open(file)
while true do
    local s = inp:read(1)
    if s == nil then break end
    printthing('.byte',string.byte(s,1))
end

globl(name..'Size',4)
printthing('.long',size)

printthing('.ident','"GCC: (GNU) 4.9.1"')
printthing('.section','.note.GNU-stack,"",@progbits')
