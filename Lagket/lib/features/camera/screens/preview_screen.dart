import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../providers/camera_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';

class PreviewScreen extends ConsumerWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(capturedFileProvider);

    if (file == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.close_circle, color: Colors.white, size: 28),
          onPressed: () {
            ref.read(capturedFileProvider.notifier).state = null;
            ref.read(cameraNotifierProvider.notifier).clearCapture();
            context.pop();
          },
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Preview image
          Image.file(
            file,
            fit: BoxFit.cover,
          ),

          // Bottom actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 48),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Looking good! 🔥',
                    style: AppTextStyles.headlineLarge,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Retake',
                          onPressed: () {
                            ref
                                .read(capturedFileProvider.notifier)
                                .state = null;
                            ref
                                .read(cameraNotifierProvider.notifier)
                                .clearCapture();
                            context.pop();
                          },
                          variant: AppButtonVariant.secondary,
                          borderRadius: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: 'Send',
                          onPressed: () => context.push('/send'),
                          icon: Iconsax.send_1,
                          borderRadius: 14,
                        ),
                      ),
                    ],
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
