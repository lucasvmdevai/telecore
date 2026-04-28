# Telecore — scaffold inicial (monolito Elixir/Phoenix)

**Data:** 2026-04-28
**Autor:** lucasvmdevai@gmail.com (com Claude)
**Status:** Design aprovado, aguardando review final

---

## Contexto e objetivo

Criar a base de um novo produto chamado **Telecore**. A primeira fase é um monólito Elixir/Phoenix que serve UI e API a partir do mesmo app. Em uma fase futura (não escopada aqui), o front será extraído para uma SPA React separada e o app Phoenix passará a servir somente JSON.

A meta deste documento é descrever o **scaffold inicial** — sem regras de domínio — de forma que a transição futura para arquitetura back/front separada seja simples e previsível.

## Decisões já tomadas (resumo das escolhas)

| Decisão | Escolha | Por quê |
|---|---|---|
| Ambiente | WSL 2 + Ubuntu | Performance e compatibilidade com a comunidade Elixir; alinhado com produção (Linux). |
| Gerência de versões | `asdf` | Padrão da comunidade; `.tool-versions` no repo garante reprodutibilidade. |
| Banco | PostgreSQL via `apt install postgresql` no WSL | Sem container extra; usuário escolheu nativo. |
| Sabor do Phoenix | Híbrido (LiveView + JSON API) desde o dia 1 | Velocidade de UI agora + transição limpa para React depois. |
| Autenticação | `mix phx.gen.auth` completo (registro, login, reset, confirmação) | Mais barato adicionar agora do que retrofit depois. |
| Auth da API | Bearer token via `UserToken` nativo do `phx.gen.auth` | Sem libs extras (sem Guardian, sem JWT) no início. |
| IDs | `--binary-id` (UUID) | Não enumeráveis; melhor pra API pública e front desacoplado. |
| Tooling extra | `credo`, `dialyxir`, `ex_machina`, `mox` | Padrão da comunidade; defaults razoáveis. |

## Arquitetura

```
┌─────────────────────────────┐  ┌─────────────────────────────┐
│  Web (LiveView/HTML)        │  │  Web (JSON API em /api/v1)  │
│  TelecoreWeb.PageLive etc.  │  │  TelecoreWeb.Api.* etc.     │
│  Auth: cookie de sessão     │  │  Auth: Bearer token         │
└──────────────┬──────────────┘  └──────────────┬──────────────┘
               │                                │
               └────────────────┬───────────────┘
                                ▼
                ┌──────────────────────────────┐
                │  Contexts (lógica de negócio)│
                │  Telecore.Accounts, etc.     │
                └──────────────┬───────────────┘
                               ▼
                ┌──────────────────────────────┐
                │  Ecto / PostgreSQL           │
                └──────────────────────────────┘
```

**Regra invariante:** toda lógica de negócio mora nos *contexts* (`Telecore.Accounts`, etc). Tanto o LiveView quanto o controller JSON chamam as **mesmas funções de context** — nenhuma regra duplicada, nenhuma regra dentro de controller/LiveView. Quando o React substituir o LiveView, os contexts ficam intactos.

**Estratégia de auth dupla:**
- Caminho web (LiveView/HTML): sessão por cookie, gerada pelos fluxos padrão do `phx.gen.auth` (magic link em 1.8).
- Caminho API (`/api/v1`): token Bearer no header `Authorization`. O token é emitido por `POST /api/v1/sessions` e armazenado/validado via o schema `UserToken` que o `phx.gen.auth` já cria — adiciona-se um contexto `"api"` à lista de contextos suportados pelo schema.
- O context `Telecore.Accounts` expõe `register_user_with_password/1` (criada nesse scaffold) que compõe `User.email_changeset/2` + `User.password_changeset/3` num único insert. O `register_user/1` original (só email, usado pela LiveView de magic link) fica intacto.
- Ambos os caminhos compartilham `Telecore.Accounts.get_user_by_email_and_password/2`.

## Ambiente e versões

### Pré-requisitos a instalar (uma vez)

1. **WSL Ubuntu** — `wsl --install -d Ubuntu` em PowerShell admin (requer reboot e criação de usuário/senha no primeiro boot).
2. **Libs nativas do Erlang** (apt):
   `build-essential autoconf m4 libncurses-dev libssl-dev libssh-dev unixodbc-dev libxml2-utils libwxgtk3.2-dev curl git inotify-tools`
3. **asdf** (versão estável atual — v0.16+). Plugins: `erlang`, `elixir`.
4. **PostgreSQL** — `apt install postgresql postgresql-contrib`. Senha do usuário `postgres` definida como `postgres` (apenas dev).

### Versões pinadas no repo (`.tool-versions`)

- Erlang/OTP: 27.x (última patch estável da série 27 no momento da execução)
- Elixir: 1.18.x-otp-27 (última patch estável)
- Phoenix archive (`phx.new`): 1.8.x

> Patch numbers exatas são resolvidas no momento da execução — o plano de implementação registra a versão usada.

