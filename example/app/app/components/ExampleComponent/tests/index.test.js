// @flow

import React from 'react';
import expect from 'expect';
import { shallow } from 'enzyme';
import { View } from 'react-native';
import { ExampleComponent } from '../index';


it('should render', (): void => {
  const wrapper = shallow(<ExampleComponent state={{}} />);
  expect(wrapper.type()).toEqual(View);
});

