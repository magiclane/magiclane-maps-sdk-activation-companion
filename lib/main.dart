// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'package:activation_companion/app.dart';
import 'package:activation_companion/client/activation_service_client.dart';
import 'package:flutter/widgets.dart';

void main() => runApp(CompanionApp(activationServiceClient: ActivationServiceClient()));
