#  objc tests

This project is a playground for testing objc stuff. 

History: (Written way after creating this – in [Apr 2025]) 
    This was the origin of MFDataClass, our custom cmark-based Markdown Parser, *and* MFObserver (formerly BlockObserver)
    So all this horrible 'writing our own APIs' stuff which we wasted sooo much time on came from here! 
    
    I came back to this in [Apr 2025] after merging mac-mouse-fix's master branch into feature-strings-catalog branch
        and then wanting to merge all the valuable work from 2024 sideprojects (such as this one) into feature-strings-catalog, 
        so we can then forget about those side-projects.
    
    When I came back to this in [Apr 2025]:
        - MFDataClass and the Markdown Parser had already been moved to MMF, 
            but the BlockObserver (renamed to MFObserver) still lived here. 
            IIRC, the reason we didn't move it into MMF before is that: 
                - It's sorta tricky code, it wasn't tested, if we do adopt it and it's not rock-solid that would be really bad
                - we weren't sure it provided any meaningful benefit over ReactiveSwift  
                    (which MMF is using but which we kinda wanted to get rid of in Summer 2024) or Combine (which is another alternative)
            After coming back to the code, we cleaned it up, thought it through again, and tested the edge-cases we weren't sure about (See mfobserver_cleanup_tests()) 
                -> After all that, I'm now confident that MFObserver is production-ready and could be safely used in MMF. (Or even other projects.)
                    So we're now merging the code into MMF. 
                    (I'm still not sure this has any meaningful benefit over ReactiveSwift, but sunk-cost-fallacy and all that. I guess it's nice we can easily write Reactive Stuff in objc with this.)
        - The other interesting thing we did was: Figure out how to get compiler warnings for nullability mistakes. 
            - This is documented in `Xcode Nullability Settings.md` 
            - We used the nullability warnings to work on MFObserver.m
            - We also plan to enable those nullability warnings inside mac-mouse-fix repo.
    -> All the other stuff in the repo (MFLinkedList and so on) isn't interesting
        -> We can safely forget about this repo now and never look at it again!
