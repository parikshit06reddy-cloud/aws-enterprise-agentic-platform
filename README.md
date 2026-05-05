# Enterprise Agentic Platform on AWS

[![CI](https://github.com/parikshit06reddy-cloud/aws-enterprise-agentic-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/parikshit06reddy-cloud/aws-enterprise-agentic-platform/actions/workflows/ci.yml)
[![Security](https://github.com/parikshit06reddy-cloud/aws-enterprise-agentic-platform/actions/workflows/security.yml/badge.svg)](https://github.com/parikshit06reddy-cloud/aws-enterprise-agentic-platform/actions/workflows/security.yml)
[![Python 3.12.8](https://img.shields.io/badge/python-3.12.8-blue.svg)](https://www.python.org/downloads/)

> Production-grade, multi-framework agentic platform on AWS. Hosts agents written in **LangGraph, Strands, CrewAI, and Pydantic-AI** on a shared substrate of **AWS Bedrock AgentCore Runtime + EKS**, coordinated through a unified gateway, memory layer, and MCP tool catalog. Includes a mortgage-domain agent layer and end-to-end LangSmith + RAGAS observability.

---

## Table of Contents

- [Why this exists](#why-this-exists)
- [Architecture](#architecture)
- [Tech stack](#tech-stack)
- [Repository layout](#repository-layout)
- [Key features](#key-features)
- [Quick start](#quick-start)
- [Deploying](#deploying)
- [Build, release, and image tagging](#build-release-and-image-tagging)
- [Observability](#observability)
- [Security and compliance](#security-and-compliance)
- [Contributing](#contributing)
- [License](#license)

---

## Why this exists

Enterprise teams rarely bet on a single agent framework. They need:

- A shared runtime for multiple frameworks without lock-in
- A common memory + retrieval layer that survives across agents and sessions
- A unified tool catalog so agents reuse existing REST/Lambda capabilities
- Tracing, evaluation, and audit trails that meet enterprise compliance bars

This repo packages those concerns into reusable infrastructure and example agent services modeled on the architecture used at PennyMac's AI Platform Services to automate epic decomposition, code review, test plan generation, and mortgage document Q&A for hundreds of engineers.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    API Gateway / ALB                         │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Supervisor Agent (LangGraph)                    │
│         Centralized orchestrator — routes tasks              │
└──────┬──────────────┬──────────────┬───────────────┬────────┘
       │              │              │               │
  ┌────▼────┐   ┌─────▼─────┐  ┌────▼─────┐  ┌──────▼──────┐
  │  RAG    │   │ Document  │  │Compliance│  │ Code Review │
  │ Agent   │   │  Parser   │  │  Agent   │  │   Agent     │
  │(Pinecone│   │(Textract) │  │ (Claude  │  │(LangGraph)  │
  │+Bedrock)│   │           │  │  3.5)    │  │             │
  └─────────┘   └───────────┘  └──────────┘  └─────────────┘
       │
┌──────▼──────────────────────────────────────────────────────┐
│         AgentCore Memory (Short + Long Term)                 │
│     Pinecone Vector Store   │   DynamoDB Session Store       │
└─────────────────────────────────────────────────────────────┘
       │
┌──────▼──────────────────────────────────────────────────────┐
│      Observability: LangSmith + CloudWatch (OpenTelemetry)   │
│              RAGAS + DeepEval Evaluation Pipeline            │
└─────────────────────────────────────────────────────────────┘
```

---

## Tech stack

| Layer | Technologies |
|---|---|
| Agent frameworks | LangGraph, Strands Agents, CrewAI, Pydantic-AI |
| LLMs | Claude 3.5 Sonnet, GPT-4o, AWS Titan Embeddings, LiteLLM router |
| Orchestration | AWS Bedrock AgentCore Runtime, EKS, ECS |
| RAG / vector | Pinecone (hybrid), pgvector (Postgres), ChromaDB, cross-encoder rerank |
| Doc processing | AWS Textract |
| Tools | Model Context Protocol (MCP), AgentCore Gateway, AWS Lambda |
| Memory | AgentCore Memory (short + long-term episodic), DynamoDB, Redis |
| Observability | LangSmith, CloudWatch (OpenTelemetry), Arize Phoenix |
| Evaluation | RAGAS, DeepEval, golden-dataset pipelines |
| Security | AWS IAM, VPC, Cognito, RBAC, gitleaks, CodeQL |
| Dependency mgmt | `uv` + `uv.lock` (reproducible) |
| IaC | Terraform (modular EKS / ECS / observability) |
| Container build | Docker buildx multi-arch (amd64 + arm64), pushed to ECR |

---

## Repository layout

```
.
├── alembic/                # DB migrations
├── bootstrap/              # First-run helpers
├── deploy/                 # Build + deploy scripts (multi-arch ECR push)
├── docker/                 # One Dockerfile per service
├── infrastructure/         # Terraform stacks + modules (EKS, ECS, observability)
├── k8s/                    # Helm charts and raw manifests
├── labs/                   # Jupyter notebook explorations
├── src/agentic_platform/   # Python source: agents/services/MCP/core
├── tests/                  # unit + integration tests
├── pyproject.toml          # core deps (Python ==3.12.8)
├── uv.lock                 # locked dep graph (source of truth)
├── Makefile                # task entrypoints (install/test/dev/build/deploy)
└── .github/workflows/      # CI + Security + ECR publish
```

---

## Key features

- **Multi-framework agent factory** — Supervisor dispatches tasks across LangGraph, Strands, CrewAI, Pydantic-AI without framework lock-in
- **Production RAG** — Hybrid (BM25 + dense) on Pinecone with cross-encoder rerank; sub-100ms p95 retrieval latency
- **MCP tool gateway** — Existing REST APIs and Lambda functions exposed as agent tools via semantic discovery
- **AgentCore memory** — Episodic + session memory enabling stateful, personalized assistance
- **Hallucination guardrails** — Pydantic schema validation on outputs, deterministic fallbacks, human-in-the-loop escalation
- **Full OTel tracing** — LangSmith + CloudWatch traces across every agent boundary
- **Immutable image tags** — Every build is tagged with the commit SHA; `:latest` is a moving alias only
- **Hardened CI** — Lint, tests, lockfile check, CodeQL, Gitleaks, Trivy (FS + IaC + image), Checkov; all blocking on PR

---

## Quick start

Prerequisites:

- Python `==3.12.8`
- [uv](https://github.com/astral-sh/uv) for dependency management
- Docker + Docker Buildx
- AWS CLI v2 and target account access
- Terraform 1.6+

```bash
git clone https://github.com/parikshit06reddy-cloud/aws-enterprise-agentic-platform.git
cd aws-enterprise-agentic-platform

make install                         # uv sync from uv.lock
make dev:deps                        # bring up Postgres, Redis, LiteLLM locally
make dev agentic_chat                # run an agent locally on :8080
```

Run tests + lint locally:

```bash
make test
make lint
make security                        # gitleaks
```

---

## Deploying

The platform supports two runtimes per agent: **EKS** and **AgentCore Runtime**.

```bash
make build agentic_chat              # multi-arch build + push to ECR
make deploy-eks agentic_chat         # build + apply k8s manifests
make deploy-ac agentic_chat          # build + apply AgentCore Terraform
```

Infrastructure is split into composable Terraform stacks under `infrastructure/stacks/`:

- `platform-eks` — VPC, EKS, observability, ALB, networking
- `agentcore-runtime` — Bedrock AgentCore deployments per agent
- `bedrock-knowledge-bases` — KB sources, ingestion, S3 + IAM

---

## Build, release, and image tagging

`deploy/build-container.sh` always produces an **immutable, traceable** primary tag:

| Source | Resulting tag |
|---|---|
| `IMAGE_TAG` env (CI override) | `IMAGE_TAG` value (e.g. `v1.2.3`) |
| GitHub Actions | `${GITHUB_SHA}` |
| Local with git | short commit SHA (`git rev-parse --short=12 HEAD`) |
| Local without git | UTC timestamp |

The script also pushes a moving `:latest` alias for backward compatibility, and the workflow emits the full immutable URI as a step output (`image_uri`) so downstream rollouts can pin by digest.

CI runs `Trivy` on the published image before letting downstream deploy steps proceed.

---

## Observability

- **LangSmith** for full prompt/trace history per agent
- **OpenTelemetry → CloudWatch** for service traces, metrics, and logs
- **OTel Collector** deployed alongside agents in EKS (see `infrastructure/modules/kubernetes/otel-collectors.tf`)
- **RAGAS / DeepEval** evaluation pipelines for offline scoring of agent outputs

Add CloudWatch alarms for service health and SLOs in `infrastructure/modules/observability-alarms/` (see roadmap).

---

## Security and compliance

- **CI gates (PR-blocking):** ruff + ruff format, pytest, `uv lock --check`, CodeQL, Gitleaks, Trivy FS + IaC, Checkov
- **Image scanning:** Trivy on every pushed image
- **Secrets:** GitHub push protection enabled; `make security` runs gitleaks on demand
- **IAM:** least-privilege per agent role; OIDC trust between GitHub Actions and AWS
- **Networking:** ALBs use deletion protection in prod; VPC isolation per environment
- **Patch policy:** Dependabot weekly groups (`langchain*`, `aws-*`, `opentelemetry*`, `pydantic*`, `strands-agents*`, dev tooling)

Report vulnerabilities by opening a private GitHub Security Advisory.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). PRs must pass CI + Security workflows. Local pre-commit runs ruff and gitleaks.

---

## License

See [LICENSE](LICENSE).

---

**Author:** Parikshit Reddy — [LinkedIn](https://www.linkedin.com/in/parikshitr/) · [GitHub](https://github.com/parikshit06reddy-cloud)

> Extended fork of [aws-samples/sample-agentic-platform](https://github.com/aws-samples/sample-agentic-platform) with mortgage-domain agents, MCP tool gateway, and end-to-end LangSmith + RAGAS observability.
