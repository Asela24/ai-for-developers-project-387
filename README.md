# EasyBook

**Демо: https://easybook-zcmj.onrender.com** (бесплатный инстанс Render засыпает при простое, первое открытие может занять до минуты)

[![hexlet-check](https://github.com/Asela24/ai-for-developers-project-387/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/Asela24/ai-for-developers-project-387/actions)

Разработайте совместно с ИИ сервис для бронирования звонков

Учебный проект Хекслета: https://ru.hexlet.io/programs/ai-for-developers
Как это должно работать: https://files.hexlet.app/a/2ipc5m

## Стек

- Typescript, vite. shadcn/ui, react, tanstack router
- Testing: vitest
- Docker
- Nodejs for backend
- SDK is @hey-api/openapi-ts
-  TypeSpec → OpenAPI
  ├─ фронт: openapi-typescript + openapi-fetch (или hey-api / orval)
  └─ бек:   Fastify + fastify-openapi-glue + openapi-typescript для типов
            + Schemathesis в CI


## Установка

```bash
git clone https://github.com/Asela24/ai-for-developers-project-387.git
cd ai-for-developers-project-387
mise install
pnpm install
```

## Использование

```bash
mise run dev
```

Приложение: http://localhost:5173. API проксируется под `/api`.

## Docker

Один образ из корневого `Dockerfile`: сервер отдаёт собранный фронтенд и API под `/api` на порту из переменной `PORT`.

```bash
docker build -t easybook .
docker run --rm -e PORT=8080 -p 8080:8080 easybook
```

Приложение: http://localhost:8080.

## Данные

Данные хранятся в памяти сервера и **сбрасываются при каждом перезапуске**: брони пропадают, типы событий возвращаются к стандартным. На бесплатном тарифе Render инстанс засыпает после простоя, и пробуждение — это тоже перезапуск.

## Деплой

Публичная ссылка: https://easybook-zcmj.onrender.com

Приложение развёрнуто на [Render](https://render.com) как Web Service (Docker, бесплатный тариф) из ветки `main`, каждый коммит в `main` деплоится автоматически. `PORT` Render задаёт сам.

## MCP

В `.mcp.json` лежит проектная конфигурация MCP для Claude Code: [Render MCP](https://render.com/docs/mcp-server) для управления деплоем, логов и статуса сервиса. Ключа в файле нет, он берётся из переменной окружения.

1. Создайте API key в Render: **Account Settings → API Keys → Create API Key**.
2. Добавьте его в окружение, например в `~/.zshrc`, не в репозиторий:
   ```bash
   export RENDER_API_KEY=rnd_...
   ```
3. Запустите Claude Code в корне репозитория и разрешите проектный сервер `render`. `/mcp` покажет его статус.
4. Выберите workspace: «Set my Render workspace to <имя>».

## ИИ-агент в issues и PR (`@claude`)

Воркфлоу [`.github/workflows/claude.yml`](.github/workflows/claude.yml) запускает [Claude Code](https://github.com/anthropics/claude-code-action) прямо в GitHub: агент берёт задачу из комментария, работает на свежем раннере и отвечает в том же issue или PR.

- **Событие:** новый комментарий в issue или PR (`issue_comment` и `pull_request_review_comment`, только `types: [created]`).
- **Команда (mentions):** только `@claude`. Других триггеров нет: `/claude`, назначение исполнителя и метки не настроены.
- **Кто может запустить:** только люди с ролью OWNER, MEMBER или COLLABORATOR. Комментарии ботов игнорируются, PR из форков отклоняются до использования секретов.
- **Модель:** `claude-opus-5-5`, авторизация через подписку Claude (секрет `CLAUDE_CODE_OAUTH_TOKEN` в GitHub Secrets).
- **Назначение:** отвечать на вопросы по коду, ревьюить PR, разбирать обращения, вести задачи по процессу первого проекта. В `.claude/skills/` лежат скиллы `triage`, `to-spec`, `to-tickets`, `implement-spec` и `tdd` (из [mattpocock/skills](https://github.com/mattpocock/skills)). Настройки трекера берутся из `docs/agents/` через `AGENTS.md`.
- **Результат:** один комментарий агента, который обновляется по ходу работы. Изменения в коде агент пушит в ветку `claude/…` и даёт ссылку на создание PR. Сам PR не создаёт и в `main` не мержит. Прогон виден во вкладке Actions.
- **Ограничения:** одновременно работает не больше одного агента на весь репозиторий (`concurrency` на уровне job, `cancel-in-progress: false`): новый запрос ждёт, пока закончится текущий. У GitHub в очереди одно место, поэтому если пришло несколько запросов, ждёт только последний. Тайм-аут 30 минут.
- **Решение по share:** share выключен, публичных ссылок на сессию нет. Ход работы виден в комментарии агента и в логе прогона в Actions.

Примеры:

```text
@claude объясни, как устроена проверка пересечений броней
@claude разбери обращение по скиллу triage, предложи следующий шаг, код пока не меняй
@claude /to-spec по обсуждению выше
@claude /to-tickets #12
@claude /implement-spec #12
```

### Автотриаж новых issue

Воркфлоу [`.github/workflows/claude-triage.yml`](.github/workflows/claude-triage.yml) запускается событием `issues: opened`, без комментария. Инструкция лежит в `prompt` воркфлоу: запустить скилл `triage` на новом issue. Агент пересказывает обращение в терминах глоссария, задаёт вопросы, если данных не хватает (метка `needs-info`), и предлагает следующий шаг. Код не меняет, метку `ready-for-agent` не ставит: брать ли задачу в работу, решает человек.

- **Что пропускается:** issue от ботов (тикеты, которые `claude[bot]` создал через `to-tickets`) и issue, у которых при создании уже есть метка триажа (`ready-for-agent`, `needs-info`, `wontfix`). Метки описаны в [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md).
- **Кто может запустить:** автор issue с ролью OWNER, MEMBER или COLLABORATOR.
- **Инструменты агента:** чтение кода и `gh issue view/list/comment/edit`. Без `git`, `pnpm` и `mise`.
- **Повторный разбор** после ответов автора: комментарий `@claude разбери обращение по скиллу triage` в том же issue.

### GitHub App

На репозиторий установлено [Claude GitHub App](https://github.com/apps/claude). Воркфлоу обменивает OIDC-токен прогона на короткоживущий токен приложения. Этот токен действует только в этом репозитории и только до конца прогона. От имени `claude[bot]` агент комментирует, пушит ветки и работает с issues. Собственный `GITHUB_TOKEN` прогона остаётся только на чтение.

### Отличие от OpenCode

Сначала в проекте был агент [OpenCode](https://opencode.ai/docs/github/) (`.github/workflows/opencode.yml`, issue #1). Его заменил Claude Code с теми же сценариями: ответы в issue/PR и скиллы `to-spec` → `to-tickets` → `implement-spec`. Различия:

| | OpenCode (было) | Claude Code (сейчас) |
| --- | --- | --- |
| Команда | `/oc`, `/opencode` | `@claude` |
| GitHub App | OpenCode App | Claude GitHub App (`claude[bot]`) |
| Модель | `opencode/big-pickle` | `claude-opus-5-5` |
| Ключ в Secrets | `OPENCODE_API_KEY` | `CLAUDE_CODE_OAUTH_TOKEN` (подписка Claude) |
| Инструкции проекта | читает `AGENTS.md` напрямую | читает `CLAUDE.md`, который подключает `AGENTS.md` |
| Скиллы | из окружения агента | закоммичены в `.claude/skills/`, поэтому есть на свежем раннере |
| Права агента | полный набор инструментов | только явно разрешённые команды (`gh`, `pnpm`, `mise run`, `git`) |
| Результат | сам открывает PR | пушит ветку `claude/…` и даёт ссылку на создание PR |
| Share | может публиковать ссылку на сессию | публичных ссылок нет, лог только в Actions |
| PR из форков | не проверялись | отклоняются до использования секретов |

## Pull request

Описание PR заполняется по шаблону [`.github/pull_request_template.md`](.github/pull_request_template.md): что и зачем со ссылкой `Refs #N` на тикет, выполненные проверки, уровень риска и способ отката. GitHub подставляет шаблон в каждый новый PR, в том числе созданный по ссылке от `@claude`.

---

<details>
<summary>Автоматические тесты Хекслета</summary>

Тесты запускаются на каждый коммит. За запуск отвечает файл `.github/workflows/hexlet-check.yml` — не удаляйте и не переименовывайте ни его, ни репозиторий.

</details>

## О Хекслете

[Хекслет](https://ru.hexlet.io/) — школа программирования: авторские программы обучения с практикой, поддержкой наставников и реальными проектами, которые остаются в резюме. Этот репозиторий — один из таких проектов.
