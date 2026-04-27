const pino = require('pino');

const level = process.env.LOG_LEVEL || 'info';

let transport;

try {
  require.resolve('pino-pretty');
  transport = {
    target: 'pino-pretty',
    options: {
      colorize: true,
      translateTime: 'SYS:standard',
      ignore: 'pid,hostname'
    }
  };
} catch (error) {
  transport = undefined;
}

const logger = pino({
  level,
  transport
});

module.exports = { logger };
