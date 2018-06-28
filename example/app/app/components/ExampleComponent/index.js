// @flow

import React from 'react';
import { connect } from 'react-redux';
import { View } from 'react-native';
import type { StateType } from '../../types';

type Props = {};

export class ExampleComponent extends React.Component<Props> { // eslint-disable-line react/prefer-stateless-function
  render() {
    return (
      <View />
    );
  }
}

export default connect(
  (state: StateType): Object => ({
    state: state.toJS(),
  }),
)(ExampleComponent);
