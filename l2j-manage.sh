#!/bin/bash
set -e

# =============================================================
# L2J Mobius High Five - скрипт управления сервером
# =============================================================

IMAGE="l2j-mobius-h5:patched"
DB_IMAGE="mariadb:10.6"
USER_HOME="$HOME"
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
fi
DIR="$USER_HOME/l2j"
DB_NAME="l2jmobiush5"
BACKUP_DIR="$DIR/backups"

log() {
  echo "==> $1"
}

fail() {
  echo "Ошибка: $1" >&2
  exit 1
}

require_compose() {
  [ -f "$DIR/docker-compose.yml" ] || fail "Файл $DIR/docker-compose.yml не найден. Сначала запустите ./l2j-setup.sh"
  cd "$DIR" || fail "Не удалось перейти в папку $DIR"
}

sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

start() {
  log "Запускаем контейнеры"
  require_compose
  docker compose up -d || fail "Не удалось запустить контейнеры"
}

stop() {
  log "Останавливаем контейнеры"
  require_compose
  docker compose down || fail "Не удалось остановить контейнеры"
}

restart() {
  log "Перезапускаем контейнеры"
  require_compose
  docker compose down || fail "Не удалось остановить контейнеры"
  docker compose up -d || fail "Не удалось запустить контейнеры"
}

status() {
  log "Показываем статус контейнеров"
  require_compose
  docker compose ps || fail "Не удалось получить статус контейнеров"

  echo ""
  log "Последние 20 строк логов login"
  docker logs l2j-login --tail 20 || fail "Не удалось получить логи login"

  echo ""
  log "Последние 20 строк логов game"
  docker logs l2j-game --tail 20 || fail "Не удалось получить логи game"
}

logs() {
  log "Показываем живые логи"
  require_compose
  docker compose logs -f || fail "Не удалось открыть живые логи"
}

backup() {
  log "Создаём бэкап базы $DB_NAME"
  require_compose
  mkdir -p "$BACKUP_DIR" || fail "Не удалось создать папку $BACKUP_DIR"

  local backup_file="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).sql"
  docker exec l2j-db mariadb-dump -uroot "$DB_NAME" > "$backup_file" || fail "Не удалось создать бэкап базы"
  log "Бэкап сохранён: $backup_file"
}

restore() {
  log "Восстанавливаем базу $DB_NAME из последнего бэкапа"
  require_compose

  local backup_file
  backup_file=$(ls -t "$BACKUP_DIR"/backup_*.sql 2>/dev/null | head -n 1 || true)
  [ -n "$backup_file" ] || fail "Бэкапы не найдены в $BACKUP_DIR"

  docker exec -i l2j-db mysql -uroot "$DB_NAME" < "$backup_file" || fail "Не удалось восстановить базу из $backup_file"
  log "База восстановлена из $backup_file"
}

addaccount() {
  local login="$1"
  local password="$2"

  [ -n "$login" ] || fail "Укажите логин: ./l2j-manage.sh addaccount <login> <password>"
  [ -n "$password" ] || fail "Укажите пароль: ./l2j-manage.sh addaccount <login> <password>"

  log "Создаём аккаунт $login"
  require_compose

  local safe_login
  local safe_password
  safe_login=$(sql_escape "$login")
  safe_password=$(sql_escape "$password")

  docker exec l2j-db mysql -uroot "$DB_NAME" -e "
    INSERT INTO accounts (login, password, accessLevel)
    VALUES ('$safe_login', TO_BASE64(UNHEX(SHA1('$safe_password'))), 0);
  " || fail "Не удалось создать аккаунт $login"
}

setpassword() {
  local login="$1"
  local password="$2"

  [ -n "$login" ] || fail "Укажите логин: ./l2j-manage.sh setpassword <login> <password>"
  [ -n "$password" ] || fail "Укажите пароль: ./l2j-manage.sh setpassword <login> <password>"

  log "Меняем пароль аккаунта $login"
  require_compose

  local safe_login
  local safe_password
  safe_login=$(sql_escape "$login")
  safe_password=$(sql_escape "$password")

  local account_exists
  account_exists=$(docker exec l2j-db mysql -N -B -uroot "$DB_NAME" -e "
    SELECT COUNT(*) FROM accounts WHERE login = '$safe_login';
  " 2>/dev/null) || fail "Не удалось проверить аккаунт $login"

  [ "$account_exists" = "1" ] || fail "Аккаунт $login не найден"

  docker exec l2j-db mysql -uroot "$DB_NAME" -e "
    UPDATE accounts
    SET password = TO_BASE64(UNHEX(SHA1('$safe_password')))
    WHERE login = '$safe_login';
  " || fail "Не удалось сменить пароль аккаунта $login"

  log "Пароль аккаунта $login изменён"
}

usage() {
  echo "Использование: $0 {start|stop|restart|status|logs|backup|restore|addaccount <login> <password>|setpassword <login> <password>}"
}

case "${1:-}" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    restart
    ;;
  status)
    status
    ;;
  logs)
    logs
    ;;
  backup)
    backup
    ;;
  restore)
    restore
    ;;
  addaccount)
    shift
    addaccount "$@"
    ;;
  setpassword)
    shift
    setpassword "$@"
    ;;
  *)
    usage
    exit 1
    ;;
esac
