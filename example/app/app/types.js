// @flow

import type { Map } from 'immutable';


export type ActionType = {
  type: string,
  value: any
};

export type StateType = Map<string, *>;
