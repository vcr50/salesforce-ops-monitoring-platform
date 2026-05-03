# SentinelFlow Debugging Guide

This guide helps you debug issues in SentinelFlow across different components and layers.

## Table of Contents

- [Overview](#overview)
- [Debugging Tools](#debugging-tools)
- [Common Debugging Scenarios](#common-debugging-scenarios)
- [Component-Specific Debugging](#component-specific-debugging)
- [Logging](#logging)
- [Performance Debugging](#performance-debugging)
- [Common Issues and Solutions](#common-issues-and-solutions)

## Overview

SentinelFlow consists of multiple layers that may require different debugging approaches:

1. **Frontend (Dashboard)**: JavaScript/HTML/CSS
2. **Backend API**: Node.js/Express
3. **Salesforce Integration**: Apex/Platform Events
4. **Database**: PostgreSQL
5. **Queue**: Redis

## Debugging Tools

### Browser Developer Tools

For frontend debugging:

1. **Chrome DevTools** (F12):
   - Console: View JavaScript errors and logs
   - Network: Inspect API requests/responses
   - Elements: Inspect DOM and styles
   - Sources: Set breakpoints in JavaScript
   - Performance: Analyze runtime performance

2. **React DevTools** (if using React):
   - Component tree inspection
   - Props and state inspection
   - Time travel debugging

### Node.js Debugging

1. **Built-in Debugger**:
   ```bash
   node inspect src/app.js
   ```

2. **VS Code Debugger**:
   - Set breakpoints in VS Code
   - Use launch configuration:
     ```json
     {
       "type": "node",
       "request": "launch",
       "name": "Debug SentinelFlow",
       "program": "${workspaceFolder}/src/app.js"
     }
     ```

3. **Chrome DevTools with Node.js**:
   ```bash
   node --inspect src/app.js
   # Then open chrome://inspect in Chrome
   ```

### Salesforce Debugging

1. **Developer Console**:
   - Open in Salesforce Setup
   - Debug Apex code
   - View debug logs

2. **Debug Logs**:
   ```bash
   sf apex get log --target-org sentinelFlow-dev-edition
   ```

3. **Anonymous Apex**:
   ```bash
   sf apex run --file scripts/apex/debug.apex
   ```

### Database Debugging

1. **PostgreSQL**:
   ```bash
   psql -U username -d sentinelflow
   ```

2. **Query Analysis**:
   ```sql
   EXPLAIN ANALYZE SELECT * FROM incidents;
   ```

## Common Debugging Scenarios

### API Not Responding

1. Check if server is running:
   ```bash
   curl http://localhost:3000/health
   ```

2. Check server logs for errors
3. Verify port is not in use
4. Check environment variables

### Data Not Loading in Dashboard

1. Open browser DevTools (F12)
2. Check Console for JavaScript errors
3. Check Network tab for failed API calls
4. Verify API responses in Network tab
5. Check if data exists in database

### Salesforce Integration Issues

1. Verify Salesforce credentials in `.env`
2. Check Connected App configuration
3. Review Salesforce debug logs
4. Test API connection:
   ```bash
   curl -H "Authorization: Bearer $ACCESS_TOKEN"      https://your-instance.salesforce.com/services/data/v58.0/
   ```

### Authentication Failures

1. Check session configuration
2. Verify OAuth flow
3. Review authentication logs
4. Test with valid credentials

## Component-Specific Debugging

### Frontend Dashboard

1. **JavaScript Errors**:
   - Open Console in DevTools
   - Look for red error messages
   - Check stack traces

2. **API Calls**:
   - Use Network tab
   - Filter by XHR/Fetch
   - Inspect request/response headers
   - Check response status codes

3. **State Issues**:
   - Add console.log() for state changes
   - Use React DevTools (if applicable)
   - Check component props

4. **CSS Issues**:
   - Use Elements tab
   - Inspect applied styles
   - Check for style conflicts

### Backend API

1. **Request Handling**:
   ```javascript
   app.use((req, res, next) => {
     console.log(`${req.method} ${req.path}`);
     console.log('Headers:', req.headers);
     console.log('Body:', req.body);
     next();
   });
   ```

2. **Error Handling**:
   ```javascript
   app.use((err, req, res, next) => {
     console.error('Error:', err);
     console.error('Stack:', err.stack);
     res.status(500).json({ error: err.message });
   });
   ```

3. **Database Queries**:
   ```javascript
   console.log('Query:', query);
   console.log('Params:', params);
   ```

### Salesforce Integration

1. **API Calls**:
   ```java
   System.debug('API Call: ' + endpoint);
   System.debug('Request: ' + requestBody);
   System.debug('Response: ' + response);
   ```

2. **Platform Events**:
   ```java
   System.debug('Publishing Event: ' + event);
   System.debug('Event Payload: ' + JSON.serialize(event));
   ```

3. **Triggers**:
   ```java
   System.debug('Trigger fired on: ' + Trigger.new);
   System.debug('Operation: ' + Trigger.operationType);
   ```

### Database

1. **Slow Queries**:
   ```sql
   EXPLAIN ANALYZE SELECT * FROM incidents WHERE status = 'Open';
   ```

2. **Connection Issues**:
   ```bash
   psql -U username -d sentinelflow -c "SELECT version();"
   ```

3. **Data Integrity**:
   ```sql
   SELECT COUNT(*) FROM incidents;
   SELECT * FROM incidents WHERE created_at > NOW() - INTERVAL '1 hour';
   ```

## Logging

### Application Logging

SentinelFlow uses Pino for structured logging:

```javascript
const { logger } = require('./middleware/logger');

// Info level
logger.info({ incidentId: 'INC-001' }, 'Processing incident');

// Error level
logger.error({ error: err }, 'Failed to process incident');

// Debug level
logger.debug({ data }, 'Detailed debug information');
```

### Log Levels

- `trace`: Very detailed information
- `debug`: Detailed information for debugging
- `info`: General informational messages
- `warn`: Warning messages
- `error`: Error messages
- `fatal`: Critical errors

### Viewing Logs

```bash
# Development (console)
npm run dev

# Production (file)
tail -f logs/app.log

# Filter by level
grep "ERROR" logs/app.log

# Search for specific incident
grep "INC-001" logs/app.log
```

### Salesforce Debug Logs

```bash
# Enable debug logs for a user
sf apex enable trace --target-org sentinelFlow-dev-edition   --target-user-id <user-id>

# Retrieve debug logs
sf apex get log --target-org sentinelFlow-dev-edition

# View log
sf apex get log --target-org sentinelFlow-dev-edition | less
```

## Performance Debugging

### Frontend Performance

1. **Use Chrome DevTools Performance tab**:
   - Record page load
   - Analyze timeline
   - Identify bottlenecks

2. **Lighthouse**:
   ```bash
   npm install -g lighthouse
   lighthouse http://localhost:3000/dashboard
   ```

3. **Network Performance**:
   - Check large assets
   - Optimize images
   - Enable compression

### Backend Performance

1. **Response Time**:
   ```javascript
   const start = Date.now();
   // ... operation ...
   const duration = Date.now() - start;
   logger.info({ duration }, 'Operation completed');
   ```

2. **Database Performance**:
   ```sql
   EXPLAIN ANALYZE your_query;
   ```

3. **Memory Usage**:
   ```javascript
   const used = process.memoryUsage();
   console.log(`Memory: ${Math.round(used.rss / 1024 / 1024)}MB RSS`);
   ```

### Salesforce Performance

1. **SOQL Query Performance**:
   ```java
   List<Incident__c> incidents = [
     SELECT Id, Name, Status__c 
     FROM Incident__c 
     WHERE Status__c = 'Open'
     LIMIT 1000
   ];
   System.debug('Query returned: ' + incidents.size() + ' records');
   ```

2. **Governor Limits**:
   ```java
   System.debug(Limits.getQueries());
   System.debug(Limits.getDmlStatements());
   ```

## Common Issues and Solutions

### Issue: Port Already in Use

**Symptoms**: Error message "EADDRINUSE: address already in use"

**Solution**:
```bash
# Find process using port
lsof -i :3000  # macOS/Linux
netstat -ano | findstr :3000  # Windows

# Kill process or change PORT in .env
PORT=3001 npm run dev
```

### Issue: Database Connection Failed

**Symptoms**: Error connecting to PostgreSQL

**Solution**:
1. Verify PostgreSQL is running
2. Check DATABASE_URL in .env
3. Test connection:
   ```bash
   psql $DATABASE_URL
   ```
4. Check database credentials

### Issue: Salesforce API Rate Limit

**Symptoms**: "REQUEST_LIMIT_EXCEEDED" error

**Solution**:
1. Reduce API call frequency
2. Implement caching
3. Use bulk API for large operations
4. Check Salesforce limits in Setup

### Issue: Session Expiring

**Symptoms**: Users logged out frequently

**Solution**:
1. Check SESSION_SECRET in .env
2. Adjust session timeout:
   ```javascript
   cookie: {
     maxAge: 24 * 60 * 60 * 1000 // 24 hours
   }
   ```
3. Verify session store configuration

### Issue: Memory Leak

**Symptoms**: Increasing memory usage over time

**Solution**:
1. Use heap profiling:
   ```bash
   node --inspect src/app.js
   # Then use Chrome DevTools Memory profiler
   ```
2. Check for event listeners not removed
3. Review database connection pooling
4. Look for unclosed resources

### Issue: Slow API Response

**Symptoms**: API endpoints taking long to respond

**Solution**:
1. Profile with:
   ```javascript
   const start = Date.now();
   // ... code ...
   console.log(`Duration: ${Date.now() - start}ms`);
   ```
2. Check database queries
3. Review external API calls
4. Add caching where appropriate

## Getting Help

If you can't resolve an issue:

1. Check existing documentation
2. Search GitHub Issues
3. Create a new issue with:
   - Detailed description
   - Steps to reproduce
   - Error messages
   - Environment details
   - Debug logs

## Additional Resources

- [Node.js Debugging Guide](https://nodejs.org/en/docs/guides/debugging-getting-started/)
- [Chrome DevTools Documentation](https://developer.chrome.com/docs/devtools/)
- [Salesforce Debugging Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_debugging.htm)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
