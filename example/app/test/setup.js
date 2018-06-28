//import fs from 'fs';
//import path from 'path';
//import register from 'babel-core/register';
//import mock from 'mock-require';
//
//// Ignore all node_modules except these
//const modulesToCompile = [
//  'react-native',
//  "react-native-vector-icons",
//  'react-native-mock',
//  'react-navigation'
//].map((moduleName) => new RegExp(`/node_modules/${moduleName}`));
//
//const rcPath = path.join(__dirname, '..', '.babelrc');
//const source = fs.readFileSync(rcPath).toString();
//const config = JSON.parse(source);
//config.ignore = function(filename) {
//  if (!(/\/node_modules\//).test(filename)) {
//    return false;
//  } else {
//    const matches = modulesToCompile.filter((regex) => regex.test(filename));
//    const shouldIgnore = matches.length === 0;
//    return shouldIgnore;
//  }
//}
//register(config);
//// Setup globals / chai
//global.__DEV__ = true;
//// Setup mocks
//require('react-native-mock/mock');
//const React = require('react-native')
//
//mock('react-navigation', { 
//  StackNavigator : () => React.View,
//  addNavigationHelpers: () => {},
//});

import { configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';

configure({ adapter: new Adapter() });