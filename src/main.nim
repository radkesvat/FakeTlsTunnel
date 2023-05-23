
import overrides/[asyncnet]
import times,random
import strformat, tables, json, strutils, sequtils, hashes
import net, asyncdispatch, os, strutils, parseutils, deques, options, net
from globals import nil
import keys,print,tunnel
import tunnel,server


randomize()
globals.init()



if globals.mode == globals.RunMode.tunnel:
    asyncCheck tunnel.start()
else:
    asyncCheck server.start()

runForever()