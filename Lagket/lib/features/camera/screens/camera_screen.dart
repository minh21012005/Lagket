import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../providers/camera_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  Future<void> _initCamera() async {
    final cameras = await ref.read(availableCamerasProvider.future);
    await ref.read(cameraNotifierProvider.notifier).initialize(cameras);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    final cameraState = ref.read(cameraNotifierProvider);
    if (!cameraState.isInitialized) return;
    if (lifecycleState == AppLifecycleState.inactive) {
      ref.read(cameraNotifierProvider.notifier).controller?.dispose();
    } else if (lifecycleState == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _capture() async {
    final path =
        await ref.read(cameraNotifierProvider.notifier).capture();
    if (path != null && mounted) {
      ref.read(capturedFileProvider.notifier).state = File(path);
      context.push('/preview');
    }
  }

  IconData _flashIcon(FlashMode mode) {
    switch (mode) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
        return Icons.flash_on_rounded;
      default:
        return Icons.flash_off_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final camState = ref.watch(cameraNotifierProvider);
    final controller =
        ref.read(cameraNotifierProvider.notifier).controller;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Flash toggle
          IconButton(
            icon: Icon(_flashIcon(camState.flashMode),
                color: Colors.white, size: 26),
            onPressed: camState.isInitialized
                ? () => ref
                    .read(cameraNotifierProvider.notifier)
                    .cycleFlash()
                : null,
          ),
          // Feed
          IconButton(
            icon:
                const Icon(Icons.photo_library_rounded, color: Colors.white),
            onPressed: () => context.push('/feed'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          if (camState.isInitialized && controller != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: CameraPreview(controller),
              ),
            )
          else if (camState.error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_rounded,
                        color: AppColors.textHint, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      camState.error!,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Profile button
                  IconButton(
                    onPressed: () => context.push('/profile'),
                    icon: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 28),
                  ),

                  // Capture button
                  GestureDetector(
                    onTap: camState.isInitialized ? _capture : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: camState.isCapturing ? 72 : 80,
                      height: camState.isCapturing ? 72 : 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 4),
                        gradient: camState.isCapturing
                            ? null
                            : AppColors.primaryGradient,
                        color: camState.isCapturing
                            ? Colors.white24
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: camState.isCapturing
                          ? const Center(
                              child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ))
                          : null,
                    ),
                  ),

                  // Flip camera button
                  IconButton(
                    onPressed: camState.isInitialized
                        ? () async {
                            final cameras = await ref
                                .read(availableCamerasProvider.future);
                            ref
                                .read(cameraNotifierProvider.notifier)
                                .toggleCamera(cameras);
                          }
                        : null,
                    icon: const Icon(Icons.flip_camera_ios_rounded,
                        color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
