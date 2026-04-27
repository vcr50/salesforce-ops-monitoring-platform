# salesforce-ops-monitoring-platform
Real-time, event-driven monitoring and administration system designed for enterprise Salesforce environments.  It provides visibility into system health, automates administrative processes, and enables proactive incident management by integrating Salesforce with a Node.js middleware deployed on Heroku.

---

## Key Features

- Real-time monitoring using Streaming API (no polling)
- SLA-based incident management with auto-escalation
- Integration monitoring and failure detection
- Health score engine for system visibility
- Self-healing automation for repeated failures
- Audit trail for administrative actions
- Multi-environment support (Dev / QA / Prod)
- Live dashboards (React + Lightning Web Components)
- Slack and email alerting system
- CI/CD pipeline using GitHub Actions
- Infrastructure as Code using Terraform

---

## Tech Stack

### Salesforce
- Apex
- Flows
- Platform Events
- Lightning Web Components (LWC)

### Backend
- Node.js (Express)
- Kafka / Redis Streams
- Socket.IO (WebSockets)

### Frontend
- React

### Database
- PostgreSQL

### Cloud & DevOps
- Heroku
- GitHub Actions
- Terraform

### Security
- OAuth 2.0
- JWT Authentication
- Secret Management

---

## Project Structure
