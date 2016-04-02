'use strict';

const app = require('express')();
const constants = require('./constants');

app.use('/', require('./routers/scripts-router.js')(constants.path));

let server = app.listen(4204, () => {
  console.log(`Listening on port ${server.address().port}`);
});
