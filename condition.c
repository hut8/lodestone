#include "condition.h"

static void trigger_condition(int signum) { /* nop */ }

inline void install_signal_handler() {
  struct sigaction sa;
  sa.sa_handler = trigger_condition;
  sigemptyset(&sa.sa_mask);
  if (sigaction(SIGWINCH, &sa, NULL) < 0) {
    fprintf(stderr, "could not install signal handler\n");
    _exit(-1);
  }
}

inline void uninstall_signal_handler() {
  struct sigaction sa;
  sa.sa_handler = SIG_DFL;
  sigemptyset(&sa.sa_mask);
  if (sigaction(SIGWINCH, &sa, NULL) < 0) {
    fprintf(stderr, "could not uninstall signal handler\n");
    _exit(-1);
  }
}

void condition_broadcast(char * filename) {
  /* be able to notify 1024 processes */
  int process_queue[1024];
  /* queue position index */
  int queue_i = 0, kill_i = 0;
  /* procfs directory pointer */
  DIR *dirp;
  /* directory entry pointer */
  struct dirent *dp;
  /* find out if entries are directories */
  struct stat statbuf;
  /* file pointer for scanf of /proc/pid/stat/ */
  FILE *stat_fp;
  /* filename of thing we're examining */
  char exam_filename[PATH_MAX];
  char target_fn[PATH_MAX];
  /* pid */
  int target_pid;
  /* adjust filename */
  if (strrchr(filename, (int)'/') != NULL) {
    filename = strrchr(filename,(int)'/')+sizeof(char);
  }

  /* open procfs */
  if ((dirp = opendir("/proc/")) == NULL) {
    /* write to apache error log */
    fprintf(stderr, "could not open procfs\n");
    _exit(-1);
  }
  /* loop through directory entries */
  errno = 0;
  while ((dp = readdir(dirp)) != NULL) {
    /* if the entry is not numeric, skip it */
    if (atoi(dp->d_name) == 0 || atoi(dp->d_name) == getpid()) {
      continue;
    }
    /* stat this */
    sprintf(target_fn, "/proc/%s", dp->d_name);
    if (stat(target_fn, &statbuf) == -1) {
      fprintf(stderr, "error while trying to stat %s", dp->d_name);
      _exit(-1);
    }
    /* if this is a directory */
    if (S_ISDIR(statbuf.st_mode)) {
      /* extrat this PID and exe filename */
      sprintf(target_fn, "/proc/%s/stat", dp->d_name);
      if ((stat_fp = fopen(target_fn, "r")) == NULL) {
	fprintf(stderr, "could not open %s", target_fn);
	exit(-1);
      }
      fscanf(stat_fp, "%d ", &target_pid);
      fscanf(stat_fp, "(%s)", (char*)&exam_filename);
      exam_filename[strlen(exam_filename)-1] = 0;
      /* check to see if it is one of us */
      if (strcmp(exam_filename, filename) == 0) {
	/* enqueue it */
	fprintf(stderr, "found sibling %d\n", target_pid);
	process_queue[queue_i++] = target_pid;
      }
      fclose(stat_fp);
    }
  }
  closedir(dirp);
  /* KILLING SPREE */
  for (kill_i = 0; kill_i < queue_i; kill_i++) {
    kill(process_queue[kill_i], SIGWINCH);
  }
}

void condition_wait() {
  install_signal_handler();
  pause();
  uninstall_signal_handler();
}
