import os,shutil,sys

for path in sys.stdin:
    path = path.strip()
    if not path: continue
    print(path)    
    base = os.path.basename(path)
    dest = '/media/usb/'+base
    if os.path.exists(dest): continue
    try: shutil.copy2(path,dest)
    except OSError: continue
    with open('/media/usb/playlist.m3u','at') as out:
        out.write(base+'\n')
