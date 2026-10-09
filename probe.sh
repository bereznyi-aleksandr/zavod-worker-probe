#!/bin/bash
# ДОКУМЕНТ: probe.sh  ВЕРСИЯ: v0.1  СТАТУС: CANDIDATE
# ДАТА СОЗДАНИЯ: 2026-10-09 22:15 +03:00  ИСПОЛНИТЕЛЬ: Claude (сессия fd43469f-418c-4f8b-b94b-32cc0b8d4acf)
# НАЗНАЧЕНИЕ: пробы E4-2 (а)–(з) протокола Z1 v1.9 в облачной сессии рабочего. Печатает только коды и
#   первые строки ответов; значения переменных с ключами не печатает (только «заглушка / нет / другое, длина»).
# ВЫЗОВ: bash probe.sh 2>&1 | tee probe_out.txt
set +e
O=bereznyi-aleksandr
T=$(mktemp -d)
r() { local name=$1; shift; local out; out=$("$@" 2>&1); local rc=$?
  echo "$name exit=$rc :: $(printf '%s' "$out" | head -3 | tr '\n' ' ' | cut -c1-300)"; }
echo "E42_PROBE v0.1 $(date -u +%FT%TZ) host=$(hostname) user=$(id -un)"
echo "GIT_USER=$(git config --get user.name 2>/dev/null) ORIGIN=$(git remote get-url origin 2>/dev/null)"

echo "## (a) canary A: no access for OD-9 account — every command must be refused"
r A_LSREMOTE git ls-remote https://github.com/$O/zavod-canary-a.git
r A_CLONE git clone -q https://github.com/$O/zavod-canary-a.git "$T/a"
r A_FETCH git fetch -q https://github.com/$O/zavod-canary-a.git main
r A_API gh api repos/$O/zavod-canary-a --jq .full_name
r A_MARKER grep -h MARKER "$T/a/README.md"

echo "## (b) canary B: OD-9 has access, not attached to session — API must be 403 'not enabled for this session'; git is recorded"
r B_API gh api repos/$O/zavod-canary-b --jq .full_name
r B_LSREMOTE git ls-remote https://github.com/$O/zavod-canary-b.git
r B_CLONE git clone -q https://github.com/$O/zavod-canary-b.git "$T/b"
r B_FETCH git fetch -q https://github.com/$O/zavod-canary-b.git main
r B_MARKER grep -h MARKER "$T/b/README.md"

echo "## (c) network outside the Custom list — must be refused"
r C_EXAMPLE curl -sS -m 10 -o /dev/null -w "%{http_code}" https://example.com/
r C_RAW curl -sS -m 10 -o /dev/null -w "%{http_code}" https://raw.githubusercontent.com/$O/ai-devops-system/main/README.md
r C_TELEGRAM curl -sS -m 10 -o /dev/null -w "%{http_code}" https://api.telegram.org/

echo "## (d) GH_TOKEN / GITHUB_TOKEN must equal the proxy placeholder (value never printed)"
for v in GH_TOKEN GITHUB_TOKEN; do val="${!v}"
  if [ -z "$val" ]; then echo "D_$v=UNSET"; elif [ "$val" = "proxy-injected" ]; then echo "D_$v=PLACEHOLDER"; else echo "D_$v=OTHER len=${#val}"; fi
done
echo "D_ENV_NAMES_WITH_KEY_WORDS=$(env | cut -d= -f1 | grep -Ei 'token|secret|key|pass' | sort | tr '\n' ' ')"

echo "## (e) no Kernel services or database in the VM"
for p in 5432 54348; do r E_PORT_$p bash -c "(exec 3<>/dev/tcp/127.0.0.1/$p) 2>/dev/null && echo OPEN || echo CLOSED"; done
r E_PROCS bash -c "ps -eo comm,args | grep -Ei 'postgres|kernel' | grep -v grep | wc -l"
r E_WRITE bash -c "echo probe > /tmp/e42_write_test && ls -l /tmp/e42_write_test"

echo "## (f) direct process with a clean environment — boundary must not change"
r F_DIRECT_A env -i PATH=/usr/bin:/bin HOME="$HOME" git ls-remote https://github.com/$O/zavod-canary-a.git

echo "## (g) positive: own repo, branch push, allowed address"
r Z_OWN_LSREMOTE git ls-remote origin
BR="probe/e42-$(date -u +%Y%m%d%H%M%S)"
r Z_BRANCH git checkout -q -b "$BR"
echo "$BR" > probe_branch.txt
git add probe_branch.txt
r Z_COMMIT git -c user.name=zavod-probe -c user.email=probe@invalid commit -q -m "E4-2 positive push probe"
r Z_PUSH git push -q -u origin "$BR"
r Z_NPM curl -sS -m 10 -o /dev/null -w "%{http_code}" https://registry.npmjs.org/grammy
echo "E42_PROBE_END"
