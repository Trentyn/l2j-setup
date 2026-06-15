# L2J Setup

Скрипт для быстрого запуска сервера L2J Mobius High Five через Docker.

## Что делает скрипт

- Создает папку `~/l2j`.
- Генерирует `docker-compose.yml`.
- Запускает MariaDB.
- Создает базы `l2jdb_game` и `l2jdb_login`.
- Копирует SQL-файлы из Docker-образа сервера.
- Загружает SQL в базы данных.
- Запускает login и game серверы.
- Показывает статус контейнеров и последние логи.

## Требования

- Linux-сервер или VPS.
- Установленный Docker.
- Установленный Docker Compose plugin (`docker compose`).
- Открытые порты:
  - `2106` для login-сервера;
  - `7777` для game-сервера;
  - `3306` для MariaDB, если нужен внешний доступ к базе.

## Запуск

```bash
chmod +x l2j-setup.sh
./l2j-setup.sh
```

После запуска скрипт выведет IP-адрес, который нужно указать в клиенте Lineage 2:

```ini
ServerAddr=ВАШ_IP
```

## Используемые образы

- `sealbro/lineage2-server:chaotic-throne-high-five`
- `mariadb:10.6`

## Где будут файлы

Рабочая папка создается здесь:

```bash
~/l2j
```

Основной файл Docker Compose:

```bash
~/l2j/docker-compose.yml
```

## Полезные команды

Посмотреть контейнеры:

```bash
docker ps
```

Посмотреть логи login-сервера:

```bash
docker logs l2j-login --tail 50
```

Посмотреть логи game-сервера:

```bash
docker logs l2j-game --tail 50
```

Остановить сервер:

```bash
cd ~/l2j
docker compose down
```

Запустить сервер снова:

```bash
cd ~/l2j
docker compose up -d
```

## Важно

Пароли к базе данных сейчас заданы прямо в скрипте. Для публичного или постоянного сервера лучше изменить значения переменных `DB_ROOT_PASS`, `DB_USER` и `DB_PASS` перед запуском.
