#ifndef NOTIFY_H_
#define NOTIFY_H_


#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <signal.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

/* Notify everyone waiting */
void condition_notify();

/* Block until notified
   (wait for changes to objdb) */
void condition_wait();

#endif