## Sequência de scaffold (ordem cronológica)

1. **Criar projeto:** `mix phx.new telecore --binary-id` em `~/projects/`.
   - Mantém defaults: HTML + LiveView + Tailwind + esbuild + Postgres.
2. **Banco:** `mix ecto.create`.
3. **Auth:** `mix phx.gen.auth Accounts User users --binary-id` → `mix deps.get` → `mix ecto.migrate`.
4. **Tooling:** adicionar em `mix.exs` e `mix deps.get`:
   - `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}`
   - `{:dialyxir, "~> 1.4", only: [:dev], runtime: false}`
   - `{:ex_machina, "~> 2.7", only: :test}`
   - `{:mox, "~> 1.1", only: :test}`
   - Configurar `.credo.exs` com defaults; PLT do Dialyzer pré-construído (`mix dialyzer --plt`).
5. **Camada de API:**
   - Adicionar contexto `"api"` em `Telecore.Accounts.UserToken.contexts/0` (ou equivalente — depende do que `gen.auth` 1.8 gerou).
   - `lib/telecore_web/controllers/api/v1/session_controller.ex` — `POST /api/v1/sessions` (login → token), `DELETE /api/v1/sessions` (logout → revogar token).
   - `lib/telecore_web/controllers/api/v1/user_controller.ex` — `POST /api/v1/users` (registro), `GET /api/v1/users/me` (autenticado).
   - Plug `TelecoreWeb.ApiAuth` — lê `Authorization: Bearer <token>`, busca `UserToken` com contexto `"api"`, popula `conn.assigns.current_user`.
   - Pipeline `:api_authenticated` em `router.ex` que aplica o plug.
   - JSON views correspondentes (`UserJSON`, `SessionJSON`).
   - Testes de controller para os 4 endpoints.
6. **Smoke test manual:**
   - `mix phx.server` → `localhost:4000`.
   - Cadastrar usuário em `/users/register` (browser).
   - `curl -X POST localhost:4000/api/v1/sessions -H "Content-Type: application/json" -d '{"email":"...","password":"..."}'` → 200 com token.
   - `curl -H "Authorization: Bearer <token>" localhost:4000/api/v1/users/me` → 200 com user.

## Estrutura de commits

Granular pra deixar a história legível e fácil de reverter por camada:

1. `chore: initial mix phx.new --binary-id` — saída pristine de `mix phx.new`, mais o spec deste documento (`docs/superpowers/specs/...`).
2. `feat(auth): mix phx.gen.auth Accounts User users` — saída pristine de `gen.auth`.
3. `chore: add credo, dialyxir, ex_machina, mox + configs` — deps + arquivos de config.
4. `feat(api): add /api/v1 scope with bearer-token auth` — controllers, views, plug, rotas, testes.

## Escopo: o que **NÃO** está incluído

- Qualquer domínio de negócio além do `Accounts` gerado por `phx.gen.auth`.
- CI/CD (sem GitHub Actions, sem deploy).
- OAuth, login social, 2FA, RBAC.
- App React (esse é o passo futuro de separação — fica fora desse spec).
- Docker Compose para o app Phoenix em si.
- Observabilidade extra (telemetry padrão do Phoenix é o suficiente).
- Documentação de domínio, ADRs, runbooks.

## Definition of Done

- [ ] `mix phx.server` sobe em `localhost:4000`.
- [ ] Cadastro/login/logout no browser funcionam (`/users/register`, `/users/log_in`).
- [ ] `POST /api/v1/sessions` com credenciais válidas retorna 200 + `{"token": "..."}`.
- [ ] `GET /api/v1/users/me` com token válido retorna 200 + `{"user": {...}}`.
- [ ] `mix test` passa (incluindo os novos testes de controller da API).
- [ ] `mix credo --strict` roda sem erros.
- [ ] `mix dialyzer` roda sem erros (após PLT inicial).
- [ ] `.tool-versions` commitado com versões reais usadas.

## Ponte para o futuro (split back/front)

Quando o React entrar:
- Novo repo (ou subpasta `apps/web`) com Vite + React.
- Front consome `/api/v1/*`. Auth via `POST /api/v1/sessions` → guardar token (HttpOnly cookie ou storage seguro).
- O monólito Phoenix vira API-only: rota raiz `/` deixa de servir LiveView, todas as rotas LiveView/HTML são removidas. Os contexts permanecem inalterados.
- Versão `/api/v2` quando houver breaking changes — `/api/v1` segue funcionando até a SPA migrar.

## Notas de localização do projeto

- **Código-fonte do scaffold:** `~/projects/telecore` dentro do Ubuntu/WSL (filesystem ext4 — performance de I/O decente; rodar Phoenix em `/mnt/c` é sabidamente lento).
- **Este spec:** atualmente em `C:\Users\lucas\projects\telecore\docs\superpowers\specs\` (lado Windows). Será movido/copiado para `~/projects/telecore/docs/superpowers/specs/` durante o passo 1 da implementação, e versionado junto com o primeiro commit.
