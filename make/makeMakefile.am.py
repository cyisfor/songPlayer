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

class Program:
	def __init__(self,name):
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
			self.sources.extend(thing.sources)

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
	sources = ("src/queue.c",)
	def __init__(self):
		super(Q, self).__init__("GLIB")
	def added(self,parent):
		super(Q, self).added(parent)
		parent.addCflags("-pthread")
queue = Q()

def program(name,*args):
	p = Program(name)
	for arg in args:
		p.add(arg)
	derpname = p.name.replace("-","_").replace(".","_")
	print(derpname+"_SOURCES =","src/"+p.name+".c",*p.sources)
	if p.cflags:
		print(derpname+"_CFLAGS =",*p.cflags)
	if p.ldflags:
		print(derpname+"_LDADD =",*p.ldflags)
	print("")

class Fields:
	def added(self,parent):
		parent.sources.append(parent.name + ".fields.ch")
Fields = Fields()

program('addalbum',songdb)
program('best',songdb,Pkg.MEDIA)
program('current',songdb,Pkg.GUI,glade)
program('done',songdb,"adjust.c",queue,"select.c","synchronize.c")
program('dscanner',songdb,Pkg.MEDIA)
program('enqueue',songdb,queue)
program('enqueuePath',songdb,"adjust.c",queue)
program('graph',"adjust.c")
program('import',"derpstring.c","hash.c",songdb,Pkg.GCRYPT)
program('migrate',songdb)
program('mode','adjust.c',queue,'synchronize.c',songdb)
program('next','config.c','get_pid.c',songdb)
program('nowplaying','nextreactor.c',Fields)
program('nowplaying-make')
program('pause',glade,'get_pid.c','config.c')
