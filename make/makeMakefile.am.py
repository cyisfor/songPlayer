# sigh

class Package:
	sources = None
	def __init__(self, name):
		self.name = name
	def added(self,parent):
		parent.addCflags("$(" + self.name + "_CFLAGS)")
		parent.addLDflags("$(" + self.name + "_LIBS)")

class pthread:
	sources = None
	def added(self,parent):
		parent.addCflags("-pthread")
pthread = pthread()

class Program(str):
	def __init__(self,name,noinst=False):
		self.noinst = noinst
		self.name = name
		self.sources = []
		self.cflags = []
		self.ldflags = []
	def addCflags(self,flags):
		self.cflags.append(flags)
	def addLDflags(self,flags):
		self.ldflags.append(flags)
	def add(self,thing):
		if isinstance(thing,str):
			self.sources.append("src/"+thing)
			return
		thing.added(self)
		if thing.sources:
			self.sources.extend("src/" + s for s in thing.sources)

class SongDB:
	sources = None
	def added(self,parent):
		parent.addLDflags("libsongdb.la")
		parent.addCflags("$(DB_CFLAGS)")
songdb = SongDB()

class Pkg:
	sources = None
	MEDIA = Package("MEDIA")
	GUI = Package("GUI")
	GCRYPT = Package("GCRYPT")

class Glade:
	sources = None
	def added(self,parent):
		Pkg.GUI.added(parent)
		parent.sources.append(parent.name + ".glade.ch")
glade = Glade()

class Q(Package):
	sources = ("queue.c","adjust.c")
	def __init__(self):
		super(Q, self).__init__("GLIB")
	def added(self,parent):
		super(Q, self).added(parent)
		songdb.added(parent)
		parent.addCflags("-pthread")
queue = Q()

programs = []
def program(name,*args,noinst=False):
	p = Program(name,noinst=noinst)
	for arg in args:
		p.add(arg)
	programs.append(p)

class Fields:
	sources = None
	def added(self,parent):
		parent.sources.append(parent.name + ".fields.ch")
Fields = Fields()

program('addalbum',songdb)
program('best',songdb,Pkg.MEDIA)
program('current',songdb,Pkg.GUI,glade)
program('done',songdb,queue,"select.c","synchronize.c")
program('dscanner',songdb,Pkg.MEDIA)
program('enqueue',queue,"synchronize.c")
program('enqueuePath',queue)
program('graph',"adjust.c")
program('import',"derpstring.c","hash.c",songdb,Pkg.GCRYPT)
program('migrate',songdb)
program('mode',queue,'synchronize.c')
program('next','config.c','get_pid.c',songdb)
program('nowplaying','nextreactor.c',Fields)
program('nowplaying-make',noinst=True)
program('pause',songdb,glade,'get_pid.c','config.c')
program('player','config.c','get_pid.c',queue,'select.c','signals.c',
				'synchronize.c',Pkg.MEDIA)
program('playlist','nextreactor.c',songdb)
program('ratebyalbum',songdb)
program('ratebytitle',songdb)
program('replay',queue,'synchronize.c')
program('replaygain_scanner',songdb)
program('testadjust','adjust.c',noinst=True)
program('testqueue',queue,'select.c','synchronize.c',noinst=True)

programs = sorted(programs)
print("bin_PROGRAMS =",*(p for p in programs if not p.noinst))
noinst = [p for p in programs if not p.noinst]
if noinst:
	print("noinst_PROGRAMS =",*(sorted(noinst)))
	
for p in sorted(programs):
	derpname = p.name.replace("-","_").replace(".","_")
	print(derpname+"_SOURCES =","src/"+p.name+".c",*p.sources)
	if p.cflags:
		print(derpname+"_CFLAGS =",*p.cflags)
	if p.ldflags:
		print(derpname+"_LDADD =",*p.ldflags)
	print("")
