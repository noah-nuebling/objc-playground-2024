//
//  CoolMacros.h
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 30.07.24.
//

#ifndef CoolMacros_h
#define CoolMacros_h

#pragma mark - Macro Magic (unused) (but cool)

///
/// Do numbered macros
///

/// Explanation:
///
///     `doNumberedMacro(myMacro)` will resolve to
///         `myMacro_0()`
///
///     `doNumberedMacro(myMacro, a)` will resolve to
///         `myMacro_1(a)`
///
///     `doNumberedMacro(myMacro, a, b)` will resolve to
///         `myMacro_2(a, b)`
///
///     `doNumberedMacro(myMacro, a, b, c)` will resolve to
///         `myMacro_3(a, b, c)`
///
///      And so on (up to `myMacro_9`)
///

#define doNumberedMacro(__macroPrefix, __args...) \
    __macroPrefix ## macroPostfix(__args) (__args)

#define macroPostfix(__args...) \
    getTenth(__args, ## _9, _8, _7, _6, _5, _4, _3, _2, _1, _0)

#define getTenth(__1, __2, __3,__4, __5, __6, __7, __8, __9, __10, __rest...) \
    __10
    
///
/// forEach macro
///

/// Explanation:
///
///     `forEach(myMacro, a)` will resolve to
///         `myMacro(a)
///
///     `forEach(myMacro, a, b)` will resolve to
///         `myMacro(a) myMacro(b)
///
///     `forEach(myMacro, a, b, c)` will resolve to
///         `myMacro(a) myMacro(b) myMacro(c)
///
///      And so on (up to 8 "iterations", or (a, b, c, d, e, f, g, h))
///

#define forEach(__macro, __list...) \
    doNumberedMacro(_forEach, __macro, __list)

#define _forEach_0() \
    /// Do Nothing

#define _forEach_1(__macro) \
    /// Do Nothing

#define _forEach_2(__macro, __1) \
    __macro(__1)

#define _forEach_3(__macro, __1, __2) \
    __macro(__1) __macro(__2)

#define _forEach_4(__macro, __1, __2, __3) \
    __macro(__1) __macro(__2) __macro(__3)

#define _forEach_5(__macro, __1, __2, __3, __4) \
    __macro(__1) __macro(__2) __macro(__3) __macro(__4)

#define _forEach_6(__macro, __1, __2, __3, __4, __5) \
    __macro(__1) __macro(__2) __macro(__3) __macro(__4) __macro(__5)

#define _forEach_7(__macro, __1, __2, __3, __4, __5, __6) \
    __macro(__1) __macro(__2) __macro(__3) __macro(__4) __macro(__5) __macro(__6)

#define _forEach_8(__macro, __1, __2, __3, __4, __5, __6, __7) \
    __macro(__1) __macro(__2) __macro(__3) __macro(__4) __macro(__5) __macro(__6) __macro(__7)

#define _forEach_9(__macro, __1, __2, __3, __4, __5, __6, __7, __8) \
    __macro(__1) __macro(__2) __macro(__3) __macro(__4) __macro(__5) __macro(__6) __macro(__7) __macro(__8)


#endif /* CoolMacros_h */
