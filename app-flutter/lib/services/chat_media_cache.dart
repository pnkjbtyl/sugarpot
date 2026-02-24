import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/config.dart';

/// Local cache for chat media. Mirrors server path:
/// Server: /uploads/chat-media/<filename>
/// Local:  <app-documents>/chat-media/<filename>
class ChatMediaCache {
  ChatMediaCache._();
  static final ChatMediaCache _instance = ChatMediaCache._();
  static ChatMediaCache get instance => _instance;

  static const String _chatMediaSegment = 'chat-media';
  Directory? _baseDir;

  Future<Directory> _getBaseDir() async {
    if (_baseDir != null && await _baseDir!.exists()) return _baseDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _baseDir = Directory(p.join(appDir.path, _chatMediaSegment));
    if (!await _baseDir!.exists()) await _baseDir!.create(recursive: true);
    return _baseDir!;
  }

  /// Server path or full URL -> filename only.
  static String _getFilename(String serverPathOrUrl) {
    String path = serverPathOrUrl.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      path = Uri.parse(path).path;
    }
    path = path.replaceFirst(RegExp(r'^/'), '');
    final idx = path.indexOf(_chatMediaSegment);
    if (idx != -1) {
      final after = path.substring(idx + _chatMediaSegment.length);
      return after.replaceFirst(RegExp(r'^/'), '');
    }
    return p.basename(path);
  }

  static String _networkUrl(String serverPathOrUrl) {
    if (serverPathOrUrl.startsWith('http://') || serverPathOrUrl.startsWith('https://')) {
      return serverPathOrUrl;
    }
    return AppConfig.buildImageUrl(serverPathOrUrl);
  }

  /// Returns cached file if exists.
  Future<File?> getCachedFile(String serverPathOrUrl) async {
    try {
      final filename = _getFilename(serverPathOrUrl);
      final base = await _getBaseDir();
      final file = File(p.join(base.path, filename));
      if (await file.exists()) return file;
    } catch (e) {
      debugPrint('ChatMediaCache getCachedFile: $e');
    }
    return null;
  }

  /// Download and save to cache (fire-and-forget).
  Future<void> downloadToCache(String serverPathOrUrl) async {
    try {
      if (await getCachedFile(serverPathOrUrl) != null) return;
      final url = _networkUrl(serverPathOrUrl);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;
      final base = await _getBaseDir();
      final file = File(p.join(base.path, _getFilename(serverPathOrUrl)));
      await file.writeAsBytes(response.bodyBytes);
    } catch (e) {
      debugPrint('ChatMediaCache downloadToCache: $e');
    }
  }

  /// Use cached file if present; otherwise return network URL and start background download.
  Future<String> getMediaUrl(String serverPathOrUrl) async {
    final file = await getCachedFile(serverPathOrUrl);
    if (file != null) return file.uri.toString();
    downloadToCache(serverPathOrUrl);
    return _networkUrl(serverPathOrUrl);
  }
}
