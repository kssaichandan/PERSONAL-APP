import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Preset theme & accent colors used consistently across the app.
const List<Color> appDefaultColorPresets = [
  Colors.blue,
  Colors.indigo,
  Colors.teal,
  Colors.cyan,
  Colors.green,
  Colors.lightGreen,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.brown,
  Colors.blueGrey,
  Colors.lightBlue,
];

/// Pastel note presets.
const List<Color> appNoteColorPresets = [
  Color(0xFFFFCDD2), // Red 100
  Color(0xFFFFE0B2), // Orange 100
  Color(0xFFFFF9C4), // Yellow 100
  Color(0xFFC8E6C9), // Green 100
  Color(0xFFB2EBF2), // Cyan 100
  Color(0xFFBBDEFB), // Blue 100
  Color(0xFFE1BEE7), // Purple 100
  Color(0xFFF8BBD0), // Pink 100
  Color(0xFFB2DFDB), // Teal 100
  Color(0xFFD7CCC8), // Brown 100
];

/// Premium, unified Custom Color Picker Dialog featuring:
/// - Live `#HEX` color preview badge
/// - 2D HSV Saturation & Value touch box
/// - Multi-stop rainbow Hue slider
/// - Real-time `#HEX` TextField input
class AppCustomColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String title;

  const AppCustomColorPickerDialog({
    super.key,
    required this.initialColor,
    this.title = 'Custom Color',
  });

  @override
  State<AppCustomColorPickerDialog> createState() =>
      _AppCustomColorPickerDialogState();
}

