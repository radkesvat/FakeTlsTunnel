import nimAES
import byteutils
import std/strutils
import zippy
import macros, hashes

var aes{.global.} = initAES()

type
  # Use a distinct string type so we won't recurse forever
  estring = distinct string

# Use a "strange" name KEKW
proc gkkaekgaEE*(s: estring, key: int): string {.noinline.} =
  # We need {.noinline.} here because otherwise C compiler
  # aggresively inlines this procedure for EACH string which results
  # in more assembly instructions
  var k = key
  result = string(s)
  for i in 0 ..< result.len:
    for f in [0, 8, 16, 24]:
      result[i] = chr(uint8(result[i]) xor uint8((k shr f) and 0xFF))
    k = k +% 1

var encodedCounter {.compileTime.} = hash(CompileTime & CompileDate) and 0x7FFFFFFF


macro `?->`*(s: string): untyped =
  var encodedStr = gkkaekgaEE(estring($s), encodedCounter)

  template genStuff(str, counter: untyped): untyped = 
    {.noRewrite.}:
      gkkaekgaEE(estring(`str`), `counter`)
  
  result = getAst(genStuff(encodedStr, encodedCounter))
  encodedCounter = (encodedCounter *% 16777619) and 0x7FFFFFFF


