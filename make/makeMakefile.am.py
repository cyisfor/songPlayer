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
			self.sources.append(thing)
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

class Glade:
	sources = None
	def added(self,parent):
		parent.sources.append(parent.name + ".glade.ch")
glade = Glade()

class Q(Package):
	sources = ("queue.c",)
	def __init__(self):
		super(Q, self).__init__("GLIB")
queue = Q()

def program(name,*args):
	p = Program(name)
	for arg in args:
		p.add(arg)
	print(p.name+"_SOURCES =",*p.sources)
	if p.cflags:
		print(p.name+"_CFLAGS =",*p.cflags)
	if p.ldflags:
		print(p.name+"_LDADD =",*p.ldflags)
	print("")

program('addalbum',songdb)
program('best',songdb,Pkg.MEDIA)
program('current',songdb,Pkg.GUI,glade)
program('done',songdb,"adjust.c",queue,"select.c","synchronize.c")
program('dscanner',songdb,Pkg.MEDIA)
program('enqueue',songdb,queue)
