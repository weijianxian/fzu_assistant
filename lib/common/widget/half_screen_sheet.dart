import 'package:flutter/material.dart';

Future<T?> showHalfScreenSheet<T>(
  BuildContext context, {
  required Widget Function(ScrollController controller) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(child: builder(controller)),
        ],
      ),
    ),
  );
}
