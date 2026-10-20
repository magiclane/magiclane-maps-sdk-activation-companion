// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'package:flutter/widgets.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A scanner without a camera, whose pictures decode to [pictureCapture].
class FakeScannerPlatform extends MobileScannerPlatform {
  FakeScannerPlatform({this.pictureCapture});

  final BarcodeCapture? pictureCapture;
  final analyzedPictures = <String>[];

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async => const MobileScannerViewAttributes(
    cameraDirection: CameraFacing.back,
    currentTorchMode: TorchState.unavailable,
    size: Size(320, 320),
  );

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  Widget buildCameraView() => const SizedBox.expand();

  @override
  Future<BarcodeCapture?> analyzeImage(String path, {List<BarcodeFormat> formats = const []}) async {
    analyzedPictures.add(path);
    return pictureCapture;
  }
}

/// A picture picker that always returns [picture], recording the options it was asked with.
class FakeImagePicker extends ImagePickerPlatform {
  FakeImagePicker(this.picture);

  final XFile? picture;
  final requests = <(ImageSource, ImagePickerOptions)>[];

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    requests.add((source, options));
    return picture;
  }
}