class _AppCustomColorPickerDialogState
    extends State<AppCustomColorPickerDialog> {
  late HSVColor _hsv;
  final _hexController = TextEditingController();
  final GlobalKey _pickerBoxKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
    _hexController.text = widget.initialColor
        .toARGB32()
        .toRadixString(16)
        .substring(2)
        .toUpperCase();
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateFromHSV(HSVColor hsv) {
    setState(() {
      _hsv = hsv;
      final hex = hsv
          .toColor()
          .toARGB32()
          .toRadixString(16)
          .substring(2)
          .toUpperCase();
      _hexController.text = hex;
    });
  }

  void _updateFromHex(String hex) {
    if (hex.length == 6) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) {
        final color = Color(0xFF000000 | value);
        setState(() {
          _hsv = HSVColor.fromColor(color);
        });
      }
    }
  }

  void _handleTouch(Offset globalPosition, Size boxSize) {
    final RenderBox? box =
        _pickerBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localOffset = box.globalToLocal(globalPosition);
    final dx = (localOffset.dx / boxSize.width).clamp(0.0, 1.0);
    final dy = (localOffset.dy / boxSize.height).clamp(0.0, 1.0);
    _updateFromHSV(_hsv.withSaturation(dx).withValue(1.0 - dy));
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    final theme = Theme.of(context);
    final isLightColor = color.computeLuminance() > 0.5;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Live Color Preview Banner
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '#${_hexController.text}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 1.5,
                      fontSize: 15,
                      color: isLightColor ? Colors.black87 : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2D Saturation & Value Interactive Field
              LayoutBuilder(
                builder: (context, constraints) {
                  const boxHeight = 160.0;
                  final boxWidth = constraints.maxWidth;
                  final thumbX = (_hsv.saturation * (boxWidth - 24)).clamp(
                    0.0,
                    boxWidth - 24,
                  );
                  final thumbY = ((1.0 - _hsv.value) * (boxHeight - 24)).clamp(
                    0.0,
                    boxHeight - 24,
                  );

                  return GestureDetector(
                    onPanStart: (details) => _handleTouch(
                      details.globalPosition,
                      Size(boxWidth, boxHeight),
                    ),
                    onPanUpdate: (details) => _handleTouch(
                      details.globalPosition,
                      Size(boxWidth, boxHeight),
                    ),
                    onTapDown: (details) => _handleTouch(
                      details.globalPosition,
                      Size(boxWidth, boxHeight),
                    ),
                    child: Container(
                      key: _pickerBoxKey,
                      height: boxHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            // Base hue
                            Container(
                              color: HSVColor.fromAHSV(
                                1,
                                _hsv.hue,
                                1,
                                1,
                              ).toColor(),
                            ),
                            // Saturation (White to Transparent)
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white, Colors.transparent],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                            ),
                            // Value (Transparent to Black)
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Colors.black],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            // Thumb Indicator
                            Positioned(
                              left: thumbX,
                              top: thumbY,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Multi-stop Rainbow Hue Slider
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        colors: [
                          Colors.red,
                          Colors.yellow,
                          Colors.green,
                          Colors.cyan,
                          Colors.blue,
                          Colors.purple,
                          Colors.red,
                        ],
                      ),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 0,
                      thumbColor: color,
                      overlayColor: color.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _hsv.hue,
                      min: 0,
                      max: 360,
                      onChanged: (v) => _updateFromHSV(_hsv.withHue(v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // HEX Input Row
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9a-fA-F]'),
                        ),
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        hintText: 'HEX CODE',
                        prefixText: '# ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      onChanged: _updateFromHex,
                      onSubmitted: (_) => Navigator.pop(context, color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, color),
                    child: const Text('Select'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a bottom sheet palette with preset circles, optional reset option,
/// and a sweep-gradient rainbow custom color button.
Future<Color?> showAppColorPickerSheet({
  required BuildContext context,
  required Color? currentColor,
  String title = 'Color Palette',
  String? resetLabel,
  String? resetSubtitle,
  Color defaultResetColor = Colors.blue,
  VoidCallback? onReset,
  List<Color> presets = appDefaultColorPresets,
  bool allowNone = false,
}) {
  final theme = Theme.of(context);

  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 4),

              if (resetLabel != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: defaultResetColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    resetLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle:
                      resetSubtitle != null ? Text(resetSubtitle) : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (onReset != null) {
                      onReset();
                    }
                    Navigator.pop(sheetCtx, defaultResetColor);
                  },
                ),
                const SizedBox(height: 8),
              ],

              if (allowNone) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.format_color_reset,
                      color: theme.colorScheme.onSurface,
                      size: 18,
                    ),
                  ),
                  title: const Text(
                    'Default (No Color)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing:
                      currentColor == null
                          ? Icon(
                            Icons.check_rounded,
                            color: theme.colorScheme.primary,
                          )
                          : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(sheetCtx, const Color(0x00000000));
                  },
                ),
                const SizedBox(height: 8),
              ],

              Text(
                'PRESET COLORS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: presets.length + 1,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                      ),
                  itemBuilder: (gridCtx, index) {
                    if (index == presets.length) {
                      // Custom Rainbow Gradient Trigger
                      return GestureDetector(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          final chosen = await showDialog<Color>(
                            context: sheetCtx,
                            builder:
                                (dialogCtx) => AppCustomColorPickerDialog(
                                  initialColor:
                                      currentColor ??
                                      theme.colorScheme.primary,
                                  title: 'Custom $title',
                                ),
                          );
                          if (chosen != null && sheetCtx.mounted) {
                            Navigator.pop(sheetCtx, chosen);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const SweepGradient(
                              colors: [
                                Colors.red,
                                Colors.yellow,
                                Colors.green,
                                Colors.cyan,
                                Colors.blue,
                                Colors.purple,
                                Colors.red,
                              ],
                            ),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.palette_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    }

                    final color = presets[index];
                    final isSelected =
                        currentColor != null &&
                        currentColor.toARGB32() == color.toARGB32();

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(sheetCtx, color);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected
                                    ? (color.computeLuminance() > 0.6
                                        ? Colors.black87
                                        : Colors.white)
                                    : theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.4),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child:
                            isSelected
                                ? Center(
                                  child: Icon(
                                    Icons.check_rounded,
                                    color:
                                        color.computeLuminance() > 0.6
                                            ? Colors.black87
                                            : Colors.white,
                                    size: 20,
                                  ),
                                )
                                : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
