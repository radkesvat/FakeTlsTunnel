
import overrides/[asyncnet]
import times,random
import strformat, tables, json, strutils, sequtils, hashes
import  asyncdispatch, os, strutils, parseutils, deques, options
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