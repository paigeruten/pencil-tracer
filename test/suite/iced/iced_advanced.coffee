if require?
  iced = icedlib = require 'iced-runtime'

##----------------------------------------------------------------------

  atest "rendezvous & windowing example", (cb) ->

    slots = []
    call = (i, cb) ->
      slots[i] = 1
      await setTimeout(defer(), 10*Math.random())
      slots[i] |= 2
      cb()

    window = (n, window, cb) ->
      rv = new iced.Rendezvous
      nsent = 0
      nrecv = 0
      while nrecv < n
        if nsent - nrecv < window and nsent < n
          call nsent, rv.id(nsent).defer()
          nsent++
        else
          await rv.wait defer(res)
          slots[res] |= 4
          nrecv++
      cb()

    await window 10, 3, defer()
    res = true
    for s in slots
      res = false unless s == 7
    cb(res, {})

##----------------------------------------------------------------------

  atest "pipeliner example", (cb) ->

    slots = []
    call = (i, cb) ->
      slots[i] = 1
      await setTimeout(defer(), 3*Math.random())
      slots[i] |= 2
      cb(4)

    window = (n, window, cb) ->
      tmp = {}
      p = new icedlib.Pipeliner window, .01
      for i in [0..n]
        await p.waitInQueue defer()
        call i, p.defer tmp[i]
      await p.flush defer()
      for k,v of tmp
        slots[k] |= tmp[k]
      cb()

    await window 100, 10, defer()

    ok = true
    for s in slots
      ok = false unless s == 7
    cb(ok, {})

##----------------------------------------------------------------------

  atest "stack protector", (cb) ->
    noop = (cb) -> cb()
    for i in [0..10000]
      await noop defer()
    cb(true, {})

##----------------------------------------------------------------------

  atest "iand and ior", (cb) ->
    boolfun = (res, cb) ->
      await setTimeout defer(), 10*Math.random()
      cb res
    out = [ true ]
    ok = true
    await
      boolfun true, icedlib.iand defer(), out
      boolfun true, icedlib.iand defer(), out
      boolfun true, icedlib.iand defer(), out
    ok = false unless out[0]
    await
      boolfun true,  icedlib.iand defer(), out
      boolfun true,  icedlib.iand defer(), out
      boolfun false, icedlib.iand defer(), out
    ok = false if out[0]
    out[0] = false
    await
      boolfun true,  icedlib.ior defer(), out
      boolfun true,  icedlib.ior defer(), out
      boolfun false, icedlib.ior defer(), out
    ok = false unless out[0]
    out[0] = false
    await
      boolfun false, icedlib.ior defer(), out
      boolfun false, icedlib.ior defer(), out
      boolfun false, icedlib.ior defer(), out
    ok = false if out[0]
    cb(ok, {})
    

##----------------------------------------------------------------------

  atest "stack walk", (cb) ->
    check = false
    
    f2 = (cb) ->
      await setTimeout defer(), 10*Math.random()
      stk = iced.stackWalk()
      if stk.length is 4 and
          stk[0].search /at f1 \(test\/iced_advanced.coffee:112\)/ and
          stk[1].search /at f2 \(test\/iced_advanced.coffee:120\)/ and
          stk[2].search /at foo \(test\/iced_advanced.coffee:124\)/ and
          stk[3].search /at <anonymous> \(test\/iced_advanced.coffee:127\)/
        check = true
      cb()

    f1 = (cb) ->
      await f2 defer()
      cb()

    foo = (cb) ->
      await f1 defer()
      cb()

    await foo defer()
    cb(check, {})
      

##----------------------------------------------------------------------

  atest "multi", (cb) ->
    
    fun = (c) ->
      await setTimeout defer(), 10
      c()
      await setTimeout defer(), 10
      c()
      
    rv = new iced.Rendezvous
    c = rv.id(1,true).defer()
    fun(c)
    await rv.wait defer()
    await rv.wait defer()
    cb(true, {})
    
    
  
