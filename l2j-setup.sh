#!/bin/bash
set -e

# =============================================================
# L2J Mobius High Five - Docker Setup Script
# =============================================================

IMAGE="sealbro/lineage2-server:chaotic-throne-high-five"
DB_IMAGE="mariadb:10.6"
DIR="$HOME/l2j"
SQL_TMP="/tmp/l2sql"

DB_ROOT_PASS="l2jroot"
DB_USER="l2jdb"
DB_PASS="l2jdb"
DB_GAME="l2jdb_game"
DB_LOGIN="l2jdb_login"

echo "==> Создаём папку $DIR"
mkdir -p "$DIR"

echo "==> Создаём docker-compose.yml"
cat > "$DIR/docker-compose.yml" << EOF
services:
  db:
    image: $DB_IMAGE
    container_name: l2j-db
    environment:
      MYSQL_ROOT_PASSWORD: $DB_ROOT_PASS
      MYSQL_USER: $DB_USER
      MYSQL_PASSWORD: $DB_PASS
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
      DB_USER: $DB_USER
      DB_PASSWORD: $DB_PASS
      DB_NAME_GAME: $DB_GAME
      DB_NAME_LOGIN: $DB_LOGIN
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
      DB_USER: $DB_USER
      DB_PASSWORD: $DB_PASS
      DB_NAME_GAME: $DB_GAME
      DB_NAME_LOGIN: $DB_LOGIN
    depends_on:
      - login
    command: game

volumes:
  l2jdb:
EOF

echo "==> Скачиваем образы"
docker pull "$IMAGE"
docker pull "$DB_IMAGE"

echo "==> Запускаем MariaDB"
cd "$DIR" && docker compose up -d db

echo "==> Ждём пока MariaDB поднимется (15 сек)..."
sleep 15

echo "==> Создаём базы данных и пользователя"
docker exec l2j-db mysql -uroot -p"$DB_ROOT_PASS" -e "
  CREATE DATABASE IF NOT EXISTS $DB_GAME;
  CREATE DATABASE IF NOT EXISTS $DB_LOGIN;
  GRANT ALL PRIVILEGES ON $DB_GAME.* TO '$DB_USER'@'%';
  GRANT ALL PRIVILEGES ON $DB_LOGIN.* TO '$DB_USER'@'%';
  FLUSH PRIVILEGES;
"

echo "==> Копируем SQL файлы из образа"
rm -rf "$SQL_TMP"
mkdir -p "$SQL_TMP"
docker run --rm --entrypoint /bin/sh \
  -v "$SQL_TMP:/output" \
  "$IMAGE" \
  -c "cp -r /app/db_installer/sql/login /output/ && cp -r /app/db_installer/sql/game /output/"

echo "==> Заливаем SQL в БД"
docker run --rm --network host \
  -v "$SQL_TMP:/sql" \
  "$DB_IMAGE" bash -c "
    for f in /sql/login/*.sql; do
      mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS $DB_LOGIN < \$f 2>/dev/null || true
    done
    for f in /sql/game/*.sql; do
      mysql -h127.0.0.1 -u$DB_USER -p$DB_PASS $DB_GAME < \$f 2>/dev/null || true
    done
    echo SQL_DONE"

echo "==> Запускаем login и game серверы"
cd "$DIR" && docker compose up -d login game

echo "==> Ждём запуска (10 сек)..."
sleep 10

echo "==> Статус контейнеров:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "==> Логи login сервера:"
docker logs l2j-login --tail 10

echo ""
echo "==> Логи game сервера:"
docker logs l2j-game --tail 10

echo ""
echo "============================================"
echo " L2J High Five запущен!"
echo " В клиенте (system/l2.ini) укажи:"
EXT_IP=$(curl -s ifconfig.me 2>/dev/null || echo "ВАШ_IP")
echo " ServerAddr=$EXT_IP"
echo " Порты: 2106 (login), 7777 (game)"
echo "============================================"
