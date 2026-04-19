import 'dart:io';

void main() {
  final dir = Directory('lib');
  final map = {
    'Icons.arrow_back_ios_new_rounded': 'Iconsax.arrow_left',
    'Icons.settings_rounded': 'Iconsax.setting_2',
    'Icons.edit_rounded': 'Iconsax.edit',
    'Icons.people_rounded': 'Iconsax.people',
    'Icons.send_rounded': 'Iconsax.send_1',
    'Icons.calendar_month_rounded': 'Iconsax.calendar_1',
    'Icons.widgets_rounded': 'Iconsax.category',
    'Icons.chevron_right_rounded': 'Iconsax.arrow_right_3',
    'Icons.camera_alt_rounded': 'Iconsax.camera',
    'Icons.photo_camera_rounded': 'Iconsax.camera',
    'Icons.alternate_email_rounded': 'Iconsax.sms',
    'Icons.save_rounded': 'Iconsax.document_download',
    'Icons.shield_rounded': 'Iconsax.shield_tick',
    'Icons.notifications_rounded': 'Iconsax.notification',
    'Icons.notifications_none_rounded': 'Iconsax.notification',
    'Icons.notifications_active_rounded': 'Iconsax.notification_bing',
    'Icons.lock_open_rounded': 'Iconsax.unlock',
    'Icons.check_circle_rounded': 'Iconsax.tick_circle',
    'Icons.check_rounded': 'Iconsax.tick_square',
    'Icons.close_rounded': 'Iconsax.close_circle',
    'Icons.people_outline_rounded': 'Iconsax.people',
    'Icons.person_add_rounded': 'Iconsax.user_add',
    'Icons.broken_image': 'Iconsax.gallery_slash',
    'Icons.photo': 'Iconsax.gallery',
    'Icons.visibility_off': 'Iconsax.eye_slash',
    'Icons.visibility': 'Iconsax.eye',
    'Icons.error_outline': 'Iconsax.info_circle',
    'Icons.lock_reset_rounded': 'Iconsax.password_check',
    'Icons.email_outlined': 'Iconsax.sms',
    'Icons.description_rounded': 'Iconsax.document_text',
    'Icons.info_outline': 'Iconsax.info_circle',
    'Icons.logout_rounded': 'Iconsax.logout',
    'Icons.person_outline_rounded': 'Iconsax.user',
    'Icons.person_rounded': 'Iconsax.user',
    'Icons.more_horiz_rounded': 'Iconsax.more',
    'Icons.share_rounded': 'Iconsax.send_2',
    'Icons.heart_broken_rounded': 'Iconsax.heart_slash',
    'Icons.favorite_rounded': 'Iconsax.heart5',
    'Icons.favorite_border_rounded': 'Iconsax.heart',
    'Icons.lock_outline_rounded': 'Iconsax.lock',
    'Icons.mail_outline_rounded': 'Iconsax.sms',
    'Icons.search_rounded': 'Iconsax.search_normal',
    'Icons.add_rounded': 'Iconsax.add',
  };

  final files = dir.listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    bool changed = false;

    // Check if file uses any Icons. inside the map
    for (final entry in map.entries) {
      if (content.contains(entry.key)) {
        content = content.replaceAll(entry.key, entry.value);
        changed = true;
      }
    }

    if (changed) {
      // make sure iconsax is imported
      if (!content.contains('package:iconsax/iconsax.dart')) {
        content = "import 'package:iconsax/iconsax.dart';\n" + content;
      }
      file.writeAsStringSync(content);
      print('Updated \${file.path}');
    }
  }
}
