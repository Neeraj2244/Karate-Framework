# Karate API Test Framework

[![Regression](https://github.com/Neeraj2244/Karate-Framework/actions/workflows/regression.yml/badge.svg)](https://github.com/Neeraj2244/Karate-Framework/actions/workflows/regression.yml)
[![Java 21](https://img.shields.io/badge/Java-21-blue?logo=openjdk)](https://adoptium.net/)
[![Karate 2.0.10](https://img.shields.io/badge/Karate-2.0.10-green)](https://github.com/karatelabs/karate)

One framework. Four protocols. No Java required.

---

## What is this?

A test automation framework that lets you write API tests in plain English (Gherkin). It handles **REST, GraphQL, WebSocket, and gRPC** — all from the same codebase, with built-in CI/CD and parallel execution.

No boilerplate. No Java classes to write. Just `.feature` files.

---

## Why use it?

Most teams end up maintaining separate tools for each protocol — Postman for REST, custom scripts for GraphQL, ad-hoc clients for WebSocket. This framework replaces all of that with a single DSL, a single CLI, and a single CI pipeline.

---

## Stack

- **[Karate 2.0.10](https://github.com/karatelabs/karate)** — test DSL and runner
- **Java 21** — runtime (Temurin)
- **GitHub Actions** — 5 pre-built CI workflows
- **grpcurl** — gRPC test execution
- **Logback** — CI-safe logging with header masking

---

## What's covered

| Area | What's tested |
|---|---|
| REST | GET, POST, DELETE, file upload, custom headers |
| GraphQL | Queries, mutations, variables, file-based `.graphql` queries |
| WebSocket | Text/binary frames, message filtering, multi-step conversations |
| gRPC | Unary RPC calls, service reflection |
| Auth | Bearer token login, shared across all parallel threads |
| Data-driven | CSV-backed `Scenario Outline` for REST and GraphQL |

---

## Getting started

**Prerequisites:** Java 21, PowerShell, `grpcurl` (gRPC tests only)

```powershell
# 1. Clone
git clone https://github.com/Neeraj2244/Karate-Framework.git
cd Karate-Framework

# 2. Set up credentials
Copy-Item .env.example .env
# Edit .env with your values

# 3. Run a test
.\karate.ps1 run examples/users/GetCall.feature
```

---

## Running tests

Everything goes through `karate.ps1`:

```powershell
# Run one feature
.\karate.ps1 run examples/graphql/GraphQLBasicQuery.feature

# Run by tag
.\karate.ps1 tags @SanityTest

# Run in parallel (4 threads)
.\karate.ps1 parallel -Threads 4

# Run against staging
.\karate.ps1 tags @RegressionTest -KarateEnv staging

# Exclude a tag
.\karate.ps1 tags "~@IntentionalFailure"
```

---

## CI Workflows

| Workflow | When it runs | What it runs |
|---|---|---|
| `regression.yml` | Every push to `main` | `@RegressionTest` |
| `sanity.yml` | Manual | `@SanityTest` |
| `parallel-all.yml` | Manual | Everything, configurable threads |
| `tag-based.yml` | Manual | Any tag from a dropdown (16 options) |
| `smoke.yml` | Manual | `@SmokeTest` |

---

## Project layout

```
src/test/java/examples/
├── auth/          # Login + authenticated requests
├── users/         # GET with retry
├── posts/         # POST + DELETE (with teardown)
├── headers/       # Custom header tests
├── validation/    # Response schema matching
├── datadriven/    # CSV-driven tests + data files
├── retry/         # Polling / retry-until
├── reusable/      # Shared feature helpers
├── fileupload/    # Multipart upload
├── graphql/       # GraphQL queries, mutations, .graphql files
├── grpc/          # gRPC via grpcurl
└── websocket/     # WebSocket text, binary, handler patterns
```

---

## Key patterns

**Auth token shared across all threads**
One login call at suite start via `karate.callSingle()` — no per-thread re-auth.

**Retry built in**
```gherkin
* configure retry = { count: 3, interval: 2000 }
* retry until responseStatus == 200
```

**CSV data-driven tests**
```gherkin
Examples:
  | read('users-data.csv') |
```

**Automatic cleanup**
Created resources are deleted via `configure afterScenario` hooks — tests clean up after themselves.

**CI-safe logging**
`logback-ci.xml` masks `Authorization` and `X-API-Key` headers in GitHub Actions logs.

---

## Tags

```
@SanityTest       Core happy-path — runs fast
@RegressionTest   Full suite — runs on every push
@Auth             Auth flow
@GraphQL          All GraphQL scenarios
@WebSocket        All WebSocket scenarios
@gRPC             All gRPC scenarios
@DataDriven       CSV-backed tests
@Retry            Polling / retry patterns
@Validation       Response schema tests
@FileUpload       Multipart upload
@IntentionalFailure  Negative test (expected to fail)
```

---

## Reports

After each run, open:
```
target/karate-reports_<timestamp>/karate-summary.html
```

In CI, reports are uploaded as workflow artifacts (7–14 day retention).
