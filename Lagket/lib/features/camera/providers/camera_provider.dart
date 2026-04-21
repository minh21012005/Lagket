import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'dart:io';

// ─── Available cameras ────────────────────────────────────────────────────────

final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  return await availableCameras();
});

// ─── Camera state ─────────────────────────────────────────────────────────────

class CameraState {
  final bool isInitialized;
  final bool isFrontCamera;
  final FlashMode flashMode;
  final bool isCapturing;
  final String? capturedImagePath;
  final String? error;

  const CameraState({
    this.isInitialized = false,
    this.isFrontCamera = true,
    this.flashMode = FlashMode.off,
    this.isCapturing = false,
    this.capturedImagePath,
    this.error,
  });

  CameraState copyWith({
    bool? isInitialized,
    bool? isFrontCamera,
    FlashMode? flashMode,
    bool? isCapturing,
    String? capturedImagePath,
    String? error,
  }) =>
      CameraState(
        isInitialized: isInitialized ?? this.isInitialized,
        isFrontCamera: isFrontCamera ?? this.isFrontCamera,
        flashMode: flashMode ?? this.flashMode,
        isCapturing: isCapturing ?? this.isCapturing,
        capturedImagePath: capturedImagePath ?? this.capturedImagePath,
        error: error ?? this.error,
      );
}

class CameraNotifier extends StateNotifier<CameraState> {
  CameraController? controller;

  CameraNotifier() : super(const CameraState());

  Future<void> initialize(List<CameraDescription> cameras) async {
    if (cameras.isEmpty) {
      state = state.copyWith(error: 'No cameras found on this device.');
      return;
    }

    final description = state.isFrontCamera
        ? cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first,
          )
        : cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );

    await controller?.dispose();
    controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller!.initialize();
      await controller!.setFlashMode(state.flashMode);
      state = state.copyWith(isInitialized: true, error: null);
    } catch (e) {
      state = state.copyWith(error: 'Failed to initialize camera: $e');
    }
  }

  Future<void> toggleCamera(List<CameraDescription> cameras) async {
    state = state.copyWith(
      isFrontCamera: !state.isFrontCamera,
      isInitialized: false,
    );
    await initialize(cameras);
  }

  Future<void> cycleFlash() async {
    FlashMode next;
    switch (state.flashMode) {
      case FlashMode.off:
        next = FlashMode.auto;
        break;
      case FlashMode.auto:
        next = FlashMode.always;
        break;
      case FlashMode.always:
        next = FlashMode.off;
        break;
      default:
        next = FlashMode.off;
    }
    await controller?.setFlashMode(next);
    state = state.copyWith(flashMode: next);
  }

  Future<String?> capture() async {
    if (!state.isInitialized || state.isCapturing) return null;
    state = state.copyWith(isCapturing: true);
    try {
      final file = await controller!.takePicture();
      state = state.copyWith(
          isCapturing: false, capturedImagePath: file.path);
      return file.path;
    } catch (e) {
      state = state.copyWith(isCapturing: false, error: 'Capture failed: $e');
      return null;
    }
  }

  void clearCapture() => state = state.copyWith(capturedImagePath: null);

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

final cameraNotifierProvider =
    StateNotifierProvider<CameraNotifier, CameraState>((ref) {
  return CameraNotifier();
});

// Captured file provider for passing between screens
final capturedFileProvider = StateProvider<File?>((ref) => null);

// Caption for the captured photo
final captionProvider = StateProvider<String>((ref) => "");

// Whether the photo is private
final isPrivateProvider = StateProvider<bool>((ref) => false);
