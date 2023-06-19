
import std/[random,os,osproc,asyncdispatch,exitprocs]
from globals import nil
import connection,tunnel,server,print

randomize()
globals.init()

if globals.multi_port and not globals.reset_iptable and globals.mode == globals.RunMode.tunnel:
    addExitProc do():
        globals.resetIptables() 
        


when defined(linux) and not defined(android):
    import std/posix
    if not isAdmin():
        echo "Please run as root."
        quit(-1)
    if globals.disable_ufw:
        discard 0 == execShellCmd("sudo ufw disable")
    discard 0 == execShellCmd("sysctl -w fs.file-max=100000")
    var limit = RLimit(rlim_cur:65000,rlim_max:66000)
    assert 0 == setrlimit(RLIMIT_NOFILE,limit)




asyncCheck startController()
if globals.mode == globals.RunMode.tunnel:
    asyncCheck tunnel.start()
else:
    asyncCheck server.start()

runForever()