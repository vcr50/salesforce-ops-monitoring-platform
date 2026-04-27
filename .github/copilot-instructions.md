<!-- Use this file to provide workspace-specific custom instructions to Copilot. -->

## Salesforce Ecosystem POC Project

This is a Node.js + Express-based Salesforce ecosystem integration POC project.

### Tech Stack
- **Runtime**: Node.js
- **Framework**: Express.js
- **APIs**: REST, SOAP, Bulk API
- **Auth**: OAuth 2.0
- **Features**: Data Sync, Records Management, Analytics

### Project Conventions
- Use ES6 syntax with proper async/await patterns
- Error handling with structured logging (Pino)
- Modular architecture with clear separation of concerns
- Configuration via environment variables
- Comprehensive error handling with retry logic

### Key Directories
- `src/` - Application source code
- `src/modules/` - Salesforce API integrations
- `src/services/` - Business logic services
- `src/controllers/` - Route handlers
- `src/routes/` - Express route definitions
- `src/middleware/` - Custom middleware
- `tests/` - Test files

### Development Commands
- `npm install` - Install dependencies
- `npm run dev` - Start development server with nodemon
- `npm start` - Start production server
- `npm test` - Run tests
- `npm run lint` - Run ESLint
