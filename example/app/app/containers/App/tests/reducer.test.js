// @flow

import expect from 'expect';
import { fromJS } from 'immutable';
import reducer from '../reducer';
import * as actions from '../actions';


it('should return the initial state', (): void => {
  expect(reducer(undefined, actions.defaultAction())).toEqual(fromJS({}));
});

