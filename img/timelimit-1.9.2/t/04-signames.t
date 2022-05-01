#!/bin/sh
#
# Copyright (c) 2011, 2018  Peter Pentchev
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

plan_ 10

diag_ 'list the available signal names'
v=`$TIMELIMIT -l 2>/dev/null`
res="$?"
if [ "$res" = 0 ]; then ok_; else not_ok_ "exit code $res"; fi
if expr "x$v" : 'x.*TERM'; then ok_; else not_ok_ "no TERM in timelimit -l"; fi
if expr "x$v" : 'x.*HUP'; then ok_; else not_ok_ "no HUP in timelimit -l"; fi
if ! expr "x$v" : 'x.*HUX'; then ok_; else not_ok_ "found HUX in timelimit -l"; fi
if ! expr "x$v" : 'x.*TERX'; then ok_; else not_ok_ "found TERX in timelimit -l"; fi

diag_ 'use signal names'
v=`$TIMELIMIT -t 1 -s HUP -T 1 -S TERM sh -c 'trap "" HUP; echo 1; sleep 3; echo 2' 2>/dev/null`
res="$?"
if [ "$res" = 143 ]; then ok_; else not_ok_ "exit code $res"; fi
if expr "x$v" : 'x1' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi
if ! expr "x$v" : 'x.*2' > /dev/null; then ok_; else not_ok_ "v is '$v'"; fi

diag_ 'use an invalid signal name for the warning signal'
v=`$TIMELIMIT -t 1 -s HUX -T 1 -S TERM sh -c 'trap "" HUP; echo 1; sleep 3; echo 2' 2>/dev/null`
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "exit code $res"; fi

diag_ 'use an invalid signal name for the kill signal'
v=`$TIMELIMIT -t 1 -s HUP -T 1 -S TERX sh -c 'trap "" HUP; echo 1; sleep 3; echo 2' 2>/dev/null`
res="$?"
if [ "$res" = 64 ]; then ok_; else not_ok_ "exit code $res"; fi
