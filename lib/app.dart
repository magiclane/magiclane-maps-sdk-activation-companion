// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'package:activation_companion/client/activation_service_client.dart';
import 'package:activation_companion/ui/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key, required this.activationServiceClient});

  final ActivationServiceClient activationServiceClient;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: activationServiceClient,
      child: MaterialApp(
        title: 'Activation Companion',
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const HomePage(),
      ),
    );
  }

  static ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: brightness),
  );
}
