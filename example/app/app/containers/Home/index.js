// @flow

import React from 'react';
import { connect } from 'react-redux';
import { bindActionCreators } from 'redux';
import { View, Text } from 'react-native';
import type { StateType } from '../../types';
import * as actionCreators from './actions';
import * as selectors from './selectors';

type Props = {};

export class Home extends React.Component<Props> { // eslint-disable-line react/prefer-stateless-function
  static navigationOptions = {
    title: 'Home',
  };

  render() {
    return (
      <View>
        <Text>Hello World!</Text>
      </View>
    );
  }
}

export default connect(
  (state: StateType): Object => ({
    state: selectors.selector(state),
  }),
  (dispatch: Function): Object => bindActionCreators(actionCreators, dispatch),
)(Home);
