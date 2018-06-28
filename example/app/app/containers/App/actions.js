// @flow

import * as constants from './constants';
import type { ActionType } from '../../types';

export function setup(): ActionType {
  return {
    type: 'SETUP',
    value: null,
  };
}

export function defaultAction(): ActionType {
  return {
    type: constants.DEFAULT_ACTION,
    value: null,
  };
}
