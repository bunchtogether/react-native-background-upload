const path = require('path');

module.exports = {
  resolve: {
    alias: {
      "shared-redux": path.resolve(__dirname, '../../app/vendor/shared-redux'),
    }
  }
};