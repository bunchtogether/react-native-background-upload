// @flow

import { put, takeEvery } from 'redux-saga/effects';
import type { IOEffect } from 'redux-saga/effects';
import * as constants from './constants';

export function* setupCompleteSaga(): Generator<IOEffect, *, *> {
  yield put({ type: constants.DEFAULT_SIDE_EFFECT, value: true });
}

export default function* defaultSaga(): Generator<IOEffect, *, *> {
  yield takeEvery('SETUP_COMPLETE', setupCompleteSaga);
}
