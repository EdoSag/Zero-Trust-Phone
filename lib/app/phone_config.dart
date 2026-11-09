import 'package:flutter/material.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// Phone in the suite. Not in the core's `ZtSuite` list yet, so the other
/// apps don't link to it before it's released.
const ZtSuiteApp phoneSuiteApp = ZtSuiteApp(
  appId: 'phone',
  name: 'Phone',
  tagline: 'Calls, with names from ZT Contacts',
  icon: Icons.call_outlined,
  accent: Color(0xFF8B5CF6), // violet
  androidPackage: 'dev.sagron.zerotrustphone',
);

const ZtAppConfig phoneAppConfig = ZtAppConfig(
  appId: 'phone',
  displayName: 'Zero-Trust Phone',
  accent: Color(0xFF8B5CF6),
);
