#!/bin/bash
set -e

# =============================================================
# L2J Mobius High Five - скрипт установки через Docker
# =============================================================

BASE_IMAGE="sealbro/lineage2-server:chaotic-throne-high-five"
IMAGE="l2j-mobius-h5:patched"
DB_IMAGE="mariadb:10.6"
USER_HOME="$HOME"
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
fi
DIR="$USER_HOME/l2j"
DB_NAME="l2jmobiush5"
SQL_TMP="/tmp/l2sql"

log() {
  echo "==> $1"
}

fail() {
  echo "Ошибка: $1" >&2
  exit 1
}

run_step() {
  local name="$1"
  shift

  "$@" || fail "$name"
}

check_dependencies() {
  log "Проверяем зависимости"
  command -v docker >/dev/null 2>&1 || fail "Docker не найден. Установите Docker и повторите запуск."
  docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin не найден. Установите Docker с поддержкой 'docker compose'."
}

create_compose() {
  log "Создаём папку $DIR"
  mkdir -p "$DIR" || fail "Не удалось создать папку $DIR"

  log "Создаём docker-compose.yml"
  if ! cat > "$DIR/docker-compose.yml" << EOF
services:
  db:
    image: $DB_IMAGE
    container_name: l2j-db
    environment:
      MARIADB_ALLOW_EMPTY_ROOT_PASSWORD: "yes"
      MARIADB_ROOT_HOST: "%"
    ports:
      - "3306:3306"
    volumes:
      - l2jdb:/var/lib/mysql

  login:
    image: $IMAGE
    container_name: l2j-login
    network_mode: host
    environment:
      DB_HOST: localhost
      DB_PORT: 3306
    depends_on:
      - db
    command: login

  game:
    image: $IMAGE
    container_name: l2j-game
    network_mode: host
    environment:
      DB_HOST: localhost
      DB_PORT: 3306
    depends_on:
      - login
    command: game

volumes:
  l2jdb:
EOF
  then
    fail "Не удалось записать файл $DIR/docker-compose.yml"
  fi
}

pull_images() {
  log "Скачиваем Docker-образы"
  docker pull "$BASE_IMAGE" || fail "Не удалось скачать образ сервера $BASE_IMAGE"
  docker pull "$DB_IMAGE" || fail "Не удалось скачать образ базы данных $DB_IMAGE"
}

build_server_image() {
  log "Собираем локальный образ сервера с патчами"
  docker build -f Dockerfile.patched -t "$IMAGE" . || fail "Не удалось собрать локальный образ сервера $IMAGE"
}

start_db() {
  log "Запускаем MariaDB"
  cd "$DIR" || fail "Не удалось перейти в папку $DIR"
  docker compose up -d db || fail "Не удалось запустить MariaDB"

  log "Ждём пока MariaDB поднимется (15 сек)..."
  sleep 15
}

init_db() {
  log "Создаём базу данных $DB_NAME и права root"
  docker exec l2j-db mysql -uroot -e "
    CREATE DATABASE IF NOT EXISTS $DB_NAME;
    ALTER USER 'root'@'%' IDENTIFIED BY '';
    GRANT ALL ON $DB_NAME.* TO 'root'@'%';
    FLUSH PRIVILEGES;
  " || fail "Не удалось инициализировать базу данных $DB_NAME"
}

import_sql() {
  log "Копируем SQL-файлы из образа"
  rm -rf "$SQL_TMP" || fail "Не удалось очистить временную папку $SQL_TMP"
  mkdir -p "$SQL_TMP" || fail "Не удалось создать временную папку $SQL_TMP"
  docker run --rm --entrypoint /bin/sh \
    -v "$SQL_TMP:/output" \
    "$IMAGE" \
    -c "cp -r /app/db_installer/sql/login /output/ && cp -r /app/db_installer/sql/game /output/" \
    || fail "Не удалось скопировать SQL-файлы из образа"

  log "Заливаем SQL в базу $DB_NAME"
  docker run --rm --network host \
    -v "$SQL_TMP:/sql" \
    "$DB_IMAGE" bash -c "
      for f in /sql/login/*.sql; do
        mysql -h127.0.0.1 -uroot $DB_NAME < \$f 2>/dev/null || true
      done
      for f in /sql/game/*.sql; do
        mysql -h127.0.0.1 -uroot $DB_NAME < \$f 2>/dev/null || true
      done
      echo SQL_DONE" \
    || fail "Не удалось импортировать SQL-файлы в базу $DB_NAME"
}

create_admin_account() {
  log "Создаём дефолтный аккаунт admin/admin"
  docker exec l2j-db mysql -uroot "$DB_NAME" -e "
    INSERT INTO accounts (login, password, accessLevel)
    VALUES ('admin', TO_BASE64(UNHEX(SHA1('admin'))), 0)
    ON DUPLICATE KEY UPDATE password = TO_BASE64(UNHEX(SHA1('admin'))), accessLevel = 0;
  " || fail "Не удалось создать аккаунт admin/admin"
}

start_servers() {
  log "Запускаем login и game серверы"
  cd "$DIR" || fail "Не удалось перейти в папку $DIR"
  docker compose up -d login game || fail "Не удалось запустить login и game серверы"

  log "Ждём запуска (10 сек)..."
  sleep 10
}

show_status() {
  log "Статус контейнеров:"
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || fail "Не удалось получить статус контейнеров"

  echo ""
  log "Логи login сервера:"
  docker logs l2j-login --tail 10 || fail "Не удалось получить логи login сервера"

  echo ""
  log "Логи game сервера:"
  docker logs l2j-game --tail 10 || fail "Не удалось получить логи game сервера"

  echo ""
  echo "============================================"
  echo " L2J High Five запущен!"
  echo " В клиенте (system/l2.ini) укажи:"
  EXT_IP=$(curl -s ifconfig.me 2>/dev/null || echo "ВАШ_IP")
  echo " ServerAddr=$EXT_IP"
  echo " Порты: 2106 (login), 7777 (game)"
  echo " Аккаунт по умолчанию: admin/admin"
  echo "============================================"
}

main() {
  run_step "Проверка зависимостей завершилась ошибкой" check_dependencies
  run_step "Создание docker-compose.yml завершилось ошибкой" create_compose
  run_step "Скачивание образов завершилось ошибкой" pull_images
  run_step "Сборка локального образа завершилась ошибкой" build_server_image
  run_step "Запуск MariaDB завершился ошибкой" start_db
  run_step "Инициализация базы завершилась ошибкой" init_db
  run_step "Импорт SQL завершился ошибкой" import_sql
  run_step "Создание аккаунта admin/admin завершилось ошибкой" create_admin_account
  run_step "Запуск серверов завершился ошибкой" start_servers
  run_step "Показ статуса завершился ошибкой" show_status
}

main "$@"
