// @flow

/**
 * app.js
 *
 * This is the entry file for the application, only setup and boilerplate
 * code.
 */

// Import all the third party stuff
import React from 'react';
import { AppRegistry } from 'react-native';
import { Provider } from 'react-redux';
import configureStore from './store';
import App from './containers/App';

// Create redux store
const initialState = {};
const store = configureStore(initialState);

const render = () => (
  <Provider store={store}>
    <App />
  </Provider>
);

AppRegistry.registerComponent('Boilerplate', () => render);

