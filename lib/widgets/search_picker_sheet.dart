import 'package:flutter/material.dart';

Future<T?> showSearchPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) label,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SearchPickerSheet<T>(title: title, items: items, label: label),
  );
}

class _SearchPickerSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) label;

  const _SearchPickerSheet({
    required this.title,
    required this.items,
    required this.label,
  });

  @override
  State<_SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<_SearchPickerSheet<T>> {
  final _q = TextEditingController();
  late List<T> filtered;

  @override
  void initState() {
    super.initState();
    filtered = widget.items;
    _q.addListener(_apply);
  }

  void _apply() {
    final q = _q.text.trim().toLowerCase();
    setState(() {
      filtered = q.isEmpty
          ? widget.items
          : widget.items.where((x) => widget.label(x).toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _q.removeListener(_apply);
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _q,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Ara...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    return ListTile(
                      title: Text(widget.label(item)),
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}