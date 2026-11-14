import 'dart:math' as math;

import 'package:counseling_is/core/widgets/app_field.dart';
import 'package:flutter/material.dart';

abstract final class AppDropdownDefaults {
  static const menuWidth = 360.0;
  static const menuMaxHeight = 320.0;
}

class AppDropdownFormField<T> extends StatefulWidget {
  const AppDropdownFormField({
    super.key,
    required this.items,
    required this.onChanged,
    this.initialValue,
    this.decoration = const InputDecoration(),
    this.validator,
    this.onSaved,
    this.hint,
    this.isExpanded = false,
    this.menuMaxHeight = AppDropdownDefaults.menuMaxHeight,
    this.labelHeight,
  });

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? initialValue;
  final InputDecoration decoration;
  final FormFieldValidator<T>? validator;
  final FormFieldSetter<T>? onSaved;
  final Widget? hint;
  final bool isExpanded;
  final double menuMaxHeight;
  final double? labelHeight;

  @override
  State<AppDropdownFormField<T>> createState() =>
      _AppDropdownFormFieldState<T>();
}

class _AppDropdownFormFieldState<T> extends State<AppDropdownFormField<T>> {
  final _layerLink = LayerLink();
  final _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      key: ValueKey<T?>(widget.initialValue),
      initialValue: widget.initialValue,
      validator: widget.validator,
      onSaved: widget.onSaved,
      builder: (field) {
        final label = widget.decoration.labelText;
        final hint =
            widget.hint ??
            Text(
              label == null
                  ? 'Select an option'
                  : 'Select ${label.replaceAll('*', '').trim().toLowerCase()}',
            );
        final fieldContent = CompositedTransformTarget(
          key: _anchorKey,
          link: _layerLink,
          child: InputDecorator(
            decoration: widget.decoration.copyWith(
              labelText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              constraints: const BoxConstraints(minHeight: 50),
              errorText: field.errorText,
            ),
            isEmpty: false,
            child: AppDropdownButton<T>(
              layerLink: _layerLink,
              anchorKey: _anchorKey,
              value: field.value,
              items: widget.items,
              hint: hint,
              isExpanded: widget.isExpanded,
              menuMaxHeight: widget.menuMaxHeight,
              onChanged: widget.onChanged == null
                  ? null
                  : (value) {
                      field.didChange(value);
                      widget.onChanged!(value);
                    },
            ),
          ),
        );
        return label == null
            ? fieldContent
            : AppField(
                label: label,
                labelHeight: widget.labelHeight,
                child: fieldContent,
              );
      },
    );
  }
}

class AppDropdownButton<T> extends StatefulWidget {
  const AppDropdownButton({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.layerLink,
    this.anchorKey,
    this.isExpanded = false,
    this.menuMaxHeight = AppDropdownDefaults.menuMaxHeight,
  });

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final Widget? hint;
  final LayerLink? layerLink;
  final GlobalKey? anchorKey;
  final bool isExpanded;
  final double menuMaxHeight;

  @override
  State<AppDropdownButton<T>> createState() => _AppDropdownButtonState<T>();
}

class _AppDropdownButtonState<T> extends State<AppDropdownButton<T>> {
  final _ownLayerLink = LayerLink();
  final _ownAnchorKey = GlobalKey();
  OverlayEntry? _menuEntry;
  Size _buttonSize = Size.zero;
  double _availableMenuHeight = 0;

  bool get _isOpen => _menuEntry != null;
  LayerLink get _layerLink => widget.layerLink ?? _ownLayerLink;

  @override
  void dispose() {
    _removeMenu();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    if (widget.onChanged == null || widget.items.isEmpty) return;
    final anchorContext =
        widget.anchorKey?.currentContext ??
        _ownAnchorKey.currentContext ??
        context;
    final renderObject = anchorContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final origin = renderObject.localToGlobal(Offset.zero);
    _buttonSize = renderObject.size;
    _availableMenuHeight = math.max(
      0,
      MediaQuery.sizeOf(context).height - origin.dy - _buttonSize.height - 8,
    );

    _menuEntry = OverlayEntry(builder: _buildMenuOverlay);
    Overlay.of(context, rootOverlay: true).insert(_menuEntry!);
    setState(() {});
  }

  Widget _buildMenuOverlay(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closeMenu,
            child: const SizedBox.expand(),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4),
            child: Material(
              color: scheme.surface,
              elevation: 8,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: SizedBox(
                width: _buttonSize.width,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.min(
                      widget.menuMaxHeight,
                      _availableMenuHeight,
                    ),
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final item in widget.items)
                        _buildMenuItem(item, scheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(DropdownMenuItem<T> item, ColorScheme scheme) {
    final selected = item.value == widget.value;
    final enabled = item.enabled && widget.onChanged != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: InkWell(
        onTap: enabled
            ? () {
                _closeMenu();
                item.onTap?.call();
                widget.onChanged?.call(item.value);
              }
            : null,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: selected ? scheme.secondaryContainer : null,
          child: DefaultTextStyle(
            style: TextStyle(
              color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
            child: item.child,
          ),
        ),
      ),
    );
  }

  void _closeMenu() {
    _removeMenu();
    if (mounted) setState(() {});
  }

  void _removeMenu() {
    _menuEntry?.remove();
    _menuEntry?.dispose();
    _menuEntry = null;
  }

  Widget _selectedChild() {
    for (final item in widget.items) {
      if (item.value == widget.value) return item.child;
    }
    return widget.hint ?? const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = Semantics(
      button: true,
      expanded: _isOpen,
      child: InkWell(
        onTap: widget.onChanged == null ? null : _toggleMenu,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: kMinInteractiveDimension,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: widget.isExpanded
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                if (widget.isExpanded)
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _selectedChild(),
                    ),
                  )
                else
                  _selectedChild(),
                Icon(
                  _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return widget.layerLink == null
        ? CompositedTransformTarget(
            key: _ownAnchorKey,
            link: _layerLink,
            child: button,
          )
        : button;
  }
}
