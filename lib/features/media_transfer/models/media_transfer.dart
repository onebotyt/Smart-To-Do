enum MediaTransferStatus {
  pending,
  transferring,
  completed,
  failed,
  cancelled,
}

class MediaTransferItem {
  final String id;
  final String fileName;
  String filePath;
  final int fileSize;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String receiverName;
  final bool isOutgoing;
  int bytesTransferred;
  MediaTransferStatus status;
  final DateTime createdAt;
  String? errorMessage;

  MediaTransferItem({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.isOutgoing,
    this.bytesTransferred = 0,
    this.status = MediaTransferStatus.pending,
    DateTime? createdAt,
    this.errorMessage,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress =>
      fileSize > 0 ? (bytesTransferred / fileSize).clamp(0.0, 1.0) : 0.0;

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  MediaTransferItem copyWith({
    String? filePath,
    int? fileSize,
    int? bytesTransferred,
    MediaTransferStatus? status,
    String? errorMessage,
  }) {
    final item = MediaTransferItem(
      id: id,
      fileName: fileName,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      receiverName: receiverName,
      isOutgoing: isOutgoing,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      status: status ?? this.status,
      createdAt: createdAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
    return item;
  }
}
