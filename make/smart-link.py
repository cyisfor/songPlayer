import os,sys
import subprocess as s
import io
import random
import re

# find a program's dependencies from a pile of objects
# record what symbols they define when compile...
# auto-resolves undefined references, given the right objects

import sqlite3
import time
db = sqlite3.connect("make/deps.sqlite",timeout=5000)

def waitlock(f):
	while True:
		try:
			with db:
				return f()
		except sqlite3.OperationalError as e:
			if e.args and e.args[0] == "database is locked":
				print("wait for the db to unlock, dammit!")
				time.sleep(0.5)
				continue
			raise
@waitlock
def _():
	db.executescript("""
CREATE TABLE 
IF NOT EXISTS
deps (
prog TEXT NOT NULL,
obj TEXT NOT NULL,
UNIQUE(prog,obj));

CREATE TABLE 
IF NOT EXISTS
syms (
sym TEXT NOT NULL,
obj TEXT NOT NULL,
UNIQUE(sym,obj));

CREATE INDEX
IF NOT EXISTS
bysym ON syms(sym);

CREATE INDEX
IF NOT EXISTS
byrsym ON syms(obj);

CREATE INDEX
IF NOT EXISTS
bydep ON deps(prog);

CREATE INDEX
IF NOT EXISTS
byrdep ON deps(obj);
""")

mode = sys.argv[1]

def slurp_syms(o):
#	print("Slurping",o)
	derps = []
	nm = s.Popen(["nm",o],stdout=s.PIPE)
	for line in io.TextIOWrapper(nm.stdout):
		kind = line[17]
		if kind != 'T': continue
		name = line[19:].rstrip()
		db.execute("INSERT OR IGNORE INTO syms (sym,obj) VALUES (?,?)",(name,o))

def docompile():
	code = s.call(sys.argv[3:])
	if code != 0: raise SystemExit(code)
	o = sys.argv[2]
	db.execute("DELETE FROM syms WHERE sym IN (SELECT sym FROM syms WHERE obj = ?)",(o,))
	db.execute("DELETE FROM deps WHERE prog IN (SELECT prog FROM deps WHERE obj = ?)",(o,))
	try: 
		os.unlink(os.environ["DEPS"])
		print("BLAM DEPS")
	except OSError: pass
	with db:
		slurp_syms(o)
if mode == 'compile':
	waitlock(docompile)
	db.close()
	raise SystemExit

def slurp():
	print("Slurping all symbols we can find")
	with db:
		for obj in os.environ["OBJECTS"].split():
			slurp_syms(obj)

if mode == "slurp":
	waitlock(slurp)
	db.close()
	raise SystemExit

def refresh_deps():
	dest = os.environ["DEPS"]
	with open(dest+".temp","wt") as out:
		for prog,objs in db.execute("""
SELECT prog,
(SELECT group_concat(B.obj,' ') FROM deps AS B WHERE B.prog = A.prog)
FROM deps AS A GROUP BY prog
"""):
#			print((prog,objs))
			out.write(prog + ": " + objs + "\n")
	os.rename(dest+".temp",dest)


if mode == "deps":
	waitlock(refresh_deps)
	raise SystemExit

assert mode == 'link'

prog = sys.argv[2]
args = sys.argv[3:]
derp = args.index("@@DERP@@")
prefix = args[:derp]
suffix = args[derp+1:]
del derp

bads = set()
badlines = []
unrefpat = re.compile("undefined reference to `([^']+)'")

@waitlock
def _():
	global objs
	objs = set(row[0] for row in db.execute("SELECT obj FROM deps WHERE prog = ?", (prog,)))

if objs:
	print("cached deps"," ".join(objs))

need_blam_deps = False
tried_slurping = False

while True:
	gcc = s.Popen(prefix+list(objs)+suffix,stderr=s.PIPE)
	gotit = False
	for line in io.TextIOWrapper(gcc.stderr):
		m = unrefpat.search(line)
		if m:
			sym = m.group(1)
			@waitlock
			def _():
				global gotit
				o = db.execute("SELECT obj FROM syms WHERE sym = ?", (sym,)).fetchone()
				if o:
					o = o[0]
					if not o in objs:
	#					print("yay",sym,o)
						objs.add(o)
						db.execute("INSERT OR IGNORE INTO DEPS (prog,obj) VALUES (?,?)",
												 (prog, o))
					gotit = True
				else:
					bads.add(sym)
		else:
			badlines.append(line)
	code = gcc.wait()
	if code == 0: 
		break
	if not gotit:
		if tried_slurping:
			print("can't compile!",args)
			print(bads)
			for line in badlines:
				print(line)
			raise SystemExit(3)
		else:
			print("still missing symbols...")
			slurp()
			tried_slurping = True

if gotit:
	#this refreshes it several times before the final program is linked...
	#refresh_deps()
	#the next run of make will refresh the deps file
	try: os.unlink(os.environ["DEPS"])
	except OSError: pass

waitlock(db.commit)
db.close()
