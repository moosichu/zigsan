# zigsan
A reimplementation of the compiler-rt clang sanitization libraries in the zig programming language.

The goal is to implement some of (maybe all)? of the clang compiler-rt sanitisation libraries: https://compiler-rt.llvm.org/

Related issues:
- https://github.com/ziglang/zig/issues/11403
- https://github.com/ziglang/zig/issues/5163
- https://github.com/ziglang/zig/issues/10374

# ubsan

The first goal (because it is the simplest) is to get all the ubsan hooks working in a way that integrates to the zig runtime.

## What is ubsan?

Ubsan (undefined behaviour sanitizer) is a feature supported by clang for catching instances of undefined behaviour being introduced into C/C++ programs. It essentially works by inserting runtime checks for instances undefined behaviour in places where it could. (eg. every signed-integer arithmetic occurs, it adds a check that the result won't overflow).

In cases where those checks fail, depending on which ubsan configuration you compiled your program with, one of three things can happen:
 - The program simply traps, so you now that an ubsan error occured but with no further info (this is what zig currently does by default).
 - The program reports a simple error message (with limited information about what went wrong).
 - The program reports a more fully-featured error message with a full description of what went wrong and why.

 ## Goal

 The goal here is to provide a runtime library (that the zig compiler can link into programs when ubsan is enabled) for reporting undefined behaviour errors when they occurs. Specifically, the goal is to do so in a way that is consistent with how undefined behaviour errors are reported by debug zig builds. i.e. if you were to have an illegal integer overflow in zig *or* C/C++ you get a consistent experience.

 The goal *is not* to just do what the clang ubsan runtime already does in terms of error reporting.

## Progress

The best way to view the progress of the ubsan inplementation is to look at [src/testing/ubsan_tests.h](src/testing/ubsan_tests.h) 

These give examples of various undefined behaviours that we can catch and appropriately report errors for. Currently waiting on https://github.com/ziglang/zig/pull/15991 to be merged as that will help with writing tests a fair bit.
