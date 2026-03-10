import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class LoadMessagesEvent extends ChatEvent {
  final String currentUserId;
  final String otherUserId;

  const LoadMessagesEvent(this.currentUserId, this.otherUserId);

  @override
  List<Object?> get props => [currentUserId, otherUserId];
}

class SendMessageEvent extends ChatEvent {
  final String currentUserId;
  final String otherUserId;
  final String content;

  const SendMessageEvent({
    required this.currentUserId,
    required this.otherUserId,
    required this.content,
  });

  @override
  List<Object?> get props => [currentUserId, otherUserId, content];
}

class DeleteMessageEvent extends ChatEvent {
  final String messageId;
  final String currentUserId;
  final String otherUserId;

  const DeleteMessageEvent({
    required this.messageId,
    required this.currentUserId,
    required this.otherUserId,
  });

  @override
  List<Object?> get props => [messageId, currentUserId, otherUserId];
}
