//
//  CoolMacros.h
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 30.07.24.
//

#ifndef CoolMacros_h
#define CoolMacros_h

///
/// Strongify / weakify macros
///

/// We thought about including EXTScope.h but I really just want @weakify and @strongify.
///     Update: [Apr 2025] Still better to just use EXTScope.h - it's the standard. 

#define weakify(__var) \
    REQUIRE_AT_PREFIX \
    __weak typeof(__var) m_weakified_ ## __var = __var;

#define strongify(__var) \
    REQUIRE_AT_PREFIX \
    typeof(__var) __var = m_weakified_ ##  __var;

///
/// Keywordify
///     When you add this to the start of a macro, it requires an @ prefix to be invoked

#define REQUIRE_AT_PREFIX \
    try {} @catch (...) {}


///
/// vvv Weird stuff, doesn't work
///

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

#define concat(__a, __b) \
__a ## __b

#define macroPostfix(__args...) \
    getTenth(__args, ## 9, 8, 7, 6, 5, 4, 3, 2, 1, 0)

#define doNumberedMacro(__macroPrefix, __args...) \
    concat(__macroPrefix, macroPostfix(__args) (__args))

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

#define _forEach0(...) \
    /// Do Nothing

#define _forEach1(__macro, ...) \
    /// Do Nothing

#define _forEach2(__macro, __1, ...) \
    __macro(__1)

#define _forEach3(__macro, __1, __2, ...) \
    __macro(__1) __macro(__2)

#define _forEach4(__macro, __1, __2, __3, ...) \
    __macro(__1) __macro(__2) __macro(__3)

#define _forEach5(__macro, __1, __2, __3, __4, ...) \
    __macro(__1) __macro(__2) __macro(__3) __macro(__4)

#define _forEach6(__macro, __1, __2, __3, __4, __5, ...) \
    __macro(__1) __macro(__2) __macro(__3) __macro(__4) __macro(__5)

#define _forEach7(__macro, __1, __2, __3, __4, __5, __6, ...) \
    __macro(__1) __macro(__2) __macro(__3) __macro(__4) __macro(__5) __macro(__6)

#define _forEach8(__macro, __1, __2, __3, __4, __5, __6, __7, ...) \
    __macro(__1) __macro(__2) __macro(__3) __macro(__4) __macro(__5) __macro(__6) __macro(__7)

#define _forEach9(__macro, __1, __2, __3, __4, __5, __6, __7, __8, ...) \
    __macro(__1) __macro(__2) __macro(__3) __macro(__4) __macro(__5) __macro(__6) __macro(__7) __macro(__8)


#endif /* CoolMacros_h */
