import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../notification/services/fcm_service.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera();
      if (!kIsWeb) {
        FCMService().requestPermissionsAndToken();
      }
    });
  }

  Future<void> _initCamera() async {
    await Future.microtask(() async {
      final cameras = await ref.read(availableCamerasProvider.future);
      await ref.read(cameraNotifierProvider.notifier).initialize(cameras);
    });
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
        return Iconsax.flash_slash;
      case FlashMode.auto:
        return Iconsax.flash;
      case FlashMode.always:
        return Iconsax.flash_1;
      default:
        return Iconsax.flash_slash;
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
                color: Colors.white, size: 22),
            onPressed: camState.isInitialized
                ? () => ref
                    .read(cameraNotifierProvider.notifier)
                    .cycleFlash()
                : null,
          ),
          // Profile (top-right)
          IconButton(
            icon: const Icon(Iconsax.user, color: Colors.white, size: 22),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: GestureDetector(
        // Swipe down → History
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            context.push('/history');
          }
        },
        child: Stack(
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
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Iconsax.camera_slash,
                            color: AppColors.error, size: 60),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Camera Access Denied',
                        style: AppTextStyles.displayMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Lagket needs camera access so you can take and share photos with your friends.',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => openAppSettings(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Open Settings',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => _initCamera(),
                        child: const Text('Try Again', 
                          style: TextStyle(color: AppColors.textSecondary)),
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
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 110),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // History Button (Left)
                    GestureDetector(
                      onTap: () => context.push('/history'),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Iconsax.gallery,
                            color: Colors.white, size: 24),
                      ),
                    ),

                    // Capture button (Center)
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
                              color: AppColors.primary.withValues(alpha: 0.5),
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

                    // Flip camera button (Right)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: camState.isInitialized
                            ? () async {
                                final cameras = await ref
                                    .read(availableCamerasProvider.future);
                                ref
                                    .read(cameraNotifierProvider.notifier)
                                    .toggleCamera(cameras);
                              }
                            : null,
                        icon: const Icon(Iconsax.rotate_left_1,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
