// @flow

import React from 'react';
import { connect } from 'react-redux';
import { bindActionCreators } from 'redux';
import { StackNavigator, addNavigationHelpers } from 'react-navigation';
import type { StateType } from '../../types';
import * as actionCreators from './actions';
import Home from '../Home';

export const AppNavigator = StackNavigator({ // eslint-disable-line new-cap
  Home: { screen: Home },
});

type Props = {
  nav: Object,
  dispatch: Function,
  setup: Function
};

export class App extends React.Component<Props> { // eslint-disable-line react/prefer-stateless-function
  static navigationOptions = {
    title: 'App',
  };

  componentWillMount() {
    this.props.setup();
  }

  render() {
    return (
      <AppNavigator
        navigation={addNavigationHelpers({
          dispatch: this.props.dispatch,
          state: this.props.nav,
        })}
      />
      // <Home />
    );
  }
}

export default connect(
  (state: StateType): Object => ({
    nav: state.get('nav'),
  }),
  (dispatch: Function): Object => bindActionCreators({ ...actionCreators, dispatch }, dispatch),
)(App);
