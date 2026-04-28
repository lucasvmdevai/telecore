# Telecore Scaffold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the Telecore monolith — Phoenix 1.8 with full email/password auth, hybrid LiveView + JSON API, and a clean path to a future React split.

**Architecture:** WSL Ubuntu hosts Erlang/OTP 27 + Elixir 1.18 via asdf. PostgreSQL is installed natively in Ubuntu. The Phoenix app exposes both LiveView/HTML routes (cookie-based session auth) and `/api/v1/*` JSON routes (Bearer-token auth). Both code paths call the same `Telecore.Accounts` context functions — business logic never lives in controllers or LiveViews.

**Tech Stack:** Erlang/OTP 27, Elixir 1.18, Phoenix 1.8 (LiveView + Tailwind + esbuild defaults), PostgreSQL (native), Ecto, asdf. Dev tooling: credo, dialyxir, ex_machina, mox.

**Reference spec:** `docs/superpowers/specs/2026-04-28-telecore-scaffold-design.md`

**Plan location note:** This plan is currently on the Windows side (`C:\Users\lucas\projects\telecore\docs\...`). Phase 2 includes a step that moves the entire `docs/` tree into the WSL project (`~/projects/telecore/docs/`) before the first git commit. Subsequent phases assume you are working inside `~/projects/telecore` in Ubuntu.

**Execution environment:**
- **User runs**: Phase 0 in PowerShell (admin) and the Ubuntu first-boot setup. These cannot be automated (reboot, password prompts).
- **Agent runs**: Phases 1–5 inside Ubuntu/WSL. From a Windows host, an agent can execute these via `wsl -e bash -lc '<command>'` once Phase 0 is done.

---

## Phase 0 — WSL Ubuntu provisioning (user-driven)

### Task 0.1: Install WSL Ubuntu

**Files:** none

- [ ] **Step 1: User opens PowerShell as Administrator and runs:**

```powershell
wsl --install -d Ubuntu
```

Expected: Ubuntu downloads and registers as a WSL distro. May require a reboot.

- [ ] **Step 2: After reboot, Ubuntu launches automatically and prompts for username/password.**

User chooses a UNIX username (e.g., `lucas`) and a password. Note them — they're used for `sudo`.

- [ ] **Step 3: Verify WSL is up.**

Run in PowerShell:
```powershell
wsl --list --verbose
```
Expected output includes `Ubuntu` with `STATE = Running` (or `Stopped` — both fine).

- [ ] **Step 4: Verify shell access.**

Run in PowerShell:
```powershell
wsl -d Ubuntu -e bash -lc 'whoami && lsb_release -d'
```
Expected: prints UNIX username + `Description: Ubuntu 24.04 ...` (or whatever LTS is current).

> **No commit at this phase** — nothing in version control yet.

---

## Phase 1 — System dependencies inside Ubuntu

> All commands in this phase run inside Ubuntu/WSL. From PowerShell on Windows, prefix with `wsl -d Ubuntu -e bash -lc '...'`. From an Ubuntu shell, run them directly.

### Task 1.1: Install Erlang build dependencies

**Files:** none (system-level)

- [ ] **Step 1: Update apt and install build deps.**

```bash
sudo apt update
sudo apt install -y \
  build-essential autoconf m4 \
  libncurses-dev libssl-dev libssh-dev \
  unixodbc-dev libxml2-utils libwxgtk3.2-dev \
  curl git inotify-tools
```

Expected: all packages install without error. If `libwxgtk3.2-dev` is unavailable on the Ubuntu version, fall back to `libwxgtk3.0-gtk3-dev`.

- [ ] **Step 2: Verify.**

```bash
gcc --version && git --version && curl --version | head -1
```
Expected: prints versions, no errors.

### Task 1.2: Install asdf

**Files:**
- Modify: `~/.bashrc`

- [ ] **Step 1: Download asdf v0.16+ binary.**

```bash
ASDF_VERSION="v0.16.7"
curl -L "https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/asdf-${ASDF_VERSION}-linux-amd64.tar.gz" \
  | tar xz -C /tmp
sudo mv /tmp/asdf /usr/local/bin/asdf
```

> If `v0.16.7` is no longer the latest, check https://github.com/asdf-vm/asdf/releases and substitute the current stable tag. The Go-rewrite binary works the same way.

- [ ] **Step 2: Verify.**

```bash
asdf --version
```
Expected: prints `0.16.x` or higher.

- [ ] **Step 3: Add asdf shims to PATH in `~/.bashrc`.**

```bash
cat >> ~/.bashrc <<'EOF'

# asdf
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
EOF
```

- [ ] **Step 4: Reload shell config.**

```bash
source ~/.bashrc
```

### Task 1.3: Install Erlang/OTP 27 via asdf

**Files:** none

