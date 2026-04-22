import 'package:iconsax/iconsax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../providers/camera_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/ai_service.dart';
import '../../../shared/widgets/app_button.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _captionController = TextEditingController();
  List<String> _suggestions = [];
  bool _isGenerating = false;
  late AnimationController _refreshController;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    // Reset caption when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(captionProvider.notifier).state = "";
      // Hiển thị caption mặc định trước
      setState(() {
        _suggestions = ref.read(aiServiceProvider).getDefaultCaptions();
      });
      _generateAISuggestions();
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _generateAISuggestions() async {
    final file = ref.read(capturedFileProvider);
    if (file == null) return;

    setState(() => _isGenerating = true);
    _refreshController.repeat();

    try {
      final suggestions =
          await ref.read(aiServiceProvider).generateCaptions(file);
      if (mounted) {
        setState(() => _suggestions = suggestions);
      }
    } catch (e) {
      // Giữ lại mặc định nếu lỗi AI
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        _refreshController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(capturedFileProvider);

    if (file == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.close_circle, color: Colors.white, size: 28),
          onPressed: () {
            ref.read(capturedFileProvider.notifier).state = null;
            ref.read(isPrivateProvider.notifier).state = false;
            ref.read(cameraNotifierProvider.notifier).clearCapture();
            context.pop();
          },
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Preview image
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(ref.read(cameraNotifierProvider).isFrontCamera ? -1.0 : 1.0, 1.0),
            child: Image.file(
              file,
              fit: BoxFit.cover,
            ),
          ),

          // Content Overlay
          Column(
            children: [
              const Spacer(),
              Container(
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
                    // Caption Input Area
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        maxLines: 2,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(color: Colors.white60),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (val) => ref.read(captionProvider.notifier).state = val,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // AI Suggestions
                    if (_suggestions.isNotEmpty || _isGenerating)
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            // Refresh Button
                            GestureDetector(
                              onTap: _isGenerating
                                  ? null
                                  : _generateAISuggestions,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: RotationTransition(
                                  turns: Tween(begin: 0.0, end: -1.0)
                                      .animate(_refreshController),
                                  child: const Icon(
                                    Iconsax.refresh,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            // Suggestions List
                            Expanded(
                              child: _isGenerating && _suggestions.isEmpty
                                  ? const SizedBox.shrink()
                                  : SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _suggestions
                                            .map((s) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 8),
                                                  child: ActionChip(
                                                    label: Text(s,
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.white)),
                                                    backgroundColor: Colors
                                                        .white
                                                        .withOpacity(0.1),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20)),
                                                    side: BorderSide.none,
                                                    onPressed: () {
                                                      _captionController.text =
                                                          s;
                                                      ref
                                                          .read(captionProvider
                                                              .notifier)
                                                          .state = s;
                                                    },
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    ),
                            ),
                          ],
                        ),
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
                                  .read(isPrivateProvider.notifier)
                                  .state = false;
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
            ],
          ),
        ],
      ),
    );
  }
}
