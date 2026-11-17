import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:scroll_to_index_plus/scroll_to_index_plus.dart';

/// One label per form field. `photo` is a spacer card without an input, so
/// the labels in use (0, 1, 3, 4, 5, 6) are not contiguous.
enum DemoField { name, email, photo, phone, company, bio, website }

/// "Scrolling to an invalid form field".
///
/// Every field is a [PositionedListItem] nested inside a [Card]. After a
/// failed save the first invalid field is scrolled into view only if it is
/// not already visible.
class FormDemo extends StatefulWidget {
  const FormDemo({super.key});

  @override
  State<FormDemo> createState() => _FormDemoState();
}

class _FormDemoState extends State<FormDemo>
    with AutomaticKeepAliveClientMixin {
  final _controller = ScrollablePositionedController(
    highlightDuration: const Duration(seconds: 2),
  );
  final _formKey = GlobalKey<FormState>();
  final _keys = {
    for (final f in DemoField.values) f: GlobalKey<FormFieldState<String>>(),
  };

  static const _required = [
    DemoField.name,
    DemoField.email,
    DemoField.phone,
    DemoField.company,
    DemoField.bio,
    DemoField.website,
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      return;
    }
    // First invalid field, in enum order.
    final first = _required.firstWhere(
      (f) => _keys[f]!.currentState?.hasError ?? false,
    );
    _controller.ensureIndexVisible(
      first.index,
      alignment: 0.1,
      highlight: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.save),
        label: const Text('Save'),
      ),
      body: Form(
        key: _formKey,
        child: ScrollablePositionedList(
          controller: _controller,
          enableHighlight: true,
          child: ListView(
            controller: _controller.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            // Every field stays built, so isIndexVisible/ensureIndexVisible
            // can measure it.
            scrollCacheExtent: const ScrollCacheExtent.pixels(5000),
            children: [
              for (final field in DemoField.values) ...[
                PositionedListItem(
                  index: field.index,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: field == DemoField.photo
                          ? const SizedBox(
                              height: 220,
                              child: Center(child: Text('Photo (optional)')),
                            )
                          : TextFormField(
                              key: _keys[field],
                              maxLines: field == DemoField.bio ? 6 : 1,
                              decoration: InputDecoration(
                                labelText: field.name,
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? '${field.name} is required'
                                      : null,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 280), // spacer between cards
              ],
            ],
          ),
        ),
      ),
    );
  }
}