- [ ] **Step 1: Add Erlang plugin.**

```bash
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
```

- [ ] **Step 2: List available 27.x versions and pick the latest.**

```bash
asdf list-all erlang | grep '^27\.' | tail -5
```
Expected: a list of patch versions like `27.0`, `27.1`, `27.1.2`, `27.2`. Pick the highest non-rc version. **Record it** — we'll pin it in `.tool-versions` later. Example: `27.2`.

- [ ] **Step 3: Install Erlang. (Slow — 5–15 min, compiles from source.)**

Replace `27.2` with the version chosen in Step 2:
```bash
asdf install erlang 27.2
```
Expected: ends with `The installation was successful` (or similar).

- [ ] **Step 4: Set as global default and verify.**

```bash
asdf set --home erlang 27.2
erl -eval 'io:format("~s~n", [erlang:system_info(otp_release)]), halt().' -noshell
```
Expected: prints `27`.

### Task 1.4: Install Elixir 1.18 via asdf

**Files:** none

- [ ] **Step 1: Add Elixir plugin.**

```bash
asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git
```

- [ ] **Step 2: List available 1.18-otp-27 builds and pick the latest.**

```bash
asdf list-all elixir | grep '^1\.18.*otp-27' | tail -5
```
Expected: list like `1.18.0-otp-27`, `1.18.1-otp-27`. Pick the highest. Record it.

- [ ] **Step 3: Install Elixir. (Fast — under 1 min.)**

Replace with version from Step 2:
```bash
asdf install elixir 1.18.1-otp-27
```

- [ ] **Step 4: Set global default and verify.**

```bash
asdf set --home elixir 1.18.1-otp-27
elixir --version
```
Expected: prints both Erlang and Elixir versions.

### Task 1.5: Install Hex, Rebar, and Phoenix archive

**Files:** none

- [ ] **Step 1: Install Hex (Elixir package manager) and Rebar (Erlang build tool).**

```bash
mix local.hex --force
mix local.rebar --force
```
Expected: both print confirmation lines.

- [ ] **Step 2: Install the Phoenix project generator archive.**

```bash
mix archive.install hex phx_new --force
```
Expected: ends with `* creating ... phx_new-X.Y.Z`. Record the version (should be `1.8.x`).

- [ ] **Step 3: Verify.**

```bash
mix phx.new --version
```
Expected: prints `Phoenix installer vX.Y.Z` matching the version installed.

### Task 1.6: Install and configure PostgreSQL

**Files:** none (system-level)

- [ ] **Step 1: Install Postgres.**

```bash
sudo apt install -y postgresql postgresql-contrib
```

