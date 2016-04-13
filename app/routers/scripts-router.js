'use strict';

const fsp = require('fs-promise');
const express = require('express');
const bodyParser = require('body-parser');
const constants = require('../constants');

let sendResult = res => {
  return result => {
    res.send(result);
  };
};

let handleError = res => {
  return () => {
    res.send('Error: Could not find script.');
  };
};

let readFileSafe = (res, path) => {
  return fsp.readFile(path, {
    encoding: 'utf8'
  });
};

let wrap = value => {
  return `$1${value}$2`;
};

let replaceConstants = content => {
  return Promise.resolve(content
    .replace(constants.addressRegex, wrap(constants.config.address))
    .replace(constants.pitPortRegex, wrap(constants.config.pitPort))
    .replace(constants.stadiumPortRegex, wrap(constants.config.stadiumPort))
    .replace(constants.scriptPortRegex, wrap(constants.config.port))
  );
};

let getVersionFrom = content => {
  return content.match(constants.versionRegex)[1];
};

module.exports = path => {
  let router = express.Router();
  router.use(bodyParser.json());
  router.use(bodyParser.urlencoded({
    extended: true
  }));

  router.all('/', (req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Headers', 'X-Requested-With');
    next();
  });

  router.get('/', (req, res) => {
    readFileSafe(res, path)
      .then(replaceConstants)
      .then(sendResult(res))
      .catch(handleError(res));
  });

  router.get('/version', (req, res) => {
    readFileSafe(res, path)
      .then(content => {
        sendResult(res)(getVersionFrom(content));
      })
      .catch(handleError(res));
  });
  return router;
};
