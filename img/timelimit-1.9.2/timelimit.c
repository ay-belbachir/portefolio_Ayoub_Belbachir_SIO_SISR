/*-
 * Copyright (c) 2001, 2007 - 2010, 2016, 2018, 2021  Peter Pentchev
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include "config.h"

unsigned long	warntime, warnmsec, killtime, killmsec;
unsigned long	warnsig, killsig;
volatile bool	fdone, falarm, fsig;
volatile int	sigcaught;
bool		propagate, quiet;

static struct {
	const char	*name, opt;
	bool		 issig;
	unsigned long	*sec, *msec;
} envopts[] = {
	{"KILLSIG",	'S',	true,	&killsig, NULL},
	{"KILLTIME",	'T',	false,	&killtime, &killmsec},
	{"WARNSIG",	's',	true,	&warnsig, NULL},
	{"WARNTIME",	't',	false,	&warntime, &warnmsec},
	{NULL,		0,	false,	NULL, NULL}
};

static struct {
	const char	*name;
	int		 num;
} signals[] = {
	/* We kind of assume that the POSIX-mandated signals are present */
	{"ABRT",	SIGABRT},
	{"ALRM",	SIGALRM},
	{"BUS",		SIGBUS},
	{"CHLD",	SIGCHLD},
	{"CONT",	SIGCONT},
	{"FPE",		SIGFPE},
	{"HUP",		SIGHUP},
	{"ILL",		SIGILL},
	{"INT",		SIGINT},
	{"KILL",	SIGKILL},
	{"PIPE",	SIGPIPE},
	{"QUIT",	SIGQUIT},
	{"SEGV",	SIGSEGV},
	{"STOP",	SIGSTOP},
	{"TERM",	SIGTERM},
	{"TSTP",	SIGTSTP},
	{"TTIN",	SIGTTIN},
	{"TTOU",	SIGTTOU},
	{"USR1",	SIGUSR1},
	{"USR2",	SIGUSR2},
	{"PROF",	SIGPROF},
	{"SYS",		SIGSYS},
	{"TRAP",	SIGTRAP},
	{"URG",		SIGURG},
	{"VTALRM",	SIGVTALRM},
	{"XCPU",	SIGXCPU},
	{"XFSZ",	SIGXFSZ},

	/* Some more signals found on a Linux 2.6 system */
#ifdef SIGIO
	{"IO",		SIGIO},
#endif
#ifdef SIGIOT
	{"IOT",		SIGIOT},
#endif
#ifdef SIGLOST
	{"LOST",	SIGLOST},
#endif
#ifdef SIGPOLL
	{"POLL",	SIGPOLL},
#endif
#ifdef SIGPWR
	{"PWR",		SIGPWR},
#endif
#ifdef SIGSTKFLT
	{"STKFLT",	SIGSTKFLT},
#endif
#ifdef SIGWINCH
	{"WINCH",	SIGWINCH},
#endif

	/* Some more signals found on a FreeBSD 8.x system */
#ifdef SIGEMT
	{"EMT",		SIGEMT},
#endif
#ifdef SIGINFO
	{"INFO",	SIGINFO},
#endif
#ifdef SIGLWP
	{"LWP",		SIGLWP},
#endif
#ifdef SIGTHR
	{"THR",		SIGTHR},
#endif
};
#define SIGNALS	(sizeof(signals) / sizeof(signals[0]))

#ifndef HAVE_ERR
static void	err(int, const char *, ...);
static void	errx(int, const char *, ...);
#endif /* !HAVE_ERR */

static void	usage(void);

static void	init(int, char * const []);
static pid_t	doit(char * const []);
static void	child(char * const []);
static void	raisesignal(int) __dead2;
static void	setsig_fatal(int, void (*)(int));
static void	setsig_fatal_gen(int, void (*)(int), bool, const char *);
static void	terminated(const char *);

#ifndef HAVE_ERR
static void
err(const int code, const char * const fmt, ...) {
	va_list v;

	va_start(v, fmt);
	vfprintf(stderr, fmt, v);
	va_end(v);

	fprintf(stderr, ": %s\n", strerror(errno));
	exit(code);
}

static void
errx(const int code, const char * const fmt, ...) {
	va_list v;

	va_start(v, fmt);
	vfprintf(stderr, fmt, v);
	va_end(v);

	fprintf(stderr, "\n");
	exit(code);
}

static void
warnx(const char * const fmt, ...) {
	va_list v;

	va_start(v, fmt);
	vfprintf(stderr, fmt, v);
	va_end(v);

	fprintf(stderr, "\n");
}
#endif /* !HAVE_ERR */

