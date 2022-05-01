# Copyright (c) 2001, 2007, 2010, 2011, 2016 - 2018  Peter Pentchev
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

CC?=		gcc
CFLAGS_STD?=	-std=c99
CFLAGS?=		-O -pipe
CFLAGS+=	${CFLAGS_STD}
CPPFLAGS_STD?=	-D_POSIX_C_SOURCE=200809L -D_XOPEN_SOURCE=700
CPPFLAGS+=	${CPPFLAGS_STD}
LDFLAGS?=
LFLAGS?=	${LDFLAGS}
LIBS?=

RM=		rm -f
MKDIR?=		mkdir -p
CAT?=		cat

PROG=		timelimit
OBJS=		timelimit.o
SRCS=		timelimit.c

MAN1=		timelimit.1
MAN1GZ=		${MAN1}.gz

LOCALBASE?=	/usr/local
PREFIX?=	${LOCALBASE}
BINDIR?=	${PREFIX}/bin
MANDIR?=	${PREFIX}/man/man
DOCSDIR?=	${PREFIX}/share/doc/timelimit
EXAMPLESDIR?=	${DOCSDIR}/examples

BINOWN?=	root
BINGRP?=	wheel
BINMODE?=	555

SHAREOWN?=	root
SHAREGRP?=	wheel
SHAREMODE?=	644

# development/debugging flags, you may safely ignore them
#CFLAGS+=	${BDECFLAGS}
#CFLAGS+=	-ggdb -g3

INSTALL?=	install
COPY?=		-c
STRIP?=		-s

INSTALL_PROGRAM?=	${INSTALL} ${COPY} ${STRIP} -o ${BINOWN} -g ${BINGRP} -m ${BINMODE}
INSTALL_DATA?=		${INSTALL} ${COPY} -o ${SHAREOWN} -g ${SHAREGRP} -m ${SHAREMODE}

all:		${PROG} ${MAN1GZ}

clean:
		${RM} ${PROG} ${OBJS} ${MAN1GZ} autoconfig.h

${PROG}:	${OBJS}
		${CC} ${LFLAGS} -o ${PROG} ${OBJS}

autoconfig.h:	autoconfig/try-err.c autoconfig/try-errno.c \
		autoconfig/try-setitimer.c autoconfig/try-sigaction.c \
		autoconfig/try-sysexits.c \
		Makefile
		: > autoconfig.h
		if ${CC} ${CPPFLAGS} ${CFLAGS} ${LFLAGS} -o try-err autoconfig/try-err.c; then \
			echo '#define HAVE_ERR' >> autoconfig.h; \
		else \
			echo '#undef HAVE_ERR' >> autoconfig.h; \
		fi
		test -f try-err && ${RM} try-err
		if ${CC} ${CPPFLAGS} ${CFLAGS} ${LFLAGS} -o try-errno autoconfig/try-errno.c; then \
			echo '#define HAVE_ERRNO_H' >> autoconfig.h; \
		else \
			echo '#undef HAVE_ERRNO_H' >> autoconfig.h; \
		fi
		test -f try-errno && ${RM} try-errno
		if ${CC} ${CPPFLAGS} ${CFLAGS} ${LFLAGS} -o try-sigaction autoconfig/try-sigaction.c; then \
			echo '#define HAVE_SIGACTION' >> autoconfig.h; \
		else \
			echo '#undef HAVE_SIGACTION' >> autoconfig.h; \
		fi
		test -f try-sigaction && ${RM} try-sigaction
		if ${CC} ${CPPFLAGS} ${CFLAGS} ${LFLAGS} -o try-setitimer autoconfig/try-setitimer.c; then \
			echo '#define HAVE_SETITIMER' >> autoconfig.h; \
		else \
			echo '#undef HAVE_SETITIMER' >> autoconfig.h; \
		fi
		test -f try-setitimer && ${RM} try-setitimer
		if ${CC} ${CPPFLAGS} ${CFLAGS} ${LFLAGS} -o try-sysexits autoconfig/try-sysexits.c; then \
			echo '#define HAVE_SYSEXITS_H' >> autoconfig.h; \
		else \
			echo '#undef HAVE_SYSEXITS_H' >> autoconfig.h; \
		fi
		test -f try-sysexits && ${RM} try-sysexits
		${CAT} autoconfig.h

timelimit.o:	timelimit.c config.h autoconfig.h
		${CC} ${CPPFLAGS} ${CFLAGS} -c timelimit.c

${MAN1GZ}:	${MAN1}
		gzip -c9 ${MAN1} > ${MAN1GZ}.tmp
		mv ${MAN1GZ}.tmp ${MAN1GZ}

install:	all
		-${MKDIR} ${DESTDIR}${BINDIR}
		-${MKDIR} ${DESTDIR}${MANDIR}1
		-${MKDIR} ${DESTDIR}${EXAMPLESDIR}/tests
		${INSTALL_PROGRAM} ${PROG} ${DESTDIR}${BINDIR}/
		${INSTALL_DATA} ${MAN1GZ} ${DESTDIR}${MANDIR}1/
		${INSTALL_DATA} t/*.t ${DESTDIR}${EXAMPLESDIR}/tests/

check:		all
		prove -v t
