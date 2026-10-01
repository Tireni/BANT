import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarService {
  final SupabaseClient supabase;
  final ImagePicker picker;

  AvatarService(this.supabase, {ImagePicker? picker})
      : picker = picker ?? ImagePicker();

  Future<String?> pickAndUpload() async {
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (file == null) return null;

    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Sign in first');

    final lower = file.name.toLowerCase();
    final ext = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.webp')
            ? 'webp'
            : 'jpg';
    final contentType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';

    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('Avatar must be 5 MB or smaller.');
    }

    final path = '${user.id}/avatar.$ext';
    await supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
            cacheControl: '3600',
          ),
        );

    final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