static void
usage(void) {
	fputs(
"usage:\ttimelimit [-pq] [-S ksig] [-s wsig] [-T ktime] [-t wtime] command\n"
"\ttimelimit --features\n"
	    , stderr);
	exit(EX_USAGE);
}

static void
atou_fatal(const char * const s, unsigned long * const sec,
		unsigned long * const msec, const bool issig) {
	if (s[0] < '0' || s[0] > '9') {
		if (s[0] == '\0' || !issig)
			usage();
		for (size_t i = 0; i < SIGNALS; i++)
			if (strcmp(signals[i].name, s) == 0)
			{
				*sec = (unsigned long)signals[i].num;
				if (msec != NULL)
					*msec = 0;
				return;
			}
		/* Not a number, not a signal name */
		usage();
	}

	unsigned long v = 0;
	const char *p;
	for (p = s; (*p >= '0') && (*p <= '9'); p++)
		v = v * 10 + *p - '0';
	if (*p == '\0') {
		*sec = v;
		if (msec != NULL)
			*msec = 0;
		return;
	} else if (*p != '.' || msec == NULL) {
		usage();
	}
	p++;

	unsigned long vm = 0;
	unsigned long mul = 1000000;
	for (; (*p >= '0') && (*p <= '9'); p++) {
		vm = vm * 10 + *p - '0';
		mul = mul / 10;
	}
	if (*p != '\0')
		usage();
	else if (mul < 1)
		errx(EX_USAGE, "no more than microsecond precision");
#ifndef HAVE_SETITIMER
	if (msec != 0)
		errx(EX_UNAVAILABLE,
		    "subsecond precision not supported on this platform");
#endif
	*sec = v;
	*msec = vm * mul;
}

static void
init(const int argc, char * const argv[]) {
	/* defaults */
	quiet = false;
	warnsig = SIGTERM;
	killsig = SIGKILL;
	warntime = 3600;
	warnmsec = 0;
	killtime = 120;
	killmsec = 0;

	bool optset = false;
	
	/* process environment variables first */
	for (size_t i = 0; envopts[i].name != NULL; i++) {
		const char * const s = getenv(envopts[i].name);
		if (s != NULL) {
			atou_fatal(s, envopts[i].sec, envopts[i].msec,
			    envopts[i].issig);
			optset = true;
		}
	}

	bool listfeatures = false, listsigs = false;
	int ch;
	while ((ch = getopt(argc, argv, "+lqpS:s:T:t:-:")) != -1) {
		switch (ch) {
			case 'l':
				listsigs = true;
				break;
			case 'p':
				propagate = true;
				break;
			case 'q':
				quiet = true;
				break;
			case '-':
				if (strcmp(optarg, "features") == 0)
					listfeatures = true;
				else
					usage();
				break;
			default:
				{
				/* check if it's a recognized option */
				bool found = false;
				for (size_t i = 0; envopts[i].name != NULL; i++)
					if (ch == envopts[i].opt) {
						atou_fatal(optarg,
						    envopts[i].sec,
						    envopts[i].msec,
						    envopts[i].issig);
						optset = true;
						found = true;
						break;
					}
				if (!found)
					usage();
				}
				break;
		}
	}

	if (listfeatures) {
		puts("Features: timelimit=1.9.2"
#ifdef HAVE_SETITIMER
		    " subsecond=1.0"
#endif
		);
		exit(EX_OK);
	}
	if (listsigs) {
		for (size_t i = 0; i < SIGNALS; i++)
			printf("%s%c", signals[i].name,
			    i + 1 < SIGNALS? ' ': '\n');
		exit(EX_OK);
	}

	if (!optset) /* && !quiet? */
		warnx("using defaults: warntime=%lu, warnsig=%lu, "
		    "killtime=%lu, killsig=%lu",
		    warntime, warnsig, killtime, killsig);

	if (argc == optind)
		usage();

	/* sanity checks */
	if ((warntime == 0 && warnmsec == 0) || (killtime == 0 && killmsec == 0))
		usage();
}

static void
sigchld(const int sig __unused) {

	fdone = true;
}

static void
sigalrm(const int sig __unused) {

	falarm = true;
}

static void
sighandler(const int sig) {

	sigcaught = sig;
	fsig = true;
}

static void
setsig_fatal(const int sig, void (* const handler)(int)) {
	
	setsig_fatal_gen(sig, handler, true, "setting");
}

