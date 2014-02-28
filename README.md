# Lodestone
Liam Bowen - LiamBowen@gmail.com

## Description:
An unnecessary platform for enabling collaborative virtual refrigerator magnet placement.  Crashes IE 7 and probably others. Why are you still reading this?

### Is this a joke?
_Yes, basically_. Originally I wrote this for a class at [RPI|http://cs.rpi.edu]. The assignment was something I already knew how to do so I decided to write this in a needlessly complicated way to learn a new language (x86 assembly).

### Why does this crash Internet Explorer 7?
Why are you using Internet Explorer?

### Building / Requirements
A Makefile is provided which should work fine with Make.  NASM is required to compile "lodestone.s" which contains
most of the source code.  The application works with Apache and should work with any CGI webserver.

### Portability:
_TL;DR_: About as portable as a real refrigerator.
The IPC mechanism (absurd, signal based kludge) should work fine with any Linux system.  It would need to be modified for procfs on FreeBSD.
"syscall" macros are provided for NASM which work both in FreeBSD (stack) and Linux (registers) even though they use
totally different syscall conventions.  It will definitely not work on a non-x86 system :-P
