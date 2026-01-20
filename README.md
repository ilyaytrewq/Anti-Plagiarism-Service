# Anti-Plagiarism Service
Микросервисная система для проверки студенческих работ на плагиат с использованием векторных эмбеддингов.

Базовые URL:
- локально (docker compose): `http://localhost:8080/api/v1`
- из `api-files/openapi.yaml`: `http://158.160.186.61:8080/api/v1`
Swagger UI (docker compose): `http://localhost:8088`

## Архитектура

### 4 микросервиса:

1. **api-gateway** (`:8080`) — публичный API, Postgres для работ/сабмитов, вызовы file-storing и file-analisys
2. **file-storing** (`:8082`) — загрузка/выгрузка файлов в S3-совместимое хранилище
3. **file-analisys** (`:8081`) — очередь, анализ и отчеты; Postgres + Qdrant
4. **embedding-service** (`:8083`) — генерация эмбеддингов через Yandex Cloud

### Инфраструктура (docker-compose)

- `postgres-gateway` — БД для API Gateway
- `postgres-analysis` — БД для file-analisys
- `qdrant` — векторный поиск
- `swagger` — Swagger UI

### Пайплайн обработки:

```
Client → API Gateway → File Storing (загрузка файла, получение fileId)
                    → File Analysis (скачивание файла, chunking, запуск проверки)
                    → Embedding Service (векторизация чанков)
                    → Qdrant (поиск похожих векторов)
                    → Postgres (сохранение результатов)
Client ← API Gateway ← File Analysis (получение отчета)
```

## Запуск

### Переменные окружения

- `file-storing/internal/env-files/s3.env` — `S3_ENDPOINT`, `S3_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `S3_BUCKET`
- `embedding-service/internal/env-files/yandexCloud.env` — `API_KEY`, `FOLDER_ID`, `URL`
- опционально: `QDRANT_API_KEY` (по умолчанию `local-dev-key` в docker-compose)

### Запуск сервисов

```bash
docker compose up --build -d
```

## ⚙️ Асинхронная обработка

- `POST /works/{workId}/submissions` возвращает 202 и ставит задачу в очередь.
- Обработка выполняется воркер пулом в `file-analisys` (пакет `filequeue`).
- Статусы отчета: `QUEUED → PROCESSING → DONE/ERROR`.
- Настройки: `FILEQUEUE_WORKERS`, `FILEQUEUE_SIZE`.

## 🛠 Tech Stack

- **Go 1.25.4** — backend
- **Chi** — HTTP router
- **OpenAPI 3.0** — API specification
- **oapi-codegen** — code generation from OpenAPI
- **PostgreSQL** — хранение работ/отчетов
- **Qdrant** — векторный поиск
- **Yandex Cloud Embeddings** — генерация эмбеддингов
- **S3-compatible storage** — хранение файлов (Yandex Object Storage)
- **QuickChart Word Cloud** — генерация облака слов
- **Docker / Docker Compose** — окружение и запуск

## 🔌 API Endpoints

Все эндпоинты ниже доступны под `/api/v1`, кроме `/health`.

- `POST /works` — создать работу (assignment)
- `POST /works/{workId}/submissions` — загрузить файл работы и запустить проверку
- `GET /works/{workId}/reports` — получить отчеты по всем сабмитам работы
- `GET /submissions/{submissionId}` — получить детали сабмита и отчет
- `GET /works/{workId}/stats` — агрегированная статистика по работе
- `POST /wordcloud` — получение облака слов
- `GET /health` — проверка доступности (без `/api/v1`)

## 📁 Project Structure

```
.
├── api-files/                    # OpenAPI specifications
│   ├── openapi.yaml             # API Gateway spec
│   ├── file-storing.yaml        # File Storing spec
│   ├── file-analisys.yaml       # File Analysis spec
│   └── embedding-service.yaml   # Embedding Service spec
├── api-gateway/
│   ├── cmd/main.go
│   └── internal/
│       ├── api/generated/       
│       ├── api/handler/         
│       ├── clients/             
│       │   ├── filestoring/
│       │   └── fileanalysis/
│       ├── config/
│       ├── db/
│       └── store/
├── file-storing/
│   ├── cmd/main.go
│   └── internal/
│       ├── api/generated/
│       ├── api/handler/
│       ├── config/
│       └── service/
├── file-analisys/
│   ├── cmd/main.go
│   └── internal/
│       ├── api/generated/
│       ├── api/handler/
│       ├── clients/
│       │   ├── embedding/
│       │   └── filestoring/
│       ├── filequeue/
│       ├── qdrant/
│       └── reports/
├── embedding-service/
│   ├── cmd/main.go
│   └── internal/
│       ├── api/generated/
│       ├── api/handler/
│       └── yandexembd/
├── docker-compose.yaml
├── scripts/
├── tests/
├── tests_files/
└── README.md
```

## Кодогенерация

### Генерация серверов/клиентов из OpenAPI
```bash
chmod +x scripts/code-generation.sh
./scripts/code-generation.sh
```

### Проверка OpenAPI (Redocly)
```bash
chmod +x scripts/open-api-files-checker.sh
./scripts/open-api-files-checker.sh
```

## 🧩 CI/CD

### CI (GitHub Actions, `.github/workflows/CI.yml`)

- Триггеры: `push` и `pull_request` в ветки `main` и `dev`.
- `api-lint`: Redocly lint для всех OpenAPI файлов.
- `tests`: `gofmt` (проверка), `go vet`, `go test` для `api-gateway`, `file-storing`, `file-analisys`, `embedding-service`.
- `python-unit`: `python -m unittest discover -s tests -p "test_*.py" -v`.

### CD (GitHub Actions, `.github/workflows/CD.yml`)

- Вызывается из CI на `push`.
- Деплой по ветке:
  - `main` → `/opt/anti-plagiarism/prod`
  - другие ветки → `/opt/anti-plagiarism/dev`
- SSH ключ берется из `DEPLOY_SSH_KEY_B64` (base64).
- На сервере создаются env-файлы из секретов `S3_ENV` и `YANDEX_CLOUD_ENV`.
- Запуск: `docker compose -f docker-compose.yaml up -d --build`.