- [ ] **Step 2: Start the service. (WSL doesn't auto-start services across restarts in older configs — start it manually.)**

```bash
sudo service postgresql start
sudo service postgresql status
```
Expected: status reports `online` or `active`.

> **Heads-up:** every time you stop WSL (`wsl --shutdown`) and start it again, you'll need to re-run `sudo service postgresql start`. To make this automatic, you can later add `[boot] command = "service postgresql start"` to `/etc/wsl.conf` — but that's an optimization, not required for this plan.

- [ ] **Step 3: Set the `postgres` user password to `postgres` (dev only — matches Phoenix `dev.exs` default).**

```bash
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
```
Expected: prints `ALTER ROLE`.

- [ ] **Step 4: Verify connection works with the new password.**

```bash
PGPASSWORD=postgres psql -h localhost -U postgres -c '\l'
```
Expected: lists databases (`postgres`, `template0`, `template1`).

> **No commit yet** — system-level setup only.

---

## Phase 2 — Phoenix scaffold and first commit

### Task 2.1: Generate the Phoenix project

**Files:**
- Create: `~/projects/telecore/` (entire scaffold tree generated by `mix phx.new`)

- [ ] **Step 1: Create projects directory and run generator.**

```bash
mkdir -p ~/projects
cd ~/projects
mix phx.new telecore --binary-id
```

When prompted `Fetch and install dependencies? [Yn]`, answer **`Y`**.

Expected: scaffold generated, deps fetched, prints next-steps message ending with `cd telecore` and `mix phx.server`.

- [ ] **Step 2: Verify scaffold structure.**

```bash
cd ~/projects/telecore
ls
```
Expected: shows `lib/`, `config/`, `priv/`, `assets/`, `test/`, `mix.exs`, `.formatter.exs`, `.gitignore`, `README.md`.

### Task 2.2: Create `.tool-versions` and migrate spec/plan into project

**Files:**
- Create: `~/projects/telecore/.tool-versions`
- Move: `docs/superpowers/specs/2026-04-28-telecore-scaffold-design.md` and `docs/superpowers/plans/2026-04-28-telecore-scaffold.md` into the project from the Windows side.

- [ ] **Step 1: Pin Erlang/Elixir versions for reproducibility.**

Create `~/projects/telecore/.tool-versions` with the versions chosen in Tasks 1.3 and 1.4:
```
erlang 27.2
elixir 1.18.1-otp-27
```
(Use the actual versions you installed.)

- [ ] **Step 2: Verify asdf picks it up.**

```bash
cd ~/projects/telecore
asdf current
```
Expected: shows the pinned versions and indicates they come from `.tool-versions` in the current dir.

- [ ] **Step 3: Copy spec + plan from Windows side into the project.**

The spec and plan currently live at `C:\Users\lucas\projects\telecore\docs\` on Windows. Inside WSL that path is `/mnt/c/Users/lucas/projects/telecore/docs/`. Copy them in:

```bash
mkdir -p ~/projects/telecore/docs
cp -r /mnt/c/Users/lucas/projects/telecore/docs/superpowers ~/projects/telecore/docs/
ls ~/projects/telecore/docs/superpowers/specs ~/projects/telecore/docs/superpowers/plans
```
Expected: both files (`...-design.md` and `...-scaffold.md`) appear in their folders.

### Task 2.3: Verify dev dependencies and create the database

**Files:** none

- [ ] **Step 1: Create the dev database.**

```bash
cd ~/projects/telecore
mix ecto.create
```
Expected: `The database for Telecore.Repo has been created`.

- [ ] **Step 2: Sanity-check that Phoenix boots.**

```bash
mix phx.server &
PHX_PID=$!
sleep 5
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4000
kill $PHX_PID
wait $PHX_PID 2>/dev/null
```
Expected: prints `200`. (If it prints `000`, server failed to start — check the captured output.)

### Task 2.4: First commit

**Files:**
- Create: `~/projects/telecore/.git/` (via `git init`)

- [ ] **Step 1: Init git and verify `.gitignore` from `mix phx.new` is present.**

```bash
cd ~/projects/telecore
git init -b main
cat .gitignore | head -20
```
Expected: shows the standard Phoenix `.gitignore` (deps, _build, node_modules, etc.).

- [ ] **Step 2: Stage everything except deps/_build (already excluded by `.gitignore`).**

```bash
git add -A
git status
```
Expected: lists all scaffold files plus `.tool-versions` and `docs/`. No `deps/`, no `_build/`, no `node_modules/`.

- [ ] **Step 3: Commit.**

```bash
git commit -m "chore: initial mix phx.new --binary-id

Scaffold generated with Phoenix 1.8.x, Elixir 1.18.x, OTP 27.
Pinned versions in .tool-versions. Includes spec and plan docs.
"
```
Expected: commit succeeds. `git log --oneline` shows one commit.

---

## Phase 3 — Authentication via `phx.gen.auth`

### Task 3.1: Generate auth scaffolding

**Files:**
- Create: ~30 files generated by `phx.gen.auth` (controllers, LiveViews, schemas, migrations, tests)

- [ ] **Step 1: Run the generator.**

```bash
cd ~/projects/telecore
mix phx.gen.auth Accounts User users --binary-id
```

When prompted about hashing library, accept the default (`bcrypt_elixir`).
When prompted about the live option, accept the default (LiveView-based registration).

Expected: prints a long list of files created and ends with instructions including `mix deps.get`, `mix ecto.migrate`.

- [ ] **Step 2: Fetch the new dependencies (`bcrypt_elixir`, `swoosh`, etc.).**

```bash
mix deps.get
```
Expected: fetches and compiles new deps without errors.

- [ ] **Step 3: Run the migration.**

```bash
mix ecto.migrate
```
Expected: shows `create users` and `create users_tokens` (or similar) migrations applied.

### Task 3.2: Smoke-test auth — registration

**Files:** none (manual verification)

- [ ] **Step 1: Boot the server.**

```bash
cd ~/projects/telecore
mix phx.server
```

- [ ] **Step 2: From a browser on Windows, open http://localhost:4000/users/register.**

Phoenix 1.8 may use `/users/register` or `/users/log_in` with magic-link flow — whichever route the generator output mentions, that's the entry point.

Register a test user (e.g., `test@example.com` / `passwordpassword`).

Expected: registration succeeds; you land on a page acknowledging the user. (In dev, confirmation emails are written to the local mailbox at `/dev/mailbox` or printed to the server log — depending on what `gen.auth` set up.)

- [ ] **Step 3: Stop the server with Ctrl+C twice.**

### Task 3.3: Verify test suite passes

**Files:** none

- [ ] **Step 1: Run the test suite.**

```bash
cd ~/projects/telecore
mix test
```
Expected: **all** tests pass (the generator adds many auth-related tests). If anything fails, fix before moving on — do not skip.

### Task 3.4: Second commit

- [ ] **Step 1: Stage and commit.**

```bash
git add -A
git status   # confirm new files only — no surprise edits
git commit -m "feat(auth): mix phx.gen.auth Accounts User users --binary-id

Registration, login, logout, password reset, email confirmation.
Cookie-based session auth for the LiveView/HTML path.
"
```
Expected: commit succeeds.

---

## Phase 4 — Quality tooling (credo, dialyxir, ex_machina, mox)

### Task 4.1: Add tooling deps to `mix.exs`

**Files:**
- Modify: `~/projects/telecore/mix.exs` (the `defp deps` function)

- [ ] **Step 1: Read the current `defp deps do` block.**

```bash
cd ~/projects/telecore
grep -n 'defp deps' mix.exs
```
Note the line range so the next edit is precise.

- [ ] **Step 2: Add the four new entries to the `deps` list.**

Inside the list returned by `defp deps do`, append (before the closing `]`):

```elixir
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_machina, "~> 2.7", only: :test},
      {:mox, "~> 1.1", only: :test}
