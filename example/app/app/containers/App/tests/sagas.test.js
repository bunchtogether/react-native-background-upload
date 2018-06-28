// @flow

import SagaTester from 'redux-saga-tester';
import expect from 'expect';
import { fromJS } from 'immutable';
import sagas from '../sagas';
import * as constants from '../constants';

it('should emit the default side effect after SETUP_COMPLETE.', async () => {
  const sagaTester = new SagaTester(fromJS({}));
  sagaTester.start(sagas);

  const actionPromise = sagaTester.waitFor(constants.DEFAULT_SIDE_EFFECT, true);
  sagaTester.dispatch({ type: 'SETUP_COMPLETE', value: true });
  await actionPromise;
  expect(true).toEqual(true);
});
