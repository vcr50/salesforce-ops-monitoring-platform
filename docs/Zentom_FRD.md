# Functional Requirements Document (FRD) — Zentom Orchestration System

**Author:** Vijay Radhakrishnan  
**Date:** May 17, 2026  
**Company:** Tomcodex  

---

## Document Revision History

| Version | Date           | Author   | Description                                 |
|---------|----------------|----------|---------------------------------------------|
| 1.0     | May 17, 2026   | Tomcodex | Initial document creation and FRD formatting |

---

## Table of Contents

- [1.0 Introduction and System Architecture](#10-introduction-and-system-architecture)
  - [1.1 System Overview](#11-system-overview)
- [2.0 Functional Requirements — SentinelFlow Layers](#20-functional-requirements--sentinelflow-layers)
  - [2.1 Salesforce Layer](#21-salesforce-layer)
  - [2.2 SentinelFlow Core Layer](#22-sentinelflow-core-layer)
- [3.0 Functional Requirements — Zentom Engines](#30-functional-requirements--zentom-engines-the-orchestration-moat)
  - [3.1 Context Engine](#31-context-engine)
  - [3.2 Memory Engine](#32-memory-engine)
  - [3.3 Policy Engine](#33-policy-engine)
  - [3.4 Risk Engine](#34-risk-engine)
  - [3.5 Replay Engine](#35-replay-engine)
  - [3.6 Evaluation Engine](#36-evaluation-engine)
  - [3.7 Execution Controller](#37-execution-controller)
  - [3.8 Model Router](#38-model-router)
- [4.0 AI Model Specifications](#40-ai-model-specifications)
  - [4.1 DeepSeek R1 — Primary Reasoning Engine](#41-deepseek-r1--primary-reasoning-engine)
  - [4.2 Agentforce — Salesforce-Native Execution](#42-agentforce--salesforce-native-execution)
  - [4.3 Llama 3 — Local Inference via Ollama](#43-llama-3--local-inference-via-ollama)
  - [4.4 DeepSeek Coder — Code Analysis](#44-deepseek-coder--code-analysis)
- [5.0 Governed Autonomous Actions](#50-governed-autonomous-actions)
- [6.0 Audit and Verification Layer](#60-audit-and-verification-layer)
- [7.0 Non-Functional Requirements](#70-non-functional-requirements)

---

## 1.0 Introduction and System Architecture

### 1.1 System Overview

Zentom is the **orchestration moat**. All eight engine components (Context, Memory, Policy, Risk, Replay, Evaluation, Execution Controller, Model Router) sit inside Zentom — this is what Tomcodex owns end-to-end, not just a wrapper around third-party models.

**AI Weightage — Reasoning-First Strategy:**

| Model              | Weight | Role                                      |
|--------------------|--------|--------------------------------------------|
| DeepSeek R1        | 45%    | Heavy inference and complex reasoning      |
| Agentforce         | 20%    | Salesforce-native execution                |
| Llama 3 (Ollama)   | 10%    | Low-latency local inference                |
| DeepSeek Coder     | 10%    | Code analysis and diagnosis                |
| Embeddings (RAG)   | 10%    | Memory Engine vector retrieval             |
| Governance Engine  | 5%     | Guardrails — small by design               |

**Governance is structural, not optional.** The document explicitly states that no LLM action touches production without passing through policy validation, risk analysis, approval logic, verification, and replay logging — this is enforced by the layer order in the architecture.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SALESFORCE ORG                                 │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  Accounts · Cases · Contracts · Revenue · Platform Events     │    │
│  └──────────────────────────┬─────────────────────────────────────┘    │
│                             │ Platform Events (pub/sub)               │
│                             ▼                                         │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │              SENTINELFLOW CORE LAYER                           │    │
│  │  Analyzer → Prioritizer → Confidence Gate → Router → Tracer   │    │
│  └──────────────────────────┬─────────────────────────────────────┘    │
│                             │ Enriched Incident Context               │
│                             ▼                                         │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │              ZENTOM ORCHESTRATION SYSTEM                       │    │
│  │  ┌──────────────────────────────────────────────────────────┐  │    │
│  │  │  Context Engine  │  Memory Engine  │  Model Router       │  │    │
│  │  ├──────────────────┼─────────────────┼─────────────────────┤  │    │
│  │  │  Policy Engine   │  Risk Engine    │  Evaluation Engine  │  │    │
│  │  ├──────────────────┼─────────────────┼─────────────────────┤  │    │
│  │  │  Replay Engine   │  Execution Controller                 │  │    │
│  │  └──────────────────┴──────────────────────────────────────┘  │    │
│  └──────────────────────────┬─────────────────────────────────────┘    │
│                             │ Governed Action                         │
│                             ▼                                         │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │              AGENTFORCE (Salesforce-Native Execution)          │    │
│  │  Cases · Flows · Record Updates · Notifications               │    │
│  └────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2.0 Functional Requirements — SentinelFlow Layers

### 2.1 Salesforce Layer

**Role in the architecture:** Salesforce is the "system of record" — the authoritative source of truth for all business data that SentinelFlow acts on. Incidents, cases, accounts, contracts, revenue data — all of it lives in Salesforce. SentinelFlow doesn't replace or duplicate this; it reads from it and writes back to it.

**How events flow out of Salesforce:** The primary mechanism is **Platform Events** — Salesforce's native pub/sub messaging system. When something happens in Salesforce (an integration fails, a workflow errors, a threshold is breached), it publishes a Platform Event. SentinelFlow Core subscribes to these events and reacts. This is a clean, decoupled architecture: Salesforce doesn't need to know anything about SentinelFlow's internals.

**What Agentforce adds:** Agentforce handles the return path — actions that need to happen back inside Salesforce. Opening a case, triggering a Salesforce Flow, updating records. It runs natively within Salesforce, so it has full access to all Salesforce objects and automation capabilities. In the AI weightage model it carries 20%, focused entirely on Salesforce-native execution.

**The bidirectional relationship:**

```
Salesforce → Platform Event → SentinelFlow → Zentom (governance + reasoning) → Agentforce → Salesforce
```

This indirection ensures every action touching the system of record has been through policy validation, risk scoring, and approval logic first.

**What the Salesforce layer provides to SentinelFlow:** Beyond events, Salesforce is the source of the context that makes AI decisions meaningful — account revenue (for revenue-aware prioritization), contract details, integration topology, historical case data. Without this business context, incident severity is just a technical signal.

### 2.2 SentinelFlow Core Layer

The SentinelFlow Core layer sits between the raw Salesforce data stream and the Zentom AI runtime. Its job is to receive Platform Events, make sense of them, and route enriched incident context downstream for AI processing.

| Component         | Function                                                                                           |
|-------------------|----------------------------------------------------------------------------------------------------|
| **Analyzer**      | Extracts structured incident data (affected system, error signature, blast radius) to feed severity classification. |
| **Prioritizer**   | Cross-references analyzer output against Salesforce revenue and account data for revenue-aware prioritization. |
| **Confidence Gate** | An 80% confidence threshold separates assistance from autonomous action. Below 80%, incidents are escalated for human review. If a production system is affected, the system escalates regardless of confidence. |
| **Router**        | Decides engine engagement based on severity, confidence, and risk score.                           |
| **V1 MVP Intelligence** | Includes Incident Analyzer, AI Severity Detection, Recommendation Engine, and Structured Responses, enabling classification and impact estimation at launch. |
| **Tracer**        | Writes structured audit logs for every decision, forming the foundation for the Replay Engine.     |

---

## 3.0 Functional Requirements — Zentom Engines (The Orchestration Moat)

### 3.1 Context Engine

The Context Engine ensures AI reasoning occurs with full **situational awareness** by assembling a complete background data packet: similar past incidents, runbooks, account details, deployment history, and failure patterns.

**Four Sources of Context:**

| # | Source             | Data Provided                                                    |
|---|--------------------|------------------------------------------------------------------|
| 1 | Memory Engine      | Semantically similar past incidents via RAG                      |
| 2 | Salesforce         | Account tier, ARR, contract status (business context)            |
| 3 | Knowledge Base     | Runbooks, policies, and recovery workflows                       |
| 4 | Incident History   | Root cause context from prior resolutions and escalations        |

### 3.2 Memory Engine

**Core Mechanism:** Uses embeddings and RAG over a vector database to find semantically similar incidents. This allows the system to recognize failure patterns even if they don't share exact keywords.

**Write Path:** Every resolved incident and executed runbook is embedded and stored, building institutional memory over time that supports genuinely predictive intelligence by Phase 5.

**Technology Stack:**
- **Vector Store:** PostgreSQL + pgvector
- **Cache Layer:** Redis for frequently retrieved context

```
Raw Incident / Runbook → Embedding Model → Vector Store (pgvector)
                                                   ↓
Query (new incident) → Embedding → Similarity Search → Top-K Results → Context Packet
                                                   ↑
                                              Redis Cache
```

### 3.3 Policy Engine

The Policy Engine acts as the **governance spine**, evaluating AI-recommended actions against hard gates before execution.

**Rule Examples:**

| Condition                                 | Outcome                                |
|-------------------------------------------|----------------------------------------|
| Confidence < 80%                          | Require human approval                 |
| Production system affected                | Escalate regardless of confidence      |
| Operational risk is high                  | Block autonomous action entirely       |

**Graduated Response System:** Low-confidence goes to human review; production actions are escalated/held; high-risk actions are blocked outright.

**Relationship with Risk Engine:** The Policy Engine evaluates scores computed by the Risk Engine. This separation allows risk measurement logic to be tuned independently of governance rules.

### 3.4 Risk Engine

The Risk Engine is the **measurement instrument** that quantifies the danger of an action based on four dimensions:

| Dimension              | Measures                                                  |
|------------------------|-----------------------------------------------------------|
| **Technical Severity** | Error class and depth in the stack                        |
| **Business Impact**    | Account ARR and tier from Salesforce                      |
| **Blast Radius**       | Estimation of potential systemic damage                   |
| **Operational Context**| Environmental signals (time of day, recent deployments)   |

> **Critical Distinction:** *Confidence* comes from the AI model (certainty of diagnosis). *Risk* comes from this engine (danger of execution). Both must pass independently.

### 3.5 Replay Engine

The Replay Engine ensures **trust and auditability** by recording every AI decision lifecycle in enough detail to be re-run or challenged.

**Replay Record Content:**
- Assembled context packet
- Exact model prompt/response
- Risk dimension scores
- Policy gate outcomes
- Final action taken
- Timestamps and trace IDs
- Human override flags

**Six Replay Use Cases:**

| # | Use Case             | Description                                                    |
|---|----------------------|----------------------------------------------------------------|
| 1 | Audit Review         | Human-readable accounts of AI decisions                        |
| 2 | Policy Re-run        | Testing new thresholds against historical data                 |
| 3 | Model Comparison     | Evaluating different models against identical historical contexts |
| 4 | Training Signal      | Labelled outcomes feed model fine-tuning                       |
| 5 | Post-mortems         | Full decision timelines for incident analysis                  |
| 6 | Performance Metrics  | Feeding accuracy and drift data to the Evaluation Engine       |

### 3.6 Evaluation Engine

The Evaluation Engine is the **quality measurement system** that judges AI performance by comparing recommendations against actual outcomes recorded in the Replay Engine.

**Four Measurement Dimensions:**

| Dimension                 | What It Measures                                              |
|---------------------------|---------------------------------------------------------------|
| Recommendation Accuracy   | Correlation between AI actions and successful incident resolution |
| Risk Calibration          | Accuracy of Risk Engine scores as predictors of real impact   |
| Retrieval Quality         | Relevance of context surfaced by the Memory Engine            |
| Confidence Alignment      | Detecting model drift (confidence scores vs. actual correctness) |

**Three Feedback Loops:**
1. **Model Tuning** — Fine-tuning based on failures
2. **Threshold Tuning** — Adjusting policy gate parameters
3. **Operational Intelligence Graph** — Identifying clusters and predictive patterns (v4/v5)

### 3.7 Execution Controller

The Execution Controller is the **final gate** authorized to initiate real-world actions via Agentforce after policy clearance. An LLM never touches production directly.

**Execution Lifecycle:**

| Phase                  | Function                                                        |
|------------------------|-----------------------------------------------------------------|
| Pre-execution Checks   | Circuit breakers for unstable systems; idempotency checking     |
| Sequencer              | Manages multi-step actions and their internal dependencies      |
| Step Verification      | Confirms success of each step; enables rollback on failure      |

**Supported Action Types:**
- Restart workflow
- Retry integration
- Open Salesforce case
- Notify teams
- Rollback deployment
- Trigger Salesforce Flow

### 3.8 Model Router

The Model Router decides which combination of AI models is best suited to a given context packet based on four signals:

| Signal                          | Routing Logic                                                    |
|---------------------------------|------------------------------------------------------------------|
| Task Type                       | Reasoning → DeepSeek R1, Code → DeepSeek Coder, Records → Agentforce |
| Risk Level                      | Favoring high-capability models for critical situations          |
| Confidence vs. Latency          | Balancing local Llama 3 speed against R1 reasoning depth         |
| Agentforce Role                 | Native executor for 20% of tasks involving Salesforce records/flows |

**Structured Response Format — Normalized for Policy Engine:**

```json
{
  "recommendation": "[Concise summary of diagnosis and proposed path]",
  "confidence_score": "[Integer 0-100]",
  "proposed_action": "[Specific command for Execution Controller]",
  "rationale": "[Detailed justification covering diagnosis, action selection, and governance compliance]"
}
```

---

## 4.0 AI Model Specifications

### 4.1 DeepSeek R1 — Primary Reasoning Engine (45%)

DeepSeek R1 is the primary reasoning engine of the entire SentinelFlow + Zentom stack — carrying 45% of the total AI weightage, the largest single allocation by a significant margin.

**Why R1 specifically:**
- Trained through **reinforcement learning**, which facilitated the emergent development of advanced reasoning patterns including self-reflection, verification, and dynamic strategy adaptation.
- Rather than being "taught" the right answers from massive text corpora, R1 learned to improve its reasoning ability through trial and reward, honing its step-by-step logic on math, coding, and problem-solving tasks.
- Outperforms or matches major Western models on complex reasoning benchmarks, despite being trained at a fraction of their cost — critical for enterprise platforms running thousands of incident analyses.

**Five Incident Types R1 Handles:**

| Incident Type           | Why R1                                                              |
|-------------------------|---------------------------------------------------------------------|
| Multi-system failures   | Root cause requires reasoning across multiple stack layers simultaneously |
| Ambiguous root cause    | No clean pattern match in Memory Engine; must reason from first principles |
| Novel failure types     | Benefit from RL-trained ability to explore solution strategies dynamically |
| High-revenue-risk       | Justifies higher computational cost ($5M+ ARR accounts)             |
| Low-confidence fallback | Model Router escalates when other models return low confidence      |

### 4.2 Agentforce — Salesforce-Native Execution (20%)

Agentforce is the Salesforce-native execution arm — translating Zentom's governed, policy-cleared decisions into actual operations inside Salesforce. Where DeepSeek R1 reasons and recommends, Agentforce acts.

**Why Agentforce rather than a direct API call:**
- Runs inside the **Salesforce Trust Layer** with native access to all Salesforce objects and full permission model enforcement.
- No credentials to manage externally, no API rate limit gymnastics, no risk of writing to records the system isn't supposed to touch.
- Tracks every AI request through an execution monitoring layer, mapping dependencies across workflows.
- Automatically retries tasks based on failure type and system load; reroutes requests to alternative agents or escalates to failover workflows.

**Two Complementary Governance Layers:**
- **Zentom** governs *whether* to act (confidence thresholds, risk scores, approval requirements)
- **Agentforce** governs *how* to act safely inside Salesforce (Trust Layer, Hyperforce, deterministic guardrails, human-in-the-loop)

**AppExchange Compatibility:** Because SentinelFlow's execution layer is Salesforce-native, the entire product can be packaged and distributed through Salesforce's marketplace, dramatically lowering the adoption barrier.

### 4.3 Llama 3 — Local Inference via Ollama (10%)

Llama 3 is the **speed and efficiency layer** of the Zentom hybrid AI stack. Its role is defined by two properties: it runs locally via Ollama, and it's fast.

**Characteristics:**
- Runs locally with no external API calls, providing zero-latency inference
- Handles tasks where speed matters more than reasoning depth
- Suitable for initial triage, classification, and low-risk recommendation generation

### 4.4 DeepSeek Coder — Code Analysis (10%)

DeepSeek Coder processes code as **structured text** rather than plain language, using tokenisation optimised for symbols, indentation, and syntax trees.

**Six Incident Types:**

| Incident Type                     | Example                                                      |
|-----------------------------------|--------------------------------------------------------------|
| Salesforce Flow & Apex failures   | Script errors, governor limit violations, logic bugs         |
| LWC failures                      | Frontend code issues in Lightning Web Components             |
| API & integration bugs            | Malformed payloads, schema mismatches, broken connector logic |
| Bad deployments                   | Code-level diff analysis before rollback decisions           |
| SOQL/pgvector query errors        | SQL-aware diagnosis                                          |
| Celery/FastAPI failures           | Python code issues in Zentom's own backend                   |

**Collaboration with DeepSeek R1:** A deployment failure might have both a code bug (Coder's domain: what line broke) and a systemic blast radius question (R1's domain: what else could this affect). The Model Router can invoke both and merge outputs before Policy Engine evaluation.

---

## 5.0 Governed Autonomous Actions

Governed autonomous actions are the **Phase 4 deliverable** that makes SentinelFlow operationally valuable beyond pure diagnosis. Every action has cleared confidence thresholds, risk scoring, policy gates, and — for higher-risk actions — human approval before the Execution Controller dispatches to Agentforce.

**The Risk Gradient:**

| Action               | Risk Level | Autonomy Level                                              |
|----------------------|------------|--------------------------------------------------------------|
| Notify teams         | Lowest     | Fully autonomous — no production side effects                |
| Open case            | Low        | Fully autonomous — no production side effects                |
| Retry integration    | Medium     | Circuit breaker checked; non-prod auto, prod risk-scored     |
| Trigger SF Flow      | Variable   | Depends on Flow target; production system check (Gate 2)     |
| Restart workflow     | High       | Phase 4 MVP goal; non-prod auto, prod requires human approval |
| Rollback deployment  | Highest    | Always requires human approval; joint Coder + R1 analysis    |

**Phase 4 → Phase 5 Progression:** The system starts with lower-risk actions fully automated and progressively enables higher-risk actions as the Evaluation Engine builds evidence that AI recommendations are accurate and risk scores are calibrated correctly.

---

## 6.0 Audit and Verification Layer

The audit and verification layer is the **permanent, tamper-evident record** of what happened, why it happened, and what the outcome was.

**Two Distinct Functions:**
1. **Verification** — Confirming in real time that each execution step succeeded before proceeding
2. **Audit** — The permanent structured record written after the fact

**Replayable Record Standard:**

A complete record contains:
- Exact context packet (RAG results, runbook, account data)
- Exact model prompt/response and model version
- Risk scores per dimension
- Outcome of each policy gate with reason for any block
- Every execution step with timing
- Final outcome with resolution label
- Human override flags (first-class audit events)

**Human Overrides as First-Class Events:**
When a human approves, rejects, or overrides an AI recommendation, that decision is captured as a first-class field — not a footnote. This creates accountability in both directions and feeds the Evaluation Engine with ground truth for model learning.

---

## 7.0 Non-Functional Requirements

| Requirement          | Target                                                          |
|----------------------|-----------------------------------------------------------------|
| Latency              | < 500ms for triage; < 5s for full context assembly + reasoning  |
| Throughput           | Support 10,000+ incidents/hour                                  |
| Availability         | 99.9% uptime for all engine components                          |
| Data Retention       | All replay records retained for minimum 2 years                 |
| Security             | Zero hardcoded secrets; all credentials via Named Credentials   |
| Compliance           | AppExchange Security Review compliant; SOC 2 ready              |
| Scalability          | Horizontal scaling via Celery workers and FastAPI instances      |
| Observability        | Full OpenTelemetry tracing across all engine boundaries         |