```

Make sure existing trailing commas are correct after the merge.

- [ ] **Step 3: Add Dialyzer config to the `project/0` function.**

In the `def project do` keyword list, add (or extend) a `:dialyzer` key:

```elixir
      dialyzer: [
        plt_local_path: "priv/plts/local.plt",
        plt_core_path: "priv/plts/core.plt",
        flags: [:error_handling, :unknown, :unmatched_returns]
      ],
```

- [ ] **Step 4: Fetch the new deps.**

```bash
mix deps.get
```
Expected: fetches `credo`, `dialyxir`, `ex_machina`, `mox` (and their deps).

### Task 4.2: Generate `.credo.exs` with sensible defaults

**Files:**
- Create: `~/projects/telecore/.credo.exs`

- [ ] **Step 1: Generate the default config.**

```bash
mix credo gen.config
```
Expected: creates `.credo.exs` and prints a confirmation.

- [ ] **Step 2: Run credo to confirm it works (may report findings — that's fine here, we'll address in Step 4 of this task).**

```bash
mix credo --strict
```
Expected: runs to completion. Output may flag refactoring suggestions in the auth-generated code; we'll triage next.

- [ ] **Step 3: If credo reports issues only in `phx.gen.auth`-generated files (not in your own code), suppress them for those files.**

Add to `.credo.exs` inside the `checks: %{enabled: [...]}` block (or as a top-level `excluded` filter):

```elixir
        # Auth scaffolding is generator output — don't lint it.
        {Credo.Check.Readability.ModuleDoc, files: %{excluded: ["lib/telecore/accounts/", "lib/telecore_web/controllers/user_*.ex", "lib/telecore_web/user_*.ex"]}},
```

Re-run `mix credo --strict`. Expected: 0 issues. If issues remain in non-auth files, fix them inline (they'll be in the few files we authored ourselves).

### Task 4.3: Build the Dialyzer PLT

**Files:**
- Create: `~/projects/telecore/priv/plts/core.plt`, `priv/plts/local.plt`

- [ ] **Step 1: Make the PLT directory and add `.gitkeep`/`.gitignore` entries.**

```bash
mkdir -p priv/plts
echo '*.plt' > priv/plts/.gitignore
echo '*.plt.hash' >> priv/plts/.gitignore
echo '!.gitignore' >> priv/plts/.gitignore
```

- [ ] **Step 2: Build the PLT (slow on first run — 5–10 min).**

```bash
mix dialyzer --plt
```
Expected: builds core + local PLT files. Subsequent runs are incremental.

- [ ] **Step 3: Run Dialyzer to confirm clean.**

```bash
mix dialyzer
```
Expected: `done (passed successfully)` or a small number of warnings only in framework-side code. If real issues are reported in `lib/telecore/`, fix them before continuing.

### Task 4.4: Third commit

- [ ] **Step 1: Stage and commit.**

```bash
git add -A
git status
git commit -m "chore: add credo, dialyxir, ex_machina, mox + configs

