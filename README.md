# zigsan
A reimplementation of the compiler-rt clang sanitization libraries in the zig programming language.

This is currently in the very early stages of development! Nothing to see here (yet)!

The goal is to implement some of (maybe all)? of the clang compiler-rt sanitisation libraries: https://compiler-rt.llvm.org/

The first goal is to reimplement the runtime ubsan functionality in a way that can be integrated with the zig compiler that has ubsan enabled by default, but doesn't currently report user-friendly errors. This is in NO WAY AT ALL ready to be used.
