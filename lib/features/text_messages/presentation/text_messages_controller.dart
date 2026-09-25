import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/features/text_messages/domain/text_message.dart';

/// Presentation-facing boundary: no widget imports, Drift queries, or network.
/// A future sync-capable repository can implement MessageRepository without
/// changing the reader or composer.
class TextMessagesController {
  final MessageRepository repository;
  final String sessionId;
  final String senderId;
  final String senderName;
  final Uuid _uuid;

  TextMessagesController({
    required this.repository,
    required this.sessionId,
    required this.senderId,
    required this.senderName,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  Stream<List<TextMessage>> watchPage(int pageNumber) =>
      repository.watchPageText(sessionId, pageNumber);

  Future<TextMessage> send(int pageNumber, String text) => repository.createText(
        id: 'msg_${_uuid.v4()}',
        sessionId: sessionId,
        pageNumber: pageNumber,
        senderId: senderId,
        senderName: senderName,
        text: text,
      );

  Future<bool> edit(TextMessage message, String text) {
    _ensureOwner(message);
    return repository.updateOwnText(
      id: message.id, sessionId: sessionId, pageNumber: message.pageNumber,
      senderId: senderId, text: text,
    );
  }

  Future<bool> delete(TextMessage message) {
    _ensureOwner(message);
    return repository.deleteOwnText(
      id: message.id, sessionId: sessionId, pageNumber: message.pageNumber,
      senderId: senderId,
    );
  }

  void _ensureOwner(TextMessage message) {
    if (message.sessionId != sessionId || message.senderId != senderId) {
      throw StateError('Only the local sender can change this message');
    }
  }
}
