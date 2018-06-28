// @flow

import { fromJS } from 'immutable';
import * as constants from './constants';
import type { ActionType, StateType } from '../../types';

const initialState = fromJS({});

const actionsMap = {
  [constants.DEFAULT_ACTION](state: StateType) {
    return state;
  },
};

export default (state: StateType = initialState, action: ActionType) => {
  const reduceFn = actionsMap[action.type];
  if (!reduceFn) return state;
  return reduceFn(state, action);
};
