# Enterprise Agentic Platform on AWS

> **Extended fork** of [aws-samples/sample-agentic-platform](https://github.com/aws-samples/sample-agentic-platform) — enhanced with a mortgage-domain agent layer, MCP tool gateway, and end-to-end LangSmith + RAGAS observability.

---

## Overview

This project demonstrates a **production-grade, multi-framework agentic platform** deployed on AWS. It showcases how multiple AI agent frameworks (LangGraph, Strands, CrewAI) can coexist on shared infrastructure using AWS Bedrock AgentCore Runtime and EKS, coordinated through a unified gateway and memory layer.

Built as a direct reflection of the architecture designed at **PennyMac's AI Platform Services division** — where a similar system automates epic decomposition, code review, test plan generation, and mortgage document Q&A for 300+ engineers.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      API Gateway / ALB                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│               Supervisor Agent (LangGraph)                   │
│         Centralized orchestrator — routes tasks              │
└──────┬──────────────┬──────────────┬───────────────┬────────┘
       │              │              │               │
  ┌────▼────┐   ┌─────▼─────┐  ┌────▼────┐  ┌──────▼──────┐
  │  RAG    │   │ Document  │  │Compliance│  │  Code Review│
  │ Agent  │   │  Parser   │  │  Agent  │  │   Agent     │
  │(Pinecone│   │(Textract) │  │ (Claude │  │ (LangGraph) │
  │Bedrock) │   │           │  │  3.5)   │  │             │
  └─────────┘   └───────────┘  └─────────┘  └─────────────┘
       │
┌──────▼──────────────────────────────────────────────────────┐
│              AgentCore Memory (Short + Long Term)            │
│         Pinecone Vector Store   │   DynamoDB Session Store   │
└─────────────────────────────────────────────────────────────┘
       │
┌──────▼──────────────────────────────────────────────────────┐
│         Observability: LangSmith + CloudWatch (OTel)         │
│              RAGAS Evaluation Pipeline                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

| Layer | Technologies |
|---|---|
| Agent Frameworks | LangGraph, Strands Agents, CrewAI |
| LLM / Foundation Models | Claude 3.5 Sonnet, GPT-4o, AWS Titan Embeddings |
| Orchestration Infra | AWS Bedrock AgentCore Runtime, EKS |
| RAG & Vector Search | Pinecone (hybrid search, BM25 + dense ANN), cross-encoder re-ranking |
| Document Processing | AWS Textract, Azure Form Recognizer |
| Tool Integration | Model Context Protocol (MCP), AgentCore Gateway, AWS Lambda |
| Memory | AgentCore Memory (short-term + long-term episodic), DynamoDB |
| Observability | LangSmith, AWS CloudWatch (OpenTelemetry), Arize Phoenix |
| Evaluation | RAGAS, Golden Dataset pipelines |
| Security | AWS IAM, VPC PrivateLink, Cognito, RBAC |
| IaC | AWS CDK, CloudFormation |

---

## Key Features

- **Multi-Framework Agent Factory** — Supervisor agent dispatches tasks to specialized stateless sub-agents across LangGraph, Strands, and CrewAI without framework lock-in
- **Production RAG Pipeline** — Hybrid search (BM25 + dense ANN) with cross-encoder re-ranking; sub-100ms retrieval latency on Pinecone at enterprise scale
- **MCP Tool Gateway** — Converts existing REST APIs and Lambda functions into agent-ready capabilities with semantic tool discovery
- **AgentCore Memory** — Episodic + session memory enabling stateful, personalized assistance across multi-hour autonomous workflows
- **Hallucination Guardrails** — Zod schema validation on every LLM output, deterministic fallback logic, and human-in-the-loop escalation triggers
- **Observability Stack** — Full OpenTelemetry trace instrumentation via LangSmith and CloudWatch; RAGAS-based automated evaluation pipelines
- **Enterprise Security** — Multi-tenant agent isolation via IAM roles, VPC PrivateLink, and AgentCore session boundaries

---

## Extensions Added (Beyond Upstream)

| Extension | Description |
|---|---|
| Mortgage-Domain RAG Agent | Retrieval agent backed by Pinecone, ingesting Confluence + Jira + GitLab content |
| Document Classification Agent | AWS Textract pipeline for mortgage PDF/DOCX ingestion and indexing |
| Compliance Validation Agent | Claude 3.5-powered agent validating outputs against mortgage regulatory requirements |
| LangSmith + RAGAS Integration | End-to-end observability and evaluation layer added across all agent frameworks |
| MCP Gateway Extension | Converts Lambda functions to agent tools with semantic routing |

---

## Getting Started

```bash
# Clone this repo
git clone https://github.com/parikshit06reddy-cloud/enterprise-agentic-platform-aws
cd enterprise-agentic-platform-aws

# Install dependencies
pip install -r requirements.txt

# Configure AWS credentials
aws configure

# Deploy infrastructure
cd infrastructure && cdk deploy
```

See the upstream [AGENTS.md](AGENTS.md) for full setup and framework-specific guides.

---

## Author

**Parikshit Reddy** — Principal Applied AI Engineer  
[LinkedIn](https://www.linkedin.com/in/parikshitr/) · [GitHub](https://github.com/parikshit06reddy-cloud)

> This project is a fork extended with domain-specific agents and observability layers reflecting production patterns from enterprise AI platform engineering.
