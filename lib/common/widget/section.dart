import 'package:flutter/material.dart';

class Section extends StatelessWidget {
  final String title;
  final Widget child;
  final bool _sliver;

  const Section({super.key, required this.title, required this.child})
    : _sliver = false;

  const Section.sliver({super.key, required this.title, required this.child})
    : _sliver = true;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );

    if (_sliver) {
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(child: header),
          child,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [header, child],
    );
  }
}
