// @flow

import runAuthTests from 'shared-redux/src/auth/test';
import AuthTestAdapter from 'shared-redux/src/auth/test-adapter';

runAuthTests(new AuthTestAdapter());

