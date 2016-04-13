'use strict';

const app = require('express')();
const constants = require('./constants');

app.use('/', require('./routers/scripts-router.js')(constants.config.script));

let server = app.listen(constants.config.port, () => {
  console.log(`Listening on port ${server.address().port}`);
});
