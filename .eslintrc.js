module.exports = {
  env: {
    browser: false,
    node: true,
    es2022: true
  },
  extends: ['eslint:recommended'],
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module'
  },
  rules: {
    'no-unused-vars': ['warn', { argsIgnorePattern: 'next' }],
    'no-console': 'off',
    'prefer-const': 'warn',
    'no-undef': 'error',
    'consistent-return': 'off'
  },
  ignorePatterns: ['node_modules/', 'coverage/', 'dist/', 'build/']
};
