# L2J Setup

Скрипты для быстрого запуска и управления сервером L2J Mobius High Five через Docker.

## Требования

- Только Docker на Linux-сервере или VPS.

Скрипты используют команду `docker compose`, которая входит в современную установку Docker.

## Быстрый старт

```bash
git clone <URL_РЕПОЗИТОРИЯ>
cd l2j-setup
chmod +x l2j-setup.sh l2j-manage.sh
./l2j-setup.sh
```

Если у пользователя нет доступа к Docker socket, запускайте те же команды через `sudo`.
Скрипты всё равно будут использовать папку обычного пользователя, например `~/l2j`, а не `/root/l2j`.

После установки файлы сервера будут находиться в `~/l2j`, а основной compose-файл будет создан как `~/l2j/docker-compose.yml`.

Setup скачивает базовый образ `sealbro/lineage2-server:chaotic-throne-high-five` и собирает локальный образ `l2j-mobius-h5:patched` с исправлениями datapack.

По умолчанию создаётся аккаунт:

```text
admin / admin
```

## Настройка клиента

В клиенте Lineage 2 откройте файл:

```text
system/l2.ini
```

Укажите IP-адрес сервера в строке:

```ini
ServerAddr=ВАШ_IP
```

## Порты

- `2106` - login server
- `7777` - game server

## Управление сервером

Все команды выполняются из папки репозитория:

```bash
./l2j-manage.sh <команда>
```

Запустить контейнеры:

```bash
./l2j-manage.sh start
```

Остановить контейнеры:

```bash
./l2j-manage.sh stop
```

Перезапустить контейнеры:

```bash
./l2j-manage.sh restart
```

Показать статус и последние 20 строк логов login и game:

```bash
./l2j-manage.sh status
```

Показать живые логи:

```bash
./l2j-manage.sh logs
```

Создать бэкап базы данных:

```bash
./l2j-manage.sh backup
```

Бэкапы сохраняются в:

```text
~/l2j/backups/backup_YYYYMMDD_HHMMSS.sql
```

Восстановить базу из последнего бэкапа:

```bash
./l2j-manage.sh restore
```

Создать аккаунт:

```bash
./l2j-manage.sh addaccount player1 password123
```

## Как обновить образ сервера

Остановите сервер, скачайте свежий образ и запустите контейнеры снова:

```bash
./l2j-manage.sh stop
docker pull sealbro/lineage2-server:chaotic-throne-high-five
./l2j-manage.sh start
```

Если нужно полностью пересоздать контейнеры после обновления образа:

```bash
cd ~/l2j
docker compose up -d --force-recreate
```
