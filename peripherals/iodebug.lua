-- generate new iodebug peripheral.
-- on iocall, this just dumps registers etc.,
-- and optionally halts execution.
function new_iodebug(computer, halt)
  local iodebug = {}
  function iodebug:io_call(computer)
    print("Got IOCALL")
    computer:dump()
    if halt then
      computer.running = false
    end
  end
  return iodebug
end