import os
import subprocess as s
import io
import random

syms = {}

for o in (o for o in os.listdir("o") if o.endswith(".o")):
	nm = s.Popen(["nm","o/"+o],stdout=s.PIPE)
	for line in io.TextIOWrapper(nm.stdout):
			kind = line[17]
			if kind != 'T': continue
			name = line[19:].rstrip()
			syms[name] = o
			print((kind,name))

link = "player"
os = ["o/player.o"]
while True:
		gcc = s.Popen(["gcc","-o",link]+os,stderr=s.PIPE)
		print(gcc.stderr.read())
		break