Quality tooling. mix credo --strict and mix dialyzer both run clean.
PLT directory excluded from version control.
"
```

---

## Phase 5 — JSON API layer (`/api/v1`)

> **Phase 5 prerequisite check:** Before starting, inspect the auth artifacts that `phx.gen.auth` generated. The exact file names and module structure can vary between Phoenix 1.8 patch versions. Run:
>
> ```bash
> ls lib/telecore/accounts/
> ls lib/telecore_web/controllers/ | grep -i user
> ls lib/telecore_web/ | grep -i auth
> ```
>
> The plan below assumes:
> - `lib/telecore/accounts/user_token.ex` exists with a `contexts/0`-style listing or similar token-validation logic.
> - `lib/telecore/accounts.ex` has `get_user_by_email_and_password/2`.
>
> If the generator produced different names, **adapt the references in the tasks below to match what's on disk**. The shape of the work doesn't change — only the names.

### Task 5.1: Add API token support to `Telecore.Accounts.UserToken`

**Files:**
- Modify: `~/projects/telecore/lib/telecore/accounts/user_token.ex`

- [ ] **Step 1: Read the existing file to see its current shape.**

```bash
cat lib/telecore/accounts/user_token.ex
```
Note the existing functions and the rand/hash helpers (typically `:crypto.strong_rand_bytes/1`, `:crypto.hash/2`).

- [ ] **Step 2: Add API-specific token functions at the bottom of the module (before the final `end`).**

```elixir
  @api_token_validity_in_days 60

  @doc """
  Generates an opaque Bearer token for API auth.

  Returns `{plaintext_token, %UserToken{}}`. The plaintext is shown to the
  client exactly once; only the hash is persisted.
  """
  def build_api_token(user) do
    token = :crypto.strong_rand_bytes(32)
    hashed = :crypto.hash(:sha256, token)

    {Base.url_encode64(token, padding: false),
     %UserToken{
       token: hashed,
       context: "api",
       user_id: user.id
     }}
  end

  @doc """
  Returns the query that fetches the user owning a given API token, or `nil`.
  """
  def verify_api_token_query(plaintext_token) do
    case Base.url_decode64(plaintext_token, padding: false) do
      {:ok, raw} ->
        hashed = :crypto.hash(:sha256, raw)

        query =
          from token in __MODULE__,
            join: user in assoc(token, :user),
            where:
              token.token == ^hashed and
                token.context == "api" and
                token.inserted_at > ago(@api_token_validity_in_days, "day"),
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc "Query that finds the API token row by plaintext (used to delete on logout)."
  def by_api_token_query(plaintext_token) do
    case Base.url_decode64(plaintext_token, padding: false) do
      {:ok, raw} ->
        hashed = :crypto.hash(:sha256, raw)

        {:ok,
         from token in __MODULE__,
           where: token.token == ^hashed and token.context == "api"}

      :error ->
        :error
    end
  end
