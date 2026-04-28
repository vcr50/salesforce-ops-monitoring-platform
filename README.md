# Tomcodex - Real-Time Service Operations Portal

Premium service operations workspace built on Salesforce for real-time monitoring of incidents, integrations, and platform health.

![Platform](https://img.shields.io/badge/Platform-Salesforce-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white)
![Experience](https://img.shields.io/badge/UI-Experience%20Cloud-0B5CAB?style=for-the-badge)
![Frontend](https://img.shields.io/badge/Frontend-LWC-1B96FF?style=for-the-badge)
![Automation](https://img.shields.io/badge/Automation-Flows%20%2B%20Apex-16325C?style=for-the-badge)

## At a Glance
- Real-time monitoring for incidents, integrations, and service posture
- Premium Experience Cloud UX designed like a SaaS operations product
- Event-ready architecture using Apex, Flows, and Platform Events
- Modular portal experience across Home, Incidents, Integrations, and Analytics

## Overview
Tomcodex - Real-Time Service Operations Portal is a Salesforce-first operations platform designed to give service teams a clean, product-like interface for observing system health, investigating issues, and acting on service events.

Built with Experience Cloud, Apex, Lightning Web Components, and Flows, the portal brings operational visibility and automation into a single experience. Instead of forcing teams to work across disconnected admin pages, reports, and utility screens, Tomcodex presents incidents, integrations, and analytics through one unified service layer.

This project is designed to feel more like a SaaS product than a traditional internal portal, with branded UI, modular navigation, live operational signals, and architecture ready for real-time event handling.

## What It Solves
- Centralizes incident, integration, and service health monitoring
- Gives operations teams a unified command view for action and analysis
- Improves usability with a clean LWC-based interface inside Experience Cloud
- Enables automation across issue handling and service workflows
- Creates a scalable foundation for event-driven real-time service operations

## Core Modules
| Module | Purpose | Experience |
| --- | --- | --- |
| `Home` | Service health overview | Premium landing experience, operational posture, summary metrics |
| `Incidents` | Issue tracking | Open incident queue, severity prioritization, detail drill-down |
| `Integrations` | API monitoring | Failed and warning integration visibility, response tracking |
| `Analytics` | Insights and trends | Operational reporting, service patterns, executive visibility |

## Architecture
The solution follows a layered Salesforce architecture where Experience Cloud acts as the presentation layer, LWCs deliver the application experience, Apex powers data orchestration and domain logic, and Flows automate service operations.

```text
Experience Cloud Site
        |
        v
Lightning Web Components
        |
        v
Apex Controllers + Apex Automation
        |
        +--> Salesforce Custom Objects
        |      - Incident__c
        |      - Integration_Log__c
        |      - SLA_Policy__c
        |      - Environment__c
        |      - Deployment_Record__c
        |      - Audit_Trail__c
        |
        +--> Flows / Declarative Automation
        |
        +--> Platform Events for real-time updates
        |
        +--> External API integrations
```

### Architectural Highlights
- Experience Cloud provides the branded portal and module navigation
- LWC delivers a responsive, product-style UI layer
- Apex handles controller logic, record retrieval, automation support, and interaction orchestration
- Flows support declarative business automation for service lifecycle actions
- Platform Events enable real-time operational messaging and future event-driven scaling
- External APIs connect third-party service signals and integration telemetry into Salesforce

## Product Flow
```text
Signal Detected
    ->
Platform Event / API Input
    ->
Apex + Flow Automation
    ->
Salesforce Operational Objects
    ->
Experience Cloud + LWC Portal
    ->
Operator Action, Analytics, and Executive Visibility
```

## Tech Stack
- Salesforce Experience Cloud
- Apex
- Lightning Web Components (LWC)
- Salesforce Flows
- Platform Events
- Salesforce DX
- GitHub for version control and delivery workflow

## Features
- Unified dashboard for incidents, integrations, and analytics
- Real-time operational architecture using Platform Events
- Product-like user experience built with Lightning Web Components
- Flow-driven automation for service actions and lifecycle support
- Integration-ready design for external API monitoring and telemetry
- Dark and light presentation modes for a premium portal experience
- Modular Experience Cloud information architecture
- Drill-down detail views for incidents and integrations

## Screenshots
Add product screenshots here as the experience evolves.

| View | Placeholder |
| --- | --- |
| Home module overview | `docs/screenshots/home-overview.png` |
| Incidents live queue | `docs/screenshots/incidents-module.png` |
| Integrations monitoring | `docs/screenshots/integrations-module.png` |
| Analytics trends | `docs/screenshots/analytics-module.png` |
| Experience Cloud landing page | `docs/screenshots/landing-page.png` |

## Repository Structure
```text
.
├── config/
├── docs/
├── force-app/
│   └── main/
│       └── default/
│           ├── applications/
│           ├── classes/
│           ├── flexipages/
│           ├── layouts/
│           ├── lwc/
│           ├── objects/
│           ├── permissionsets/
│           ├── reports/
│           └── triggers/
├── infrastructure/
│   └── terraform/
├── manifest/
│   └── package.xml
├── scripts/
├── src/
└── README.md
```

## Installation
These steps are example setup instructions and can be adapted for your org and deployment model.

1. Clone the repository.

   ```bash
   git clone https://github.com/your-org/tomcodex-real-time-service-operations-portal.git
   cd tomcodex-real-time-service-operations-portal
   ```

2. Authenticate to your Salesforce org.

   ```bash
   sf org login web --alias tomcodex-dev
   ```

3. Deploy Salesforce metadata.

   ```bash
   sf project deploy start --target-org tomcodex-dev
   ```

4. Assign permission sets as needed.

   ```bash
   sf org assign permset --name SEOMP_Runtime_Admin --target-org tomcodex-dev
   sf org assign permset --name SEOMP_Portal_Support --target-org tomcodex-dev
   ```

5. Publish the Experience Cloud site and place the required LWCs in Experience Builder.

6. Seed sample data if needed for demos.

   ```bash
   sf apex run --file scripts/salesforce/seed-dashboard-sample-data.apex --target-org tomcodex-dev
   ```

## Deployment Notes
- The project uses Salesforce DX source format
- Experience Cloud components are intended to be placed through Experience Builder
- Apex classes and LWCs support the portal's live operational modules
- Platform Events are part of the real-time direction for this product and can be expanded further for event-driven processing

## Why This README Exists
This repository is meant to serve both as a working Salesforce implementation and as a showcase of how modern service operations can be presented with a cleaner, more product-grade experience inside Salesforce.

## Future Enhancements
- Full Platform Event-driven live refresh across portal modules
- Expanded external API connectors and health aggregation
- Rich analytics dashboards with executive and operator views
- SLA breach automation and proactive alert routing
- Customer-facing status pages and tenant-aware portal experiences
- CI/CD pipeline for validation, packaging, and automated deployments
- Advanced search, filters, and timeline views across incidents and integrations

## Documentation
- [Architecture](docs/architecture.md)
- [Data Model](docs/data-model.md)
- [Developer Org Setup](docs/developer-org-setup.md)
- [Dashboard Handoff](docs/dashboard-handoff.md)
- [Experience Cloud Plan](docs/experience-cloud-plan.md)
- [Experience Cloud Build Checklist](docs/experience-cloud-build-checklist.md)

## Author
**Tomcodex**

Salesforce architecture, service operations design, Experience Cloud delivery, and premium portal engineering.

---

If you use this project as a foundation, consider tailoring the branding, event model, and automation strategy to your own service operations lifecycle.