static void
setsig_fatal_gen(const int sig, void (* const handler)(int), const bool nocld,
		const char * const what) {
#ifdef HAVE_SIGACTION
	struct sigaction act;

	memset(&act, 0, sizeof(act));
	act.sa_handler = handler;
	act.sa_flags = 0;
#ifdef SA_NOCLDSTOP
	if (nocld)
		act.sa_flags |= SA_NOCLDSTOP;
#endif /* SA_NOCLDSTOP */
	if (sigaction(sig, &act, NULL) < 0 &&
	    !(errno == EINVAL && (sig == SIGKILL || sig == SIGSTOP)))
		err(EX_OSERR, "%s signal handler for %d", what, sig);
#else  /* HAVE_SIGACTION */
	(void)nocld;
	if (signal(sig, handler) == SIG_ERR &&
	    !(errno == EINVAL && (sig == SIGKILL || sig == SIGSTOP)))
		err(EX_OSERR, "%s signal handler for %d", what, sig);
#endif /* HAVE_SIGACTION */
}

static void
settimer(const char *name, unsigned long sec, unsigned long msec)
{
#ifdef HAVE_SETITIMER
	struct itimerval tval;

	tval.it_interval.tv_sec = tval.it_interval.tv_usec = 0;
	tval.it_value.tv_sec = sec;
	tval.it_value.tv_usec = msec;
	if (setitimer(ITIMER_REAL, &tval, NULL) == -1)
		err(EX_OSERR, "could not set the %s timer", name);
#else
	(void)name;
	(void)msec;
	alarm(sec);
#endif
}
    
static pid_t
doit(char * const argv[]) {
	/* install signal handlers */
	fdone = falarm = fsig = false;
	sigcaught = 0;
	setsig_fatal(SIGALRM, sigalrm);
	setsig_fatal(SIGCHLD, sigchld);
	setsig_fatal(SIGTERM, sighandler);
	setsig_fatal(SIGHUP, sighandler);
	setsig_fatal(SIGINT, sighandler);
	setsig_fatal(SIGQUIT, sighandler);

	/* fork off the child process */
	const pid_t pid = fork();
	if (pid < 0)
		err(EX_OSERR, "fork");
	else if (pid == 0)
		child(argv);

	/* sleep for the allowed time */
	settimer("warning", warntime, warnmsec);
	while (!(fdone || falarm || fsig))
		pause();
	alarm(0);

	/* send the warning signal */
	if (fdone)
		return (pid);
	if (fsig)
		terminated("run");
	falarm = false;
	if (!quiet)
		warnx("sending warning signal %lu", warnsig);
	kill(pid, (int) warnsig);

#ifndef HAVE_SIGACTION
	/* reset our signal handlers, just in case */
	setsig_fatal(SIGALRM, sigalrm);
	setsig_fatal(SIGCHLD, sigchld);
	setsig_fatal(SIGTERM, sighandler);
	setsig_fatal(SIGHUP, sighandler);
	setsig_fatal(SIGINT, sighandler);
	setsig_fatal(SIGQUIT, sighandler);
#endif /* HAVE_SIGACTION */

	/* sleep for the grace time */
	settimer("kill", killtime, killmsec);
	while (!(fdone || falarm || fsig))
		pause();
	alarm(0);

	/* send the kill signal */
	if (fdone)
		return (pid);
	if (fsig)
		terminated("grace");
	if (!quiet)
		warnx("sending kill signal %lu", killsig);
	kill(pid, (int) killsig);
	setsig_fatal_gen(SIGCHLD, SIG_DFL, false, "restoring");
	return (pid);
}

static void
terminated(const char * const period) {

	errx(EX_SOFTWARE, "terminated by signal %d during the %s period",
	    sigcaught, period);
}

static void
child(char * const argv[]) {
	execvp(argv[0], argv);
	err(EX_OSERR, "executing %s", argv[0]);
}

static __dead2 void
raisesignal (const int sig) {

	setsig_fatal_gen(sig, SIG_DFL, false, "restoring");
	raise(sig);
	while (1)
		pause();
	/* NOTREACHED */
}

int
main(const int argc, char * const argv[]) {
	init(argc, argv);
	const pid_t pid = doit(argv + optind);

	int status;
	if (waitpid(pid, &status, 0) == -1)
		err(EX_OSERR, "could not get the exit status for process %ld",
		    (long)pid);
	if (WIFEXITED(status))
		return (WEXITSTATUS(status));
	else if (!WIFSIGNALED(status))
		return (EX_OSERR);
	if (propagate)
		raisesignal(WTERMSIG(status));
	else
		return (WTERMSIG(status) + 128);
}