```

> If the generated `UserToken` already imports `Ecto.Query`, the `from` macro is available. If not, add `import Ecto.Query, only: [from: 2]` at the top of the module (next to existing imports).

### Task 5.2: Extend `Telecore.Accounts` with API token functions

**Files:**
- Modify: `~/projects/telecore/lib/telecore/accounts.ex`

- [ ] **Step 1: Read the existing context to find a good insertion point (typically near other token-related functions).**

```bash
grep -n 'session_token\|reset_password_token\|UserToken' lib/telecore/accounts.ex | head -20
```

- [ ] **Step 2: Add three public functions to the module (place them near the existing token functions).**

```elixir
  @doc """
  Creates and persists a new API Bearer token for the given user.

  Returns the plaintext token (shown to the client exactly once).
  """
  def create_user_api_token(%User{} = user) do
    {token, user_token} = UserToken.build_api_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Looks up the user owning the given plaintext API token.

  Returns the user struct or `nil` if the token is invalid or expired.
  """
  def fetch_user_by_api_token(plaintext_token) when is_binary(plaintext_token) do
    case UserToken.verify_api_token_query(plaintext_token) do
      {:ok, query} -> Repo.one(query)
      :error -> nil
    end
  end

  def fetch_user_by_api_token(_), do: nil

  @doc "Revokes (deletes) an API token, used for logout."
  def delete_user_api_token(plaintext_token) when is_binary(plaintext_token) do
    case UserToken.by_api_token_query(plaintext_token) do
      {:ok, query} -> Repo.delete_all(query)
      :error -> {0, nil}
    end
  end
```

### Task 5.3: Write the failing test for `Accounts` API token functions

**Files:**
- Modify: `~/projects/telecore/test/telecore/accounts_test.exs`

- [ ] **Step 1: Append a `describe` block to the existing `accounts_test.exs`.**

Add at the end of the existing file (before the final `end`):

```elixir
  describe "API tokens" do
    alias Telecore.Accounts

    setup do
      # If `phx.gen.auth` produced a `user_fixture/0` in this file or in
      # `Telecore.AccountsFixtures`, prefer that. Adjust if needed.
      user = Telecore.AccountsFixtures.user_fixture()
      %{user: user}
    end

    test "create_user_api_token/1 returns a plaintext token bound to the user", %{user: user} do
      token = Accounts.create_user_api_token(user)

      assert is_binary(token)
      assert byte_size(token) > 32

      assert %Telecore.Accounts.User{id: id} = Accounts.fetch_user_by_api_token(token)
      assert id == user.id
    end

    test "fetch_user_by_api_token/1 returns nil for garbage input" do
      assert is_nil(Accounts.fetch_user_by_api_token("not-a-token"))
      assert is_nil(Accounts.fetch_user_by_api_token(""))
    end

    test "delete_user_api_token/1 invalidates the token", %{user: user} do
      token = Accounts.create_user_api_token(user)
      assert %Telecore.Accounts.User{} = Accounts.fetch_user_by_api_token(token)

      Accounts.delete_user_api_token(token)
      assert is_nil(Accounts.fetch_user_by_api_token(token))
    end
  end
```

- [ ] **Step 2: Run the test to verify failure mode.**

```bash
mix test test/telecore/accounts_test.exs
```
Expected: the new tests fail or error. (If they pass at this point, something is off — investigate.)

- [ ] **Step 3: Run the test again — they should now pass given the implementation in Tasks 5.1 and 5.2.**

```bash
mix test test/telecore/accounts_test.exs
```
Expected: all tests pass, including the three new ones in `describe "API tokens"`.

> Note: the implementation was already added in 5.1/5.2 because the changes are tightly coupled. If you prefer strict TDD ordering, you can revert the implementation, watch the tests fail, then reapply — but the result is the same.

### Task 5.4: Implement the `ApiAuth` plug

**Files:**
- Create: `~/projects/telecore/lib/telecore_web/plugs/api_auth.ex`

- [ ] **Step 1: Write the plug.**

```elixir
defmodule TelecoreWeb.Plugs.ApiAuth do
  @moduledoc """
  Authenticates an API request using a Bearer token in the Authorization header.

  On success, assigns `:current_user` to the conn. On failure, halts the
  pipeline with a 401 JSON response.
  """
  import Plug.Conn

  alias Telecore.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with [bearer] <- get_req_header(conn, "authorization"),
         {:ok, token} <- extract_token(bearer),
         %Accounts.User{} = user <- Accounts.fetch_user_by_api_token(token) do
      conn
      |> assign(:current_user, user)
      |> assign(:current_api_token, token)
    else
      _ -> unauthorized(conn)
    end
  end

  defp extract_token("Bearer " <> token) when byte_size(token) > 0, do: {:ok, token}
  defp extract_token(_), do: :error

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, ~s({"error":"unauthorized"}))
    |> halt()
  end
end
```

### Task 5.5: Test the `ApiAuth` plug

**Files:**
- Create: `~/projects/telecore/test/telecore_web/plugs/api_auth_test.exs`

- [ ] **Step 1: Write the test.**

```elixir
defmodule TelecoreWeb.Plugs.ApiAuthTest do
  use TelecoreWeb.ConnCase, async: true

  alias Telecore.Accounts
  alias TelecoreWeb.Plugs.ApiAuth

  setup do
    user = Telecore.AccountsFixtures.user_fixture()
    token = Accounts.create_user_api_token(user)
    %{user: user, token: token}
  end

  test "assigns current_user when a valid Bearer token is present", %{
    conn: conn,
    user: user,
    token: token
  } do
    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> token)
      |> ApiAuth.call([])

    assert conn.assigns.current_user.id == user.id
    refute conn.halted
  end

  test "returns 401 when no Authorization header is present", %{conn: conn} do
    conn = ApiAuth.call(conn, [])
    assert conn.status == 401
    assert conn.halted
  end

  test "returns 401 when the token is invalid", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer not-a-valid-token")
      |> ApiAuth.call([])

    assert conn.status == 401
    assert conn.halted
  end

  test "returns 401 when the header is malformed", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Basic abc123")
      |> ApiAuth.call([])

    assert conn.status == 401
    assert conn.halted
  end
end
```

- [ ] **Step 2: Run the plug tests.**

```bash
mix test test/telecore_web/plugs/api_auth_test.exs
```
Expected: all 4 tests pass.

### Task 5.6: Wire the API pipeline and routes in `router.ex`

**Files:**
- Modify: `~/projects/telecore/lib/telecore_web/router.ex`

- [ ] **Step 1: Read the current router to see existing pipelines and scopes.**

```bash
cat lib/telecore_web/router.ex
```

- [ ] **Step 2: Confirm there is a `pipeline :api` block. If not, add one near the existing pipelines:**

```elixir
  pipeline :api do
    plug :accepts, ["json"]
  end
```

- [ ] **Step 3: Add the `:api_authenticated` pipeline immediately after `:api`.**

```elixir
  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug TelecoreWeb.Plugs.ApiAuth
  end
```

- [ ] **Step 4: Add the public and authenticated `/api/v1` scopes near the bottom of the router (above any catch-all error route).**

```elixir
  scope "/api/v1", TelecoreWeb.Api.V1 do
    pipe_through :api

    post "/sessions", SessionController, :create
    post "/users", UserController, :create
  end

  scope "/api/v1", TelecoreWeb.Api.V1 do
    pipe_through :api_authenticated

    delete "/sessions", SessionController, :delete
    get "/users/me", UserController, :me
  end
```

### Task 5.7: Implement `SessionController` (login + logout)

**Files:**
- Create: `~/projects/telecore/lib/telecore_web/controllers/api/v1/session_controller.ex`

- [ ] **Step 1: Write the controller.**

```elixir
defmodule TelecoreWeb.Api.V1.SessionController do
  use TelecoreWeb, :controller

  alias Telecore.Accounts

  def create(conn, %{"email" => email, "password" => password})
      when is_binary(email) and is_binary(password) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %Accounts.User{} = user ->
        token = Accounts.create_user_api_token(user)

        conn
        |> put_status(:created)
        |> json(%{token: token, user: render_user(user)})

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_credentials"})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_credentials"})
  end

  def delete(conn, _params) do
    Accounts.delete_user_api_token(conn.assigns.current_api_token)

    conn
    |> put_status(:no_content)
    |> send_resp(:no_content, "")
  end

  defp render_user(user) do
    %{id: user.id, email: user.email}
  end
end
```

### Task 5.8: Test `SessionController`

**Files:**
- Create: `~/projects/telecore/test/telecore_web/controllers/api/v1/session_controller_test.exs`

- [ ] **Step 1: Write the test.**

```elixir
defmodule TelecoreWeb.Api.V1.SessionControllerTest do
  use TelecoreWeb.ConnCase, async: true

  import Telecore.AccountsFixtures

  alias Telecore.Accounts

  describe "POST /api/v1/sessions" do
    test "returns a token for valid credentials", %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})

      conn =
        post(conn, ~p"/api/v1/sessions", %{
          "email" => user.email,
          "password" => password
        })

      assert %{"token" => token, "user" => %{"id" => id, "email" => email}} =
               json_response(conn, 201)

      assert id == user.id
      assert email == user.email
      assert is_binary(token)
      refute is_nil(Accounts.fetch_user_by_api_token(token))
    end

    test "returns 401 for wrong password", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/api/v1/sessions", %{
          "email" => user.email,
          "password" => "wrongpassword"
        })

      assert %{"error" => "invalid_credentials"} = json_response(conn, 401)
    end

    test "returns 400 when params are missing", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/sessions", %{})
      assert %{"error" => "missing_credentials"} = json_response(conn, 400)
    end
  end

  describe "DELETE /api/v1/sessions" do
    test "revokes the current token", %{conn: conn} do
      user = user_fixture()
      token = Accounts.create_user_api_token(user)

      conn = put_req_header(conn, "authorization", "Bearer " <> token)
      conn = delete(conn, ~p"/api/v1/sessions")

      assert response(conn, 204)
      assert is_nil(Accounts.fetch_user_by_api_token(token))
    end

    test "returns 401 without auth header", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/sessions")
      assert json_response(conn, 401)
    end
  end
end
```

- [ ] **Step 2: Run the tests.**

```bash
mix test test/telecore_web/controllers/api/v1/session_controller_test.exs
```
Expected: 5 tests pass.

> If `valid_user_password/0` doesn't exist in your `AccountsFixtures`, replace with the literal `"hello world!"` or whatever password the fixture uses by default. Check `test/support/fixtures/accounts_fixtures.ex` for the actual helper name.

### Task 5.9: Implement `UserController` (registration + me)

**Files:**
- Create: `~/projects/telecore/lib/telecore_web/controllers/api/v1/user_controller.ex`

- [ ] **Step 1: Write the controller.**

```elixir
defmodule TelecoreWeb.Api.V1.UserController do
  use TelecoreWeb, :controller

  alias Telecore.Accounts

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        token = Accounts.create_user_api_token(user)

        conn
        |> put_status(:created)
        |> json(%{token: token, user: render_user(user)})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_user_params"})
  end

  def me(conn, _params) do
    json(conn, %{user: render_user(conn.assigns.current_user)})
  end

  defp render_user(user) do
    %{id: user.id, email: user.email}
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
```

> If the `phx.gen.auth` output named the registration function differently (e.g., `register_user/1` vs `create_user/1`), update the call accordingly.

### Task 5.10: Test `UserController`

**Files:**
- Create: `~/projects/telecore/test/telecore_web/controllers/api/v1/user_controller_test.exs`

- [ ] **Step 1: Write the test.**

```elixir
defmodule TelecoreWeb.Api.V1.UserControllerTest do
  use TelecoreWeb.ConnCase, async: true

  import Telecore.AccountsFixtures

  alias Telecore.Accounts

  describe "POST /api/v1/users" do
    test "registers a user and returns a token", %{conn: conn} do
      attrs = %{
        "email" => unique_user_email(),
        "password" => valid_user_password()
      }

      conn = post(conn, ~p"/api/v1/users", %{"user" => attrs})

      assert %{"token" => token, "user" => %{"id" => id, "email" => email}} =
               json_response(conn, 201)

      assert email == attrs["email"]
      assert is_binary(token)
      assert %{id: ^id} = Accounts.fetch_user_by_api_token(token)
    end

    test "returns errors when params are invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/users", %{"user" => %{"email" => "bad", "password" => "x"}})
      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "email") or Map.has_key?(errors, "password")
    end

    test "returns 400 when no user params are sent", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/users", %{})
      assert %{"error" => "missing_user_params"} = json_response(conn, 400)
    end
  end

  describe "GET /api/v1/users/me" do
    test "returns the current user when authenticated", %{conn: conn} do
      user = user_fixture()
      token = Accounts.create_user_api_token(user)

      conn = put_req_header(conn, "authorization", "Bearer " <> token)
      conn = get(conn, ~p"/api/v1/users/me")

      assert %{"user" => %{"id" => id, "email" => email}} = json_response(conn, 200)
      assert id == user.id
      assert email == user.email
    end

    test "returns 401 without a token", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/users/me")
      assert json_response(conn, 401)
    end
  end
end
```

- [ ] **Step 2: Run the tests.**

```bash
mix test test/telecore_web/controllers/api/v1/user_controller_test.exs
```
Expected: 5 tests pass.

### Task 5.11: Run the full test suite

**Files:** none

- [ ] **Step 1: Full run.**

```bash
mix test
```
Expected: every test passes (auth tests from `phx.gen.auth` + new API tests). If any pre-existing test broke, fix it before moving on — usually a side-effect of touching `UserToken`.

### Task 5.12: Manual smoke test with curl

**Files:** none

- [ ] **Step 1: Boot server.**

```bash
cd ~/projects/telecore
mix phx.server
```

- [ ] **Step 2: From a separate Ubuntu shell, register a new user and capture the token.**

```bash
TOKEN=$(curl -s -X POST http://localhost:4000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"smoke@test.com","password":"superduperpassword"}}' \
  | jq -r .token)
echo "$TOKEN"
```
Expected: prints a long Base64URL string. (If `jq` is missing: `sudo apt install -y jq`.)

- [ ] **Step 3: Hit the authenticated endpoint.**

```bash
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:4000/api/v1/users/me
```
Expected: `{"user":{"id":"<uuid>","email":"smoke@test.com"}}`.

- [ ] **Step 4: Log out.**

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X DELETE \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:4000/api/v1/sessions
```
Expected: prints `204`.

- [ ] **Step 5: Same `me` request now fails.**

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:4000/api/v1/users/me
```
Expected: prints `401`.

- [ ] **Step 6: Stop the server (Ctrl+C twice).**

### Task 5.13: Run credo and dialyzer one more time

**Files:** none

- [ ] **Step 1: Lint.**

```bash
mix credo --strict
```
Expected: 0 issues.

- [ ] **Step 2: Type check.**

```bash
mix dialyzer
```
Expected: passed successfully.

### Task 5.14: Fourth commit

- [ ] **Step 1: Stage and commit.**

```bash
git add -A
git status
git commit -m "feat(api): add /api/v1 scope with bearer-token auth

POST /api/v1/users (register), POST /api/v1/sessions (login),
DELETE /api/v1/sessions (logout), GET /api/v1/users/me.

Tokens are issued via Telecore.Accounts and validated by the
TelecoreWeb.Plugs.ApiAuth plug, reusing the UserToken schema with
a new 'api' context.
"
```

- [ ] **Step 2: Verify the four-commit history.**

```bash
git log --oneline
```
Expected: 4 commits in this order (newest at top):
1. `feat(api): add /api/v1 scope with bearer-token auth`
2. `chore: add credo, dialyxir, ex_machina, mox + configs`
3. `feat(auth): mix phx.gen.auth Accounts User users --binary-id`
4. `chore: initial mix phx.new --binary-id`

---

## Definition of Done — verification checklist

Run these in order to confirm the scaffold matches the spec.

- [ ] `cd ~/projects/telecore && mix phx.server` starts and serves `http://localhost:4000` (200 on `/`).
- [ ] Registering a user at `/users/register` in a browser succeeds and you can log in.
- [ ] `curl -X POST localhost:4000/api/v1/sessions -H 'Content-Type: application/json' -d '{"email":"...","password":"..."}'` returns 201 with a `token` field for valid credentials.
- [ ] `curl -H 'Authorization: Bearer <token>' localhost:4000/api/v1/users/me` returns 200 with the user.
- [ ] `mix test` passes 100%.
- [ ] `mix credo --strict` reports 0 issues.
- [ ] `mix dialyzer` reports 0 issues.
- [ ] `.tool-versions` is committed and lists the actual Erlang and Elixir versions used.
- [ ] `git log --oneline` shows exactly 4 commits in the order specified above.
