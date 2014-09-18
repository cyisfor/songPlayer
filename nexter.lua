local ffi = require('ffi') -- grumble

ffi.cdef('int setenv(const char *name, const char *value, int overwrite);')
local setenv = ffi.C.setenv

local s = require('subprocess')
local gi = require('lgi')
local gtk = gi.require('Gtk')
local glib = gi.require('GLib')

top = gtk.Window {
    title = 'Nexter',
    default_width = 400,
    default_height = 40,
    on_destroy = gtk.main_quit
}
scale = gtk.Scale.new_with_range(gtk.Orientation.HORIZONTAL,-4,2,0.1)
scale:set_value(-1)
btn = gtk.Button.new_with_label("Next")

vbox = gtk.VBox()
top:add(vbox)
vbox:pack_start(scale,true,true,1)
vbox:pack_start(btn,true,false,0)


local nextProgram = arg[0]:gsub('nexter%.lua','next')
if not nextProgram:find('/',0,true) then
    nextProgram = './' .. nextProgram
end
-- local nextProgram = arg[

function btn:on_clicked(e)
    setenv('rating',tostring(scale:get_value()),1)
    s.call{nextProgram}
end

top:show_all()

gtk.main()
