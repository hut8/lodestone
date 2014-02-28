# Lodestone
Liam Bowen - LiamBowen@gmail.com

## Description:
An unnecessary platform for enabling collaborative virtual refrigerator magnet placement.  Crashes IE 7 and probably others. Why are you still reading this?

### Is this a joke?
_Yes, basically_. I wanted to learn x86 assembly. This is obviously useless otherwise.

### Why does this crash Internet Explorer 7?
Why are you using Internet Explorer?

### Building / Requirements
A Makefile is provided which should work fine with Make.  NASM is required to compile "lodestone.s" which contains
most of the source code.  The application works with Apache and should work with any CGI webserver.

To build on Ubuntu/Debian, you'll need:

```bash
sudo apt-get install nasm libc6-dev-i386
```

### Portability:
_TL;DR_: About as portable as a real refrigerator.
The IPC mechanism (absurd, signal based kludge) should work fine with any Linux system.  It would need to be modified for procfs on FreeBSD.
"syscall" macros are provided for NASM which work both in FreeBSD (stack) and Linux (registers) even though they use
totally different syscall conventions.  It will definitely not work on a non-x86 system :-P
