// @flow

import { createSelector } from 'reselect';
import type { StateType } from '../../types';

export const selector = (state: StateType):any => state.toJS();

export const subSelector = createSelector(
  selector,
  (data): Object => data,
);

export default selector;
