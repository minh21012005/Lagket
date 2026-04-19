import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/feed/providers/history_provider.dart';
import '../../../shared/models/photo_model.dart';
import '../../../shared/widgets/user_avatar.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

/// The calendar screen uses photosByDateProvider (already in history_provider).

// ─── Calendar Screen ──────────────────────────────────────────────────────────

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calAsync = ref.watch(calendarPhotosProvider);
    final photosByDate = ref.watch(photosByDateProvider);
    final user = ref.watch(currentUserProvider).value;

    final now = DateTime.now();
    final year = now.year;

    // Build month list from Jan → current month
    final months = List.generate(
      now.month,
      (i) => DateTime(year, i + 1),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppColors.primaryGradient.createShader(b),
                          child: Text(
                            'My Calendar',
                            style: AppTextStyles.headlineLarge.copyWith(
                              color: Colors.white,
                              fontSize: 26,
                            ),
                          ),
                        ),
                        Text(
                          'Your photo memories of $year',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Photo count badge
                  calAsync.when(
                    data: (photos) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.gallery,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${photos.length}',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            // ── Calendar body ─────────────────────────────────────────────────
            Expanded(
              child: calAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.error)),
                ),
                data: (_) => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: months.length,
                  // Show most recent month first (reverse)
                  itemBuilder: (_, rawIdx) {
                    final idx = months.length - 1 - rawIdx;
                    return _MonthSection(
                      month: months[idx],
                      photosByDate: photosByDate,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Month section ────────────────────────────────────────────────────────────

class _MonthSection extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, PhotoModel> photosByDate;
  const _MonthSection({required this.month, required this.photosByDate});

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateUtils.getDaysInMonth(month.year, month.month);
    // weekday: 1=Mon … 7=Sun in Dart. Grid starts at Mon.
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final leadingBlanks = firstWeekday - 1; // offset so Mon=col0

    final cells = leadingBlanks + daysInMonth;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              _monthName(month.month),
              style: AppTextStyles.headlineMedium
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),

          // Weekday headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: _weekdays
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textHint,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Day grid
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 4,
                childAspectRatio: 0.9,
              ),
              itemCount: cells,
              itemBuilder: (_, i) {
                if (i < leadingBlanks) return const SizedBox.shrink();
                final day = i - leadingBlanks + 1;
                final date = DateTime(month.year, month.month, day);
                final photo = photosByDate[date];
                return _DayCell(date: date, photo: photo);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) => const [
        '',
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][m];
}

// ─── Day cell ─────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime date;
  final PhotoModel? photo;
  const _DayCell({required this.date, this.photo});

  bool get _isToday {
    final n = DateTime.now();
    return date.year == n.year && date.month == n.month && date.day == n.day;
  }

  bool get _isFuture => date.isAfter(DateTime.now());

  @override
  Widget build(BuildContext context) {
    if (_isFuture) {
      return Center(
        child: Text(
          '${date.day}',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textHint.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    if (photo != null) {
      return GestureDetector(
        onTap: () => context.push('/photo/${photo!.id}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: photo!.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: AppColors.surfaceElevated),
                errorWidget: (_, __, ___) =>
                    Container(color: AppColors.surfaceElevated),
              ),
              // Day number overlay
              Positioned(
                bottom: 2,
                right: 4,
                child: Text(
                  '${date.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                ),
              ),
              if (_isToday)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // No photo — dot
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${date.day}',
          style: AppTextStyles.caption.copyWith(
            color: _isToday ? AppColors.primary : AppColors.textSecondary,
            fontWeight: _isToday ? FontWeight.w800 : FontWeight.w500,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isToday
                ? AppColors.primary
                : AppColors.textHint.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
