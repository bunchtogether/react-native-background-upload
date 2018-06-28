/**
 * Create the store with asynchronously loaded reducers
 */

import { Platform } from 'react-native';
import { createStore, applyMiddleware, compose } from 'redux';
import Immutable from 'immutable';
import createSagaMiddleware from 'redux-saga';
import installDevTools from 'immutable-devtools';
import remoteReduxDevtools from 'remote-redux-devtools';

import createReducer from './reducers';
import packageJson from '../package.json';

import appSagas from './containers/App/sagas';

const sagaMiddleware = createSagaMiddleware();

export default function configureStore(initialState = {}) {
  const middlewares = [
    sagaMiddleware,
  ];

  const enhancers = [
    applyMiddleware(...middlewares),
  ];

  // eslint-disable
  const composeEnhancers =
    typeof window === 'object' &&
      window.__REDUX_DEVTOOLS_EXTENSION_COMPOSE__ ?
      window.__REDUX_DEVTOOLS_EXTENSION_COMPOSE__({
        // Specify extension’s options like name, actionsBlacklist, actionsCreators, serialize...
      }) : compose;
  // const composeEnhancers = compose;
  // eslint-enable

  const store = createStore(
    createReducer(),
    Immutable.fromJS(initialState),
    composeEnhancers(...enhancers),
  );

  // Extensions
  store.runSaga = sagaMiddleware.run;
  store.asyncReducers = {}; // Async reducer registry

  sagaMiddleware.run(appSagas);

  // Make reducers hot reloadable, see http://mxs.is/googmo
  /* istanbul ignore next */

  if (module.hot) {
    module.hot.accept('./reducers', () => {
      System.import('./reducers').then((reducerModule) => {
        const createReducers = reducerModule.default;
        const nextReducers = createReducers(store.asyncReducers);
        store.replaceReducer(nextReducers);
      });
    });
  }


  return store;
}
