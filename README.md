# Marketplace Analytics

Пайплайн для сбора, хранения и анализа данных онлайн-маркетплейса.

## Стек технологий

- **Python** — сбор и загрузка данных
- **PostgreSQL** — хранение данных
- **Metabase** — дашборд с аналитикой

## Структура проекта

```
src/
├── api_client.py # Клиент для запросов к API
├── db.py # Подключение к базе данных
├── ddl.sql # Схема базы данных
├── load_history.py # Единоразовая загрузка исторических данных
└── load_one_day.py # Ежедневная загрузка данных (запускается через cron)
```

## Установка

1. Клонировать репозиторий
2. Создать виртуальное окружение и установить зависимости:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install requests pandas sqlalchemy psycopg2-binary python-dotenv
```

3. Создать файл `.env`:
   DB_HOST=your_host
   DB_PORT=5432
   DB_NAME=your_db
   DB_USER=your_user
   DB_PASSWORD=your_password

4. Создать схему базы данных:

```bash
psql -U your_user -d your_db -h 127.0.0.1 -f src/ddl.sql
```

5. Загрузить исторические данные:

```bash
python3 src/load_history.py
```

## Автоматическая загрузка

Ежедневный загрузчик запускается каждый день в 7:00 по московскому времени:
0 7 \* \* \* cd /root/final_project_simulative && /root/final_project_simulative/.venv/bin/python3 src/load_one_day.py >> /root/final_project_simulative/logs/cron_daily_load.out 2>&1
