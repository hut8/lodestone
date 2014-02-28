#!/bin/bash
unistd=/usr/include/asm/unistd.h
date=`date`

cat <<EOF
;;;; -*- Mode: asm; asm-indent-level: 2; -*-
;;;; $date
;;;; Linux System call interrupt numbers

%ifndef SYSCALL_MAC
%define SYSCALL_MAC

EOF

# The second `y' is a y/tab/space/.
cat $unistd | \
    sed -n '/^#define __NR/ {
             y/#/%/
             y/ / /
             s/__NR//g
             s/\/\\*.*\\*\///
             p
         }' | \
      awk '{ printf ("%s %-26s %3d\n", $1,$2,$3) }'

cat <<'EOF'

%imacro syscall 0-6 nil
  %ifidn %1, nil
    %error "syscall needs at least one parameter"
  %elifid %1
    %error "Undefined system call `%1'"
  %else
    mov    eax, dword %1
    %if %0 > 1
      mov    ebx, %2
      %if %0 > 2
        mov    ecx, %3
        %if %0 > 3
          mov    edx, %4
          %if %0 > 4
            mov    esi, %5
            %if %0 > 5
              mov    edi, %6
            %endif
          %endif
        %endif
      %endif
    %endif
    int   0x80
  %endif
%endmacro

%endif    ; SYSCALL_MAC

EOF
