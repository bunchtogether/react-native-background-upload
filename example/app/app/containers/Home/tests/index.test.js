// @flow

import React from 'react';
import expect from 'expect';
import { shallow } from 'enzyme';
import { View } from 'react-native';
import { Home } from '../index';

it('should render', (): void => {
  const wrapper = shallow(<Home state={{}} />);
  expect(wrapper.type()).toEqual(View);
});
