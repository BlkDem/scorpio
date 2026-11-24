#!/bin/sh
# Публикация веб-версии на https://scorpio.umolab.ru/
# (FastPanel-хост fp.cloud28.umolab.ru, пользователь user1, вход по ключу).
#
#   sh tool/deploy_web.sh              — собрать и выложить
#   SKIP_BUILD=1 sh tool/deploy_web.sh — выложить уже собранный build/web
#
# 1. flutter build web --release (JS + CanvasKit; wasm-рендерер skwasm пока не используем)
# 2. архив сайта уходит кусками по 2 МБ с ограничением скорости и повторами
#    (хост рвёт длинные передачи)
# 3. только когда архив целиком на сервере: очищаем папку сайта (кроме .well-known)
#    и распаковываем. При первой выкладке заглушка панели сохраняется как scorpio.umolab.ru.orig.
set -e
cd "$(dirname "$0")/.."
HOST=${HOST:-user1@fp.cloud28.umolab.ru}
DIR=/var/www/fastuser/data/www/scorpio.umolab.ru
TMP=/var/www/fastuser/data/tmp/scorpio_deploy
LIMIT=${LIMIT:-3000}                      # ограничение scp, Кбит/с
FLUTTER=${FLUTTER:-flutter}
SSH="ssh -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=5"

retry() { n=0; until "$@"; do n=$((n + 1)); [ $n -ge 6 ] && return 1; sleep 5; done; }

[ -n "$SKIP_BUILD" ] || "$FLUTTER" build web --release
test -s build/web/index.html && test -s build/web/main.dart.js

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
tar -cf "$W/site.tar" -C build/web .
SIZE=$(wc -c < "$W/site.tar" | tr -d ' ')
mkdir "$W/p" && split -b 2M -d -a 3 "$W/site.tar" "$W/p/p."
retry $SSH "$HOST" "rm -rf $TMP && mkdir -p $TMP"
for f in "$W"/p/p.*; do
  retry scp -q -l "$LIMIT" -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=5 "$f" "$HOST:$TMP/"
  printf '.'
done
echo
retry $SSH "$HOST" "set -e; cd $TMP && cat p.* > site.tar && test \$(wc -c < site.tar) -eq $SIZE
  if [ ! -w $DIR ]; then
    [ -e $DIR.orig ] || mv $DIR $DIR.orig
    mkdir -p $DIR && chgrp fastuser $DIR && chmod 2775 $DIR
  fi
  cd $DIR && find . -mindepth 1 -maxdepth 1 ! -name .well-known -exec rm -rf {} +
  tar -xf $TMP/site.tar --no-same-owner && find . -type d -exec chmod 2775 {} + && find . -type f -exec chmod 664 {} +
  rm -rf $TMP"
echo "опубликовано: https://scorpio.umolab.ru/ ($SIZE байт)"
