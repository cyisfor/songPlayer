# sigh
with open("make/Makefile.prefix.am") as inp:
	print(inp.read())

built_sources = []

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

class Program:
	def __lt__(self,other):
		return self.name < other.name 
	def __init__(self,name,noinst):
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
		source = parent.name + ".glade.ch"
		built_sources.append(source)
		parent.sources.append(source)
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
	p = Program(name,noinst)
	for arg in args:
		p.add(arg)
	programs.append(p)

class Fields:
	sources = None
	def added(self,parent):
		source = parent.name + ".fields.ch"
		built_sources.append(source)
		parent.sources.append(source)
Fields = Fields()

class LibG:
	sources = None
	def added(self,parent):
		parent.addLDflags("libguess/src/libguess/libguess.so")
LibG = LibG()

program('addalbum',songdb)
program('best',songdb,Pkg.MEDIA)
program('current',songdb,Pkg.GUI,glade)
program('done',songdb,queue,"select.c","synchronize.c")
program('dscanner',songdb,Pkg.MEDIA)
program('enqueue',queue,"synchronize.c")
program('enqueuePath',queue)
program('graph',"adjust.c")
program('import',"derpstring.c","hash.c",songdb,Pkg.GCRYPT,LibG)
program('migrate',songdb)
program('mode',queue,'synchronize.c')
program('next','config.c','get_pid.c',songdb)
program('nowplaying','nextreactor.c',Fields,songdb)
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
noinst = []
print("bin_PROGRAMS = ",end='')
for p in programs:
	if p.noinst:
		noinst.append(p)
	else:
		print(" \\\n ",p.name,end='')
print("\n")

if noinst:
	print("noinst_PROGRAMS =",end='')
	for p in sorted(noinst):
		print("\\\n ",p.name,end='')
	print("\n")

if built_sources:
	print("BUILT_SOURCES =",end='')
	for source in sorted(built_sources):
		print(" \\\n ",source,end='')
	print("\n")
	
for p in sorted(programs):
	derpname = p.name.replace("-","_").replace(".","_")
	print(derpname+"_SOURCES =","src/"+p.name+".c",*p.sources)
	if p.cflags:
		print(derpname+"_CFLAGS =",*p.cflags)
	if p.ldflags:
		print(derpname+"_LDADD =",*p.ldflags)
	print("")
