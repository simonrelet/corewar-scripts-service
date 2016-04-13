'use strict';

const config = require('./config.json');
const defaultConfig = {
  port: 4204,
  script: 'scripts/corewar.sh',
  address: 'localhost',
  pitPort: 4201,
  stadiumPort: 4202
};

module.exports = {
  config: Object.assign(defaultConfig, config),
  versionRegex: /^VERSION="(.*)"$/m,
  addressRegex: /^(ADDRESS=").*(")$/m,
  pitPortRegex: /^(PIT_PORT=").*(")$/m,
  stadiumPortRegex: /^(STADIUM_PORT=").*(")$/m,
  scriptPortRegex: /^(SCRIPT_PORT=").*(")$/m
};
