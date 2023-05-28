
import std/[random,os,asyncdispatch]
from globals import nil
import tunnel,server


when defined(linux):
    if not isAdmin():
        echo "Please run as root."
        quit(-1)
    assert 0 == execShellCmd("sudo ufw disable")
    assert 0 == execShellCmd("sysctl -w fs.file-max=100000")

randomize()
globals.init()


if globals.mode == globals.RunMode.tunnel:
    asyncCheck tunnel.start()
else:
    asyncCheck server.start()

runForever()