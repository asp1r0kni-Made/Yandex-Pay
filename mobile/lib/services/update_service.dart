import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

/// Проверка и установка обновлений напрямую из GitHub Releases,
/// минуя сторонние магазины приложений.
///
/// Как это работает:
/// 1. При запуске приложение запрашивает последний релиз репозитория
///    GitHub (latest release) через публичный REST API.
/// 2. Сравнивает тег релиза (например "v1.0.1") с текущей версией
///    приложения (из pubspec.yaml / package_info).
/// 3. Если доступна более новая версия — скачивает .apk из
///    assets релиза во временную папку.
/// 4. Открывает системный установщик пакета (требуется разрешение
///    "Установка неизвестных приложений" — пользователь даёт его
///    один раз в настройках Android).
///
/// ВАЖНО: замените [githubOwner] и [githubRepo] на свои значения.
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  UpdateInfo({required this.version, required this.downloadUrl, required this.releaseNotes});
}

class UpdateService {
  static const String githubOwner = "YOUR_GITHUB_USERNAME";
  static const String githubRepo = "splitbank";

  static Uri get _latestReleaseUrl => Uri.parse(
        "https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest",
      );

  /// Возвращает данные о новой версии, либо null если обновлений нет.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // например "1.0.0"

      final res = await http.get(
        _latestReleaseUrl,
        headers: {"Accept": "application/vnd.github+json"},
      );
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (json["tag_name"] as String? ?? "").replaceFirst("v", "");
      if (tag.isEmpty) return null;

      if (!_isNewer(tag, currentVersion)) return null;

      final assets = (json["assets"] as List<dynamic>? ?? []);
      final apkAsset = assets.firstWhere(
        (a) => (a["name"] as String).endsWith(".apk"),
        orElse: () => null,
      );
      if (apkAsset == null) return null;

      return UpdateInfo(
        version: tag,
        downloadUrl: apkAsset["browser_download_url"] as String,
        releaseNotes: json["body"] as String? ?? "",
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isNewer(String remote, String local) {
    List<int> parse(String v) =>
        v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final r = parse(remote);
    final l = parse(local);
    for (var i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv > lv;
    }
    return false;
  }

  /// Скачивает и запускает установку APK. [onProgress] от 0.0 до 1.0.
  static Future<void> downloadAndInstall(
    UpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    // На Android 8+ для установки apk из файла нужно разрешение
    // "REQUEST_INSTALL_PACKAGES" — запрашиваем доступ к хранилищу/установке.
    await Permission.requestInstallPackages.request();

    final dir = await getTemporaryDirectory();
    final filePath = "${dir.path}/splitbank_update.apk";
    final file = File(filePath);

    final request = http.Request("GET", Uri.parse(update.downloadUrl));
    final response = await http.Client().send(request);
    final total = response.contentLength ?? 0;
    var received = 0;

    final sink = file.openWrite();
    await response.stream.forEach((chunk) {
      received += chunk.length;
      sink.add(chunk);
      if (total > 0) onProgress?.call(received / total);
    });
    await sink.close();

    await OpenFilex.open(filePath);
  }
}
