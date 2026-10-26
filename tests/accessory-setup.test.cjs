const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { test } = require('node:test');
const { runInNewContext } = require('node:vm');
const ts = require('typescript');

function loadManager(native, turbo) {
  const source = ts.transpileModule(
    readFileSync(require.resolve('../src/index.ts'), 'utf8'),
    { compilerOptions: { module: ts.ModuleKind.CommonJS } }
  ).outputText;
  const context = {
    exports: {},
    global: { __turboModuleProxy: turbo ? {} : undefined },
    require: (name) => {
      if (name === 'react-native')
        return { NativeModules: { BleManager: native } };
      if (name === './NativeBleManager') return { default: native };
      return {};
    },
  };
  runInNewContext(source, context);
  return context.exports.default;
}

for (const turbo of [false, true]) {
  test(`platform-specific setup contracts (${turbo ? 'TurboModule' : 'NativeModules'})`, async () => {
    const accessories = [
      { id: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', name: 'Sensor', state: 20 },
    ];
    const items = [
      { name: 'Sensor', productImage: 'heart.fill', serviceUUID: '180D' },
    ];
    const subscription = { remove() {} };
    const calls = [];
    const manager = loadManager(
      {
        supportsAccessorySetup: (callback) => callback(true),
        accessoriesScan: (value) => {
          calls.push(value);
          return Promise.resolve(accessories);
        },
        getPairedAccessories: () => Promise.resolve(accessories),
        removeAccessory: (id) => {
          calls.push(id);
          return Promise.resolve();
        },
        stopAccessoriesScan: () => {
          calls.push('stop');
        },
        supportsCompanion: (callback) => callback(true),
        companionScan: (_uuids, _options, callback) => callback(null, null),
        getAssociatedPeripherals: (callback) => callback(null, accessories),
        removeAssociatedPeripheral: (_id, callback) => callback(null),
        onCompanionPeripheral: () => subscription,
      },
      turbo
    );

    assert.equal(await manager.supportsAccessorySetup(), true);
    assert.equal(await manager.accessoriesScan(items), accessories);
    assert.equal(await manager.getPairedAccessories(), accessories);
    await manager.removeAccessory(accessories[0].id);
    manager.stopAccessoriesScan();
    assert.deepEqual(calls, [items, accessories[0].id, 'stop']);
    assert.equal(await manager.supportsCompanion(), true);
    assert.equal(await manager.companionScan([]), null);
    assert.equal(await manager.getAssociatedPeripherals(), accessories);
    await manager.removeAssociatedPeripheral(accessories[0].id);
    assert.equal(
      manager.onCompanionPeripheral(() => {}),
      subscription
    );
  });

  test(`unsupported platforms and cancellation propagate (${turbo ? 'TurboModule' : 'NativeModules'})`, async () => {
    let cancel;
    const manager = loadManager(
      {
        supportsAccessorySetup: (callback) => callback(false),
        getPairedAccessories: () =>
          Promise.reject(
            Object.assign(new Error('Unsupported'), { code: 'NOT_SUPPORTED' })
          ),
        removeAccessory: () =>
          Promise.reject(
            Object.assign(new Error('Missing'), { code: 'ACCESSORY_NOT_FOUND' })
          ),
        accessoriesScan: () =>
          new Promise((_resolve, reject) => {
            cancel = reject;
          }),
        stopAccessoriesScan: () =>
          cancel(Object.assign(new Error('Cancelled'), { code: 'CANCELLED' })),
      },
      turbo
    );

    assert.equal(await manager.supportsAccessorySetup(), false);
    await assert.rejects(manager.getPairedAccessories(), {
      code: 'NOT_SUPPORTED',
    });
    await assert.rejects(manager.removeAccessory('missing'), {
      code: 'ACCESSORY_NOT_FOUND',
    });
    const pending = manager.accessoriesScan([]);
    manager.stopAccessoriesScan();
    await assert.rejects(pending, { code: 'CANCELLED' });
  });
}
