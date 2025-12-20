import 'package:flutter/material.dart';

enum ContentType { video, document }

class ContentItem extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  final String? duration;
  final ContentType type;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ContentItem({
    required this.index,
    required this.title,
    required this.description,
    this.duration,
    required this.type,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFF6B35).withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        dense: true,
        isThreeLine: false,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            type == ContentType.video ? Icons.play_circle_outline : Icons.picture_as_pdf,
            color: const Color(0xFFFF6B35),
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: const Color(0xFF1C1D1F),
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                if (duration != null) ...[
                  Text(
                    duration!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                  Text('•', style: TextStyle(color: Colors.grey[400])),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: onDelete,
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                type == ContentType.video
                    ? (isSelected ? Icons.pause_circle_filled : Icons.play_circle_filled)
                    : Icons.download,
                color: const Color(0xFFFF6B35),
                size: 24,
              ),
              onPressed: onTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

