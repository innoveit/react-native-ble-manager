---
layout: page
title: Troubleshooting
permalink: /troubleshooting/
nav_order: 4
---

# Troubleshooting

- Remember to use the `start` method before anything.
- If you have problem with old devices try avoid to connect/read/write to a peripheral during scan.
- Android API >= 23 require the ACCESS_COARSE_LOCATION permission to scan for peripherals. React Native >= 0.33 natively support PermissionsAndroid like in the example.
- Android API >= 29 require the ACCESS_FINE_LOCATION permission to scan for peripherals.
  React-Native 0.63.X started targeting Android API 29.
- Before write, read or start notification you need to call `retrieveServices` method
- Because location and bluetooth permissions are runtime permissions, you **must** request these permissions at runtime along with declaring them in your manifest.