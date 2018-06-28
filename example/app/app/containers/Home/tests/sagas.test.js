// @flow

import SagaTester from 'redux-saga-tester';
import expect from 'expect';
import { fromJS } from 'immutable';
import sagas from '../sagas';
import { defaultAction } from '../actions';
import * as constants from '../constants';

it('should do nothing for the default action.', async () => {
  const sagaTester = new SagaTester(fromJS({}));
  sagaTester.start(sagas);

  const actionPromise = sagaTester.waitFor(constants.DEFAULT_SIDE_EFFECT, true);
  sagaTester.dispatch(defaultAction());
  await actionPromise;
  expect(true).toEqual(true);
});

