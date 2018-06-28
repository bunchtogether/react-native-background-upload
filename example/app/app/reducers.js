// @flow

/**
 * Combine all reducers in this file and export the combined reducers.
 * If we were to do this in store.js, reducers wouldn't be hot reloadable.
 */

import { combineReducers } from 'redux-immutable';
import { AppNavigator } from './containers/App';
import appReducer from './containers/App/reducer';

/**
 * Creates the main reducer with the asynchronously loaded ones
 */
export default function createReducer() {
  return combineReducers({
    nav: (state, action) => AppNavigator.router.getStateForAction(action, state),
    app: appReducer,
  });
}
