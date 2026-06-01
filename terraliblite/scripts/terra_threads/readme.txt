These are utility scripts meant to run on a second thread.
If you want to use more than one of them, I recommend adding them all to the same thread like so:

    utilThread = threads.create({
        name="thing",
        scripts={
            timer={"/scripts/terra_threads/timer.lua"},
            other={"/scripts/terra_threads/ohwaitIveyettomakeanythingotherthantimer.lua"},
        },
        tickRate=240,
        instructionLimit=1000000000,
    })
