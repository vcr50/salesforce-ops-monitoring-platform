# Contributing to SentinelFlow

Thank you for your interest in contributing to SentinelFlow! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Code Style Guidelines](#code-style-guidelines)
- [Commit Message Conventions](#commit-message-conventions)
- [Pull Request Process](#pull-request-process)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to [contact@tomcodex.com](mailto:contact@tomcodex.com).

## Getting Started

### Prerequisites

- Node.js >= 16.0.0
- npm or yarn
- Git
- Salesforce CLI (sf)
- A Salesforce Developer Edition org

### Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/your-username/SEOMP.git
   cd SEOMP
   ```

3. Install dependencies:
   ```bash
   npm install
   ```

4. Set up environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. Start the development server:
   ```bash
   npm run dev
   ```

## Development Workflow

1. Create a new branch for your feature or bugfix:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b bugfix/your-bugfix-name
   ```

2. Make your changes following the [Code Style Guidelines](#code-style-guidelines)

3. Write tests for your changes (see [Testing Guidelines](#testing-guidelines))

4. Run tests and ensure they pass:
   ```bash
   npm test
   ```

5. Run linter and fix any issues:
   ```bash
   npm run lint
   ```

6. Commit your changes following [Commit Message Conventions](#commit-message-conventions)

7. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

8. Create a Pull Request (see [Pull Request Process](#pull-request-process))

## Code Style Guidelines

### JavaScript/Node.js

- Use 2 spaces for indentation
- Use single quotes for strings
- Use semicolons
- Use const/let, never var
- Prefer arrow functions for callbacks
- Add JSDoc comments for all functions
- Maximum line length: 100 characters

Example:
```javascript
/**
 * Retrieves system context information
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>}
 */
const getSystemContext = async (req, res) => {
  try {
    const context = await fetchSystemContext();
    res.json({ success: true, data: context });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
};
```

### Apex

- Follow Salesforce naming conventions
- Add comments for complex logic
- Use proper exception handling
- Write test classes with >= 75% coverage

### LWC (Lightning Web Components)

- Follow Salesforce LWC best practices
- Use proper component lifecycle hooks
- Implement proper error handling
- Add comments for complex logic

## Commit Message Conventions

We follow conventional commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to the build process or auxiliary tools

### Examples

```
feat(incidents): add AI analysis endpoint

Add new endpoint for triggering AI analysis on incidents.
Includes proper error handling and validation.

Closes #123
```

```
fix(auth): resolve session timeout issue

Fix issue where sessions were expiring prematurely
due to incorrect cookie configuration.
```

## Pull Request Process

1. Ensure your code follows the [Code Style Guidelines](#code-style-guidelines)
2. Update documentation if needed
3. Add tests for new features or bug fixes
4. Ensure all tests pass
5. Update the CHANGELOG.md
6. Create a descriptive PR title and description
7. Link related issues
8. Request review from maintainers

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
Describe tests added/updated

## Checklist
- [ ] Code follows style guidelines
- [ ] Tests pass locally
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
```

## Testing Guidelines

### Running Tests

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:coverage

# Run specific test file
npm test -- path/to/test.test.js
```

### Writing Tests

- Write unit tests for all new functions
- Aim for > 80% code coverage
- Mock external dependencies
- Test both success and error cases
- Use descriptive test names

Example:
```javascript
describe('getSystemContext', () => {
  it('should return system context successfully', async () => {
    const req = {};
    const res = {
      json: jest.fn()
    };

    await getSystemContext(req, res);

    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: expect.any(Object)
    });
  });

  it('should handle errors gracefully', async () => {
    const req = {};
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };

    // Mock error scenario
    jest.spyOn(fetchSystemContext, 'mockRejectedValueOnce');

    await getSystemContext(req, res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: expect.any(String)
    });
  });
});
```

## Documentation

### Updating Documentation

- Keep README.md up to date with major changes
- Update API documentation for API changes
- Add comments to complex code
- Document new features in appropriate docs/
- Update CHANGELOG.md for all changes

### Documentation Files

- `README.md` - Project overview and quick start
- `docs/api.md` - API documentation
- `docs/architecture.md` - System architecture
- `docs/setup.md` - Setup and installation
- `CONTRIBUTING.md` - This file
- `CHANGELOG.md` - Version history

## Questions or Issues?

- Check existing [Issues](https://github.com/your-username/SEOMP/issues)
- Create a new issue for bugs or feature requests
- Contact maintainers for questions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
