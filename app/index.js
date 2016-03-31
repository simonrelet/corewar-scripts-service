'use strict';

const app = require('express')();
const constants = require('./constants');

app.use('/pit', require('./routers/scripts-router.js')(constants.paths.pit));
app.use('/stadium', require('./routers/scripts-router.js')(constants.paths.stadium));

let server = app.listen(4204, () => {
  console.log(`Listening on port ${server.address().port}`);
});
