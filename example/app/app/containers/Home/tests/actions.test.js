// @flow

import expect from 'expect';
import * as actions from '../actions';
import * as constants from '../constants';

it('has a type of DEFAULT_ACTION', (): void => {
  const expected = {
    type: constants.DEFAULT_ACTION,
    value: null,
  };
  expect(actions.defaultAction()).toEqual(expected);
});

