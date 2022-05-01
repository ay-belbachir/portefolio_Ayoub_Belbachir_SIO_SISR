#!/bin/sh
#
# Copyright (c) 2011, 2018, 2021  Peter Pentchev
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

if [ -f 'tap-functions.sh' ]; then
	. tap-functions.sh
elif [ -f 't/tap-functions.sh' ]; then
	. t/tap-functions.sh
else
	echo 'Bail out! Could not find tap-functions.sh'
	exit 99
fi

[ -z "$TIMELIMIT" ] && TIMELIMIT='./timelimit'

plan_ 39

diag_ 'timelimit with no arguments should exit with EX_USAGE'
$TIMELIMIT > /dev/null 2>&1
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "exit code $res"; fi

diag_ 'kill a shell script during the sleep, only execute a single echo'
v=`$TIMELIMIT -t 1 sh -c 'echo 1; sleep 3; echo 2' 2>/dev/null`
res="$?"
if [ "$res" = 143 ]; then ok_; else not_ok_ "exit code $res"; fi
if expr "x$v" : 'x1' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi
if ! expr "x$v" : 'x.*2' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi

diag_ 'give the shell script time enough to execute both echos'
v=`$TIMELIMIT -t 4 sh -c 'echo 1; sleep 3; echo 2' 2>/dev/null`
res="$?"
if [ "$res" = 0 ]; then ok_; else not_ok_ "exit code $res"; fi
if expr "x$v" : 'x1' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi
if expr "x$v" : 'x.*2' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi

diag_ 'catch the warning signal, run two out of three echos'
v=`$TIMELIMIT -t 1 -T 4 sh -c 'trap "" TERM; echo 1; sleep 3; echo 2; sleep 3; echo 3' 2>/dev/null`
res="$?"
if [ "$res" = 137 ]; then ok_; else not_ok_ "exit code $res"; fi
if expr "x$v" : 'x1' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi
if expr "x$v" : 'x.*2' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi
if ! expr "x$v" : 'x.*3' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi

diag_ 'catch the warning signal and still run to completion'
v=`$TIMELIMIT -t 1 -T 12 sh -c 'trap "" TERM; echo 1; sleep 3; echo 2; sleep 3; echo 3' 2>/dev/null`
res="$?"
if [ "$res" = 0 ]; then ok_; else not_ok_ "exit code $res"; fi
if expr "x$v" : 'x1' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi
if expr "x$v" : 'x.*2' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi
if expr "x$v" : 'x.*3' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi

diag_ 'now interrupt with a different signal'
v=`$TIMELIMIT -t 1 -s 1 sh -c 'echo 1; sleep 3; echo 2' 2>/dev/null`
res="$?"
if [ "$res" = 129 ]; then ok_; else not_ok_ "exit code $res"; fi
if expr "x$v" : 'x1' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi
if ! expr "x$v" : 'x.*2' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi

diag_ 'now catch that different signal'
v=`$TIMELIMIT -t 1 -s 1 sh -c 'trap "" HUP; echo 1; sleep 3; echo 2' 2>/dev/null`
res="$?"
if [ "$res" = 0 ]; then ok_; else not_ok_ "exit code $res"; fi
if expr "x$v" : 'x1' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi
if expr "x$v" : 'x.*2' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi

diag_ 'now kill with a yet different signal'
v=`$TIMELIMIT -t 1 -s 1 -T 1 -S 15 sh -c 'trap "" HUP; echo 1; sleep 3; echo 2' 2>/dev/null`
res="$?"
if [ "$res" = 143 ]; then ok_; else not_ok_ "exit code $res"; fi
if expr "x$v" : 'x1' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi
if ! expr "x$v" : 'x.*2' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi

diag_ 'timelimit with an invalid argument should exit with EX_USAGE'
$TIMELIMIT -X > /dev/null 2>&1
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "exit code $res"; fi

diag_ 'use invalid numbers for the various options'
v=`$TIMELIMIT -t x true 2>/dev/null`
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "-t x exit code $res"; fi
v=`$TIMELIMIT -T x true 2>/dev/null`
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "-T x exit code $res"; fi
v=`$TIMELIMIT -s x true 2>/dev/null`
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "-s x exit code $res"; fi
v=`$TIMELIMIT -S x true 2>/dev/null`
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "-S x exit code $res"; fi
v=`$TIMELIMIT -s 1.5 true 2>/dev/null`
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "-s 1.5 exit code $res"; fi
v=`$TIMELIMIT -S 1.5 true 2>/dev/null`
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "-S 1.5 exit code $res"; fi
v=`$TIMELIMIT -t '' true 2>/dev/null`
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "-t '' exit code $res"; fi
v=`$TIMELIMIT -T '' true 2>/dev/null`
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "-T '' exit code $res"; fi
v=`$TIMELIMIT -s '' true 2>/dev/null`
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "-s '' exit code $res"; fi
v=`$TIMELIMIT -S '' true 2>/dev/null`
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "-S '' exit code $res"; fi

diag_ 'propagate a TERM signal'
v=`$TIMELIMIT -s 15 -t 3 -p sh -c 'sleep 5' 2>/dev/null`
res="$?"
if [ "$res" = 143 ]; then ok_; else not_ok_ "args -s 15 -p exit code $res"; fi
diag_ 'propagate a KILL signal'
v=`$TIMELIMIT -s 9 -t 3 -p sh -c 'sleep 5' 2>/dev/null`
res="$?"
if [ "$res" = 137 ]; then ok_; else not_ok_ "args -s 9 -p exit code $res"; fi

diag_ 'timelimit --features should contain a "timelimit" entry'
v=`$TIMELIMIT --features`
res="$?"
if [ "$res" = 0 ]; then ok_; else not_ok_ "--features exit code $res"; fi
if expr "x$v" : 'xFeatures:.* timelimit=' > /dev/null; then ok_; else not_ok_ "--features output: $v"; fi
