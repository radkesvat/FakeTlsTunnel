from globals import nil
import math,bitops,random

const hsize = 8

proc encrypt(data:var string) =
    for i in 0..<data.len():
        data[i] = chr(rotateRightBits(uint8(data[i]), 4))

proc decrypt(data:var string) =
    for i in 0..<data.len():
        data[i] = chr(rotateLeftBits(uint8(data[i]), 4))

proc muxPack(cid: uint32,data: string): string =
    var datalen = len(data)


    # echo "ceil: ", ceil(datalen/globals.mux_segment_size)
    var total_segments  = max(1.uint32,ceil(datalen/globals.mux_segment_size).uint32)

    result = newString(len= total_segments * globals.mux_segment_size)

    for si in 0..<total_segments:
        let remaining_bytes = datalen.uint32 - (si*globals.mux_segment_size)

        let index = si * globals.mux_segment_size
        var totake:uint32 = min(remaining_bytes, globals.mux_segment_size-hsize)


        copyMem(unsafeAddr result[index], unsafeAddr cid, 4)
        copyMem(unsafeAddr result[index+4], unsafeAddr totake, 4)
        if data.len != 0:
            copyMem(unsafeAddr result[index+8], unsafeAddr data[si*(globals.mux_segment_size-hsize)], totake)

        # let diff = (globals.mux_segment_size-hsize) - totake 
        # if diff > 0 : 
        #     copyMem(unsafeAddr result[index+totake], unsafeAddr(globals.random_600[rand(250)]), diff)

   


    
proc prepairTrustedSend*(cid: uint32, data: var string) = 
    if globals.mux:
        var muxres = muxPack(cid,data)
        encrypt muxres
        data = muxres
    else:
        quit(-1)
        encrypt data

proc prepairUnTrustedSend(data: var string) = discard




iterator muxRead*(data:var string):  tuple[cid:uint32,data:string] =
    decrypt data
    var datalen = len(data)
    
    assert datalen mod  globals.mux_segment_size == 0

    var index = 0
    var buffer = ""

    var last_cid:uint32 = 0
    while index < datalen:
        var cid:uint32
        var dlen:uint32
        copyMem(unsafeAddr cid, unsafeAddr data[index], 4)
        copyMem(unsafeAddr dlen, unsafeAddr data[index+4], 4)

        if last_cid == 0:
            last_cid = cid
        elif last_cid != cid:            
            yield  (last_cid,buffer)
            last_cid = cid
            buffer = ""

        var extracted_data: string = newString((globals.mux_segment_size)-hsize)

        copyMem(unsafeAddr extracted_data[0], unsafeAddr data[index+8], dlen)
        extracted_data.setLen(dlen)

        index = index +  globals.mux_segment_size
        buffer.add extracted_data
        
    yield  (last_cid,buffer)


proc normalRead*(data:var string) = 
    decrypt data


proc prepairUnTrustedRecv(data:string) = discard

 


