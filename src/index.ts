/* eslint-disable @typescript-eslint/ban-types */
export * from './types';
export * from './emitter';

import BleManager from './manager';
export { default as bleEventEmitter } from './emitter';
export { default as BleError } from './BleError';

export default BleManager;
