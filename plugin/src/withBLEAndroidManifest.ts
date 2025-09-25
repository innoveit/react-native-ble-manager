import {
  ConfigPlugin,
  withAndroidManifest,
  AndroidConfig,
} from 'expo/config-plugins';

type InnerManifest = AndroidConfig.Manifest.AndroidManifest['manifest'];

type ManifestPermission = InnerManifest['permission'];

type ExtraTools = {
  // https://developer.android.com/studio/write/tool-attributes#toolstargetapi
  'tools:targetApi'?: string;
};

type ManifestUsesPermissionWithExtraTools = {
  $: AndroidConfig.Manifest.ManifestUsesPermission['$'] & ExtraTools;
};

type AndroidManifest = {
  manifest: InnerManifest & {
    'permission'?: ManifestPermission;
    'uses-permission'?: ManifestUsesPermissionWithExtraTools[];
    'uses-permission-sdk-23'?: ManifestUsesPermissionWithExtraTools[];
    'uses-feature'?: InnerManifest['uses-feature'];
  };
};

export const withBLEAndroidManifest: ConfigPlugin<{
  isBleRequired: boolean;
  neverForLocation: boolean;
  companionDeviceEnabled: boolean;
}> = (config, { isBleRequired, neverForLocation, companionDeviceEnabled }) => {
  return withAndroidManifest(config, (config) => {
    config.modResults = addLocationPermissionToManifest(
      config.modResults,
      neverForLocation
    );
    config.modResults = addScanPermissionToManifest(
      config.modResults,
      neverForLocation
    );
    config.modResults = addConnectPermissionToManifest(
      config.modResults,
      neverForLocation
    );
    if (companionDeviceEnabled) {
      config.modResults = addCompanionPermissionToManifest(config.modResults);
    }
    if (isBleRequired) {
      config.modResults = addBLEHardwareFeatureToManifest(config.modResults);
    }
    return config;
  });
};

/**
 * Add location permissions
 *  - 'android.permission.ACCESS_COARSE_LOCATION' for Android SDK 28 (Android 9) and lower
 *  - 'android.permission.ACCESS_FINE_LOCATION' for Android SDK 29 (Android 10) and higher.
 *    From Android SDK 31 (Android 12) it might not be required if BLE is not used for location.
 */
export function addLocationPermissionToManifest(
  androidManifest: AndroidManifest,
  neverForLocationSinceSdk31: boolean
) {
  const existingPermissionNames = new Set<string>();

  if (Array.isArray(androidManifest.manifest['uses-permission'])) {
    for (const item of androidManifest.manifest['uses-permission']) {
      const permissionName = item?.$?.['android:name'];
      if (permissionName) {
        existingPermissionNames.add(permissionName);
      }
    }
  }

  if (Array.isArray(androidManifest.manifest['uses-permission-sdk-23'])) {
    for (const item of androidManifest.manifest['uses-permission-sdk-23']) {
      const permissionName = item?.$?.['android:name'];
      if (permissionName) {
        existingPermissionNames.add(permissionName);
      }
    }
  }

  const optMaxSdkVersion = neverForLocationSinceSdk31
    ? {
        'android:maxSdkVersion': '30',
      }
    : {};

  const permissionsToAdd: ManifestUsesPermissionWithExtraTools[] = [];

  if (
    !existingPermissionNames.has('android.permission.ACCESS_COARSE_LOCATION')
  ) {
    permissionsToAdd.push({
      $: {
        'android:name': 'android.permission.ACCESS_COARSE_LOCATION',
        ...optMaxSdkVersion,
      },
    });
  }

  if (!existingPermissionNames.has('android.permission.ACCESS_FINE_LOCATION')) {
    permissionsToAdd.push({
      $: {
        'android:name': 'android.permission.ACCESS_FINE_LOCATION',
        ...optMaxSdkVersion,
      },
    });
  }

  if (permissionsToAdd.length) {
    if (!Array.isArray(androidManifest.manifest['uses-permission-sdk-23'])) {
      androidManifest.manifest['uses-permission-sdk-23'] = [];
    }

    androidManifest.manifest['uses-permission-sdk-23']!.push(
      ...permissionsToAdd
    );
  }

  return androidManifest;
}

/**
 * Add 'android.permission.BLUETOOTH_SCAN'.
 * Required since Android SDK 31 (Android 12).
 */
export function addScanPermissionToManifest(
  androidManifest: AndroidManifest,
  neverForLocation: boolean
) {
  if (!Array.isArray(androidManifest.manifest['uses-permission'])) {
    androidManifest.manifest['uses-permission'] = [];
  }

  if (
    !androidManifest.manifest['uses-permission'].find(
      (item) => item.$['android:name'] === 'android.permission.BLUETOOTH_SCAN'
    )
  ) {
    AndroidConfig.Manifest.ensureToolsAvailable(androidManifest);
    androidManifest.manifest['uses-permission']?.push({
      $: {
        'android:name': 'android.permission.BLUETOOTH_SCAN',
        ...(neverForLocation
          ? {
              'android:usesPermissionFlags': 'neverForLocation',
            }
          : {}),
        'tools:targetApi': '31',
      },
    });
  }
  return androidManifest;
}

export function addConnectPermissionToManifest(
  androidManifest: AndroidManifest,
  neverForLocation: boolean
) {
  if (!Array.isArray(androidManifest.manifest['uses-permission'])) {
    androidManifest.manifest['uses-permission'] = [];
  }

  if (
    !androidManifest.manifest['uses-permission'].find(
      (item) =>
        item.$['android:name'] === 'android.permission.BLUETOOTH_CONNECT'
    )
  ) {
    AndroidConfig.Manifest.ensureToolsAvailable(androidManifest);
    androidManifest.manifest['uses-permission']?.push({
      $: {
        'android:name': 'android.permission.BLUETOOTH_CONNECT',
      },
    });
  }
  return androidManifest;
}

export function addCompanionPermissionToManifest(
  androidManifest: AndroidManifest
) {
  if (!Array.isArray(androidManifest.manifest['uses-feature'])) {
    androidManifest.manifest['uses-feature'] = [];
  }

  if (
    !androidManifest.manifest['uses-feature'].find(
      (item) =>
        item.$['android:name'] === 'android.software.companion_device_setup'
    )
  ) {
    androidManifest.manifest['uses-feature']?.push({
      $: {
        'android:name': 'android.software.companion_device_setup',
        'android:required': 'true',
      },
    });
  }
  return androidManifest;
}

// Add this line if your application always requires BLE. More info can be found on: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions
export function addBLEHardwareFeatureToManifest(
  androidManifest: AndroidConfig.Manifest.AndroidManifest
) {
  // Add `<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>` to the AndroidManifest.xml
  if (!Array.isArray(androidManifest.manifest['uses-feature'])) {
    androidManifest.manifest['uses-feature'] = [];
  }

  if (
    !androidManifest.manifest['uses-feature'].find(
      (item) => item.$['android:name'] === 'android.hardware.bluetooth_le'
    )
  ) {
    androidManifest.manifest['uses-feature']?.push({
      $: {
        'android:name': 'android.hardware.bluetooth_le',
        'android:required': 'true',
      },
    });
  }
  return androidManifest;
}
