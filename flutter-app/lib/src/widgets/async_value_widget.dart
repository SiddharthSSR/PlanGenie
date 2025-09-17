import 'package:flutter/material.dart';

/// Renders one of three builders depending on an asynchronous value.
class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    required this.value,
    required this.loadingBuilder,
    required this.errorBuilder,
    required this.dataBuilder,
    super.key,
  });

  final AsyncSnapshot<T> value;
  final WidgetBuilder loadingBuilder;
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) errorBuilder;
  final Widget Function(BuildContext context, T data) dataBuilder;

  @override
  Widget build(BuildContext context) {
    if (value.connectionState == ConnectionState.waiting) {
      return loadingBuilder(context);
    }

    if (value.hasError) {
      return errorBuilder(context, value.error!, value.stackTrace);
    }

    if (value.hasData) {
      return dataBuilder(context, value.data as T);
    }

    return const SizedBox.shrink();
  }
}
