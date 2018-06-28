// @flow

import React from 'react';
import { shallow } from 'enzyme';
import { App } from '../index';

it('should render', (): void => {
  shallow(<App nav={{}} dispatch={() => {}} setup={() => {}} />);
});

