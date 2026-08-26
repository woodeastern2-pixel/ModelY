import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class OutlookMail {
  final String id;
  final String sender;
  final String subject;
  final String bodyPreview;
  final DateTime? receivedAt;
  final List<OutlookAttachment> attachments;

  const OutlookMail({
    required this.id,
    required this.sender,
    required this.subject,
    required this.bodyPreview,
    required this.receivedAt,
    required this.attachments,
  });
}

class OutlookAttachment {
  final String id;
  final String name;
  final String contentType;
  final int size;
  final String? contentBytes;

  const OutlookAttachment({
    required this.id,
    required this.name,
    required this.contentType,
    required this.size,
    this.contentBytes,
  });
}

class OutlookService {
  static const _graphBase = 'https://graph.microsoft.com/v1.0';

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

  Future<List<OutlookMail>> collectMails({
    required String accessToken,
    String folder = 'Inbox',
    int top = 20,
  }) async {
    final encodedFolder = Uri.encodeComponent(folder);
    final url = Uri.parse(
      '$_graphBase/me/mailFolders/$encodedFolder/messages'
      '?\$top=$top&\$orderby=receivedDateTime desc&\$select=id,subject,bodyPreview,receivedDateTime,from',
    );

    final res = await http.get(url, headers: _headers(accessToken));
    if (res.statusCode != 200) {
      throw Exception('Outlook 메일 수집 실패: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final values = List<Map<String, dynamic>>.from(data['value'] ?? []);

    final mails = <OutlookMail>[];
    for (final m in values) {
      final msgId = m['id'] as String;
      final attachments = await collectAttachments(
        accessToken: accessToken,
        messageId: msgId,
      );

      mails.add(
        OutlookMail(
          id: msgId,
          sender: ((m['from'] as Map?)?['emailAddress'] as Map?)?['address'] as String? ?? '',
          subject: m['subject'] as String? ?? '(제목 없음)',
          bodyPreview: m['bodyPreview'] as String? ?? '',
          receivedAt: (m['receivedDateTime'] as String?) == null
              ? null
              : DateTime.tryParse(m['receivedDateTime'] as String),
          attachments: attachments,
        ),
      );
    }

    return mails;
  }

  Future<List<OutlookAttachment>> collectAttachments({
    required String accessToken,
    required String messageId,
  }) async {
    final url = Uri.parse(
      '$_graphBase/me/messages/$messageId/attachments'
      '?\$select=id,name,contentType,size,contentBytes',
    );

    final res = await http.get(url, headers: _headers(accessToken));
    if (res.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final values = List<Map<String, dynamic>>.from(data['value'] ?? []);

    return values
        .map(
          (a) => OutlookAttachment(
            id: a['id'] as String? ?? '',
            name: a['name'] as String? ?? 'attachment',
            contentType: a['contentType'] as String? ?? 'application/octet-stream',
            size: (a['size'] as num?)?.toInt() ?? 0,
            contentBytes: a['contentBytes'] as String?,
          ),
        )
        .toList();
  }

  Future<String?> saveAttachment(OutlookAttachment att) async {
    if (att.contentBytes == null || att.contentBytes!.isEmpty) return null;

    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'mail_attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final safeName = att.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File(p.join(dir.path, safeName));
    await file.writeAsBytes(base64Decode(att.contentBytes!));
    return file.path;
  }
}
