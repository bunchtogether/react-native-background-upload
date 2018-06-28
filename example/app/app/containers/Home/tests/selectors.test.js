// @flow

import { fromJS } from 'immutable';
import expect from 'expect';
import { selector, subSelector } from '../selectors';


it('should select', (): void => {
  const data = {
    default: 'default',
  };
  expect(selector(fromJS(data))).toEqual(data);
  expect(subSelector(fromJS(data))).toEqual(data);
});
