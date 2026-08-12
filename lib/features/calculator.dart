import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../database.dart';
import '../utils/snackbar_utils.dart';
import 'settings_provider.dart';

class CalculatorProvider extends ChangeNotifier {
  String _expression = '';
  String _result = '';
  List<Map<String, String>> _history = [];
  String? _error;
  double _memory = 0.0;
  bool _loading = false;

  String get expression => _expression;
  String get result => _result;
  List<Map<String, String>> get history => _history;
  String? get error => _error;
  double get memory => _memory;
  bool get loading => _loading;

  String get formattedMemory {
    if (_memory == 0.0) return '0';
    return formatDisplayNumber(
      _memory == _memory.toInt()
          ? _memory.toInt().toString()
          : _memory.toString(),
    );
  }

  static String formatDisplayNumber(String input) {
    if (input.isEmpty || input == 'Error' || input == 'Cannot divide by zero') {
      return input;
    }
    return input.replaceAllMapped(RegExp(r'(\d+)(\.\d+)?'), (match) {
      final intPart = match.group(1)!;
      final decPart = match.group(2) ?? '';
      final formattedInt = intPart.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
      return '$formattedInt$decPart';
    });
  }

  CalculatorProvider() {
    Future.microtask(() => loadHistory());
  }

  Future<void> loadHistory() async {
    _loading = true;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.database;
      final maps = await db.query(
        'calculator_history',
        orderBy: 'created_at DESC',
        limit: 50,
      );
      _history =
          maps
              .map(
                (m) => {
                  'id': m['id']?.toString() ?? '',
                  'expression': m['expression'] as String,
                  'result': m['result'] as String,
                },
              )
              .toList();
    } catch (e) {
      _error = 'Failed to load history';
    }
    _loading = false;
    notifyListeners();
  }

  void loadExpression(String expr) {
    _expression = expr;
    _result = '';
    notifyListeners();
  }

  void memoryAdd() {
    HapticFeedback.lightImpact();
    final cleanResult = _result.replaceAll(',', '');
    final parsed = double.tryParse(cleanResult);
    if (parsed != null) _memory += parsed;
    notifyListeners();
  }

  void memorySubtract() {
    HapticFeedback.lightImpact();
    final cleanResult = _result.replaceAll(',', '');
    final parsed = double.tryParse(cleanResult);
    if (parsed != null) _memory -= parsed;
    notifyListeners();
  }

  void memoryRecall() {
    HapticFeedback.selectionClick();
    final memStr =
        _memory == _memory.toInt()
            ? _memory.toInt().toString()
            : _memory.toString();
    if (_expression.isEmpty ||
        _expression == '0' ||
        RegExp(r'[+\-×÷^(\s]$').hasMatch(_expression)) {
      if (_memory < 0) {
        _expression += '($memStr)';
      } else {
        _expression += memStr;
      }
    } else {
      if (_memory < 0) {
        _expression += '×($memStr)';
      } else {
        _expression += '×$memStr';
      }
    }
    _result = '';
    notifyListeners();
  }

  void memoryClear() {
    HapticFeedback.mediumImpact();
    _memory = 0.0;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('calculator_history');
    } catch (e) {
      debugLog('Failed to clear history: $e');
    }
    await loadHistory();
  }

  Future<void> deleteHistoryAt(int index) async {
    if (index < 0 || index >= _history.length) return;
    final item = _history[index];
    _history.removeAt(index);
    notifyListeners();
    try {
      final db = await AppDatabase.instance.database;
      await db.delete(
        'calculator_history',
        where: 'expression = ? AND result = ?',
        whereArgs: [item['expression'], item['result']],
      );
    } catch (e) {
      debugLog('Failed to delete history item: $e');
    }
  }

  void input(String value) {
    if (value == '=') {
      HapticFeedback.mediumImpact();
    } else if (value == 'C' || value == 'CE' || value == '⌫') {
      HapticFeedback.mediumImpact();
    } else if (RegExp(r'^[0-9]$').hasMatch(value)) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.lightImpact();
    }

    if (_result == 'Error' || _result == 'Cannot divide by zero') {
      _expression = '';
      _result = '';
    }
    if (value == 'C' || value == 'CE') {
      _expression = '';
      _result = '';
    } else if (value == '⌫') {
      if (_expression.isNotEmpty) {
        _expression = _expression.substring(0, _expression.length - 1);
      }
    } else if (value == '=') {
      _evaluate();
      return;
    } else if (value == '±') {
      if (_expression.isEmpty || _expression == '0') {
        _expression = '-';
      } else if (_expression.startsWith('-')) {
        _expression = _expression.substring(1);
      } else {
        _expression = '-$_expression';
      }
    } else {
      if (_expression.length >= 50) {
        return;
      }
      _expression += value;
    }
    notifyListeners();
  }

  void _evaluate() {
    try {
      final parsed = _parse(_expression);
      if (parsed is double && parsed.isInfinite) {
        _result = 'Cannot divide by zero';
        notifyListeners();
        return;
      }
      _result = _formatResult(parsed);
      _saveToHistory(_expression, _result);
      _expression = _result;
    } catch (e) {
      _result = 'Error';
    }
    notifyListeners();
  }

  String _formatResult(num value) {
    if (value is double && (value.isNaN || value.isInfinite)) return 'Error';
    if (value == value.toInt()) return value.toInt().toString();
    final s = value
        .toStringAsFixed(10)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    return s.length > 15 ? value.toStringAsExponential(6) : s;
  }

  Future<void> _saveToHistory(String expr, String res) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.insert('calculator_history', {
        'expression': expr,
        'result': res,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugLog('Failed to save history: $e');
    }
    await loadHistory();
  }

  void square() {
    HapticFeedback.lightImpact();
    if (_result == 'Error' || _result == 'Cannot divide by zero') {
      _expression = '';
      _result = '';
      notifyListeners();
      return;
    }
    if (_expression.isNotEmpty) {
      _expression = '($_expression)^2';
      notifyListeners();
    }
  }

  int _pos = 0;
  String _input = '';

  String _preprocess(String input) {
    var s = input.replaceAll(' ', '').replaceAll(',', '');
    final percentRegex = RegExp(r'(-?\d+\.?\d*)%');
    while (percentRegex.hasMatch(s)) {
      s = s.replaceAllMapped(percentRegex, (m) {
        final numStr = m.group(1)!;
        final numVal = double.parse(numStr);
        return (numVal / 100).toString();
      });
    }
    return s;
  }

  num _parse(String input) {
    _pos = 0;
    _input = _preprocess(input);
    final result = _expr();
    if (_pos < _input.length) {
      throw FormatException('Unexpected: ${_input[_pos]}');
    }
    return result;
  }

  num _expr() {
    num result = _term();
    while (_pos < _input.length &&
        (_input[_pos] == '+' || _input[_pos] == '-')) {
      final op = _input[_pos++];
      final right = _term();
      result = op == '+' ? result + right : result - right;
    }
    return result;
  }

  num _term() {
    num result = _factor();
    while (_pos < _input.length &&
        (_input[_pos] == '×' || _input[_pos] == '÷')) {
      final op = _input[_pos++];
      final right = _factor();
      if (op == '÷' && right == 0) {
        return double.infinity;
      }
      result = op == '×' ? result * right : result / right;
    }
    return result;
  }

  num _factor() {
    num result = _unary();
    if (_pos < _input.length && _input[_pos] == '^') {
      _pos++;
      result = pow(result, _factor()).toDouble();
    }
    return result;
  }

  num _unary() {
    if (_pos >= _input.length) throw const FormatException('Unexpected end');
    if (_input[_pos] == '-') {
      _pos++;
      return -_unary();
    }
    if (_input[_pos] == '+') {
      _pos++;
      return _unary();
    }
    return _primary();
  }

  num _primary() {
    if (_pos >= _input.length) throw const FormatException('Unexpected end');

    if (_input[_pos] == '(') {
      _pos++;
      final result = _expr();
      if (_pos >= _input.length || _input[_pos] != ')') {
        throw const FormatException('Missing )');
      }
      _pos++;
      return result;
    }

    if (_input.substring(_pos).startsWith('sin')) {
      _pos += 3;
      return sin(_primary().toDouble());
    }
    if (_input.substring(_pos).startsWith('cos')) {
      _pos += 3;
      return cos(_primary().toDouble());
    }
    if (_input.substring(_pos).startsWith('tan')) {
      _pos += 3;
      return tan(_primary().toDouble());
    }
    if (_input.substring(_pos).startsWith('log')) {
      _pos += 3;
      return log(_primary().toDouble()) / ln10;
    }
    if (_input.substring(_pos).startsWith('ln')) {
      _pos += 2;
      return log(_primary().toDouble());
    }
    if (_input.substring(_pos).startsWith('sqrt')) {
      _pos += 4;
      return sqrt(_primary().toDouble());
    }
    if (_input.substring(_pos).startsWith('√')) {
      _pos += 1;
      return sqrt(_primary().toDouble());
    }

    if (_input.substring(_pos).startsWith('π')) {
      _pos++;
      return pi;
    }
    if (_input.substring(_pos).startsWith('e') &&
        (_pos + 1 >= _input.length ||
            !RegExp(r'[a-zA-Z0-9]').hasMatch(_input[_pos + 1]))) {
      _pos++;
      return e;
    }

    final start = _pos;
    while (_pos < _input.length && (RegExp(r'[0-9.]').hasMatch(_input[_pos]))) {
      _pos++;
    }
    if (_pos == start) throw FormatException('Unexpected: ${_input[_pos]}');
    var result = double.parse(_input.substring(start, _pos));
    return result;
  }
}

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calculator',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        bottom: false,
        child: Consumer2<CalculatorProvider, SettingsProvider>(
          builder: (context, calc, settings, _) {
            if (isLandscape) {
              return Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _DisplayArea(
                      calc: calc,
                      settings: settings,
                      theme: theme,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (settings.scientificMode)
                            _MemoryRow(
                              calc: calc,
                              scientific: settings.scientificMode,
                              theme: theme,
                            ),
                          _ScientificToggle(calc: calc, settings: settings),
                          _ButtonGrid(
                            calc: calc,
                            scientific: settings.scientificMode,
                            theme: theme,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                Expanded(
                  child: _DisplayArea(
                    calc: calc,
                    settings: settings,
                    theme: theme,
                  ),
                ),
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (settings.scientificMode)
                        _MemoryRow(
                          calc: calc,
                          scientific: settings.scientificMode,
                          theme: theme,
                        ),
                      _ScientificToggle(calc: calc, settings: settings),
                      _ButtonGrid(
                        calc: calc,
                        scientific: settings.scientificMode,
                        theme: theme,
                      ),
                      SizedBox(height: settings.scientificMode ? 4 : 8),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DisplayArea extends StatelessWidget {
  final CalculatorProvider calc;
  final SettingsProvider settings;
  final ThemeData theme;
  const _DisplayArea({
    required this.calc,
    required this.settings,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isSci = settings.scientificMode;
    final hasError =
        calc.result == 'Error' || calc.result == 'Cannot divide by zero';
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final formattedExpr = CalculatorProvider.formatDisplayNumber(
      calc.expression.isEmpty ? '0' : calc.expression,
    );
    final formattedRes = CalculatorProvider.formatDisplayNumber(calc.result);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: EdgeInsets.fromLTRB(
        isLandscape ? 12 : 20,
        isSci ? 6 : 12,
        isLandscape ? 12 : 20,
        isSci ? 6 : 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      alignment: Alignment.bottomRight,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: isLandscape ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Row(
              children: [
                if (calc.memory != 0.0)
                  Tooltip(
                    message: 'Memory: ${calc.formattedMemory}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.15,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'M',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            calc.formattedMemory,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                if (isSci)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.8,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.science_outlined,
                          size: 12,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'SCI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: isSci ? 4 : 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Text(
                formattedExpr,
                style: (isSci
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      color:
                          calc.expression.isEmpty
                              ? theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              )
                              : theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                maxLines: 1,
              ),
            ),
            SizedBox(height: isSci ? 2 : 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                  ),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: GestureDetector(
                      onTap:
                          settings.copyOnTap &&
                                  calc.result.isNotEmpty &&
                                  !hasError
                              ? () {
                                HapticFeedback.mediumImpact();
                                Clipboard.setData(
                                  ClipboardData(text: calc.result),
                                );
                                showSuccessSnackBar(
                                  context,
                                  'Result copied to clipboard',
                                );
                              }
                              : null,
                      child: Text(
                        formattedRes.isEmpty ? '' : formattedRes,
                        style: (isSci
                                ? theme.textTheme.headlineMedium
                                : theme.textTheme.headlineLarge)
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color:
                                  hasError
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.onSurface,
                            ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSci ? 4 : 8),
          ],
        ),
      ),
    );
  }
}

class _MemoryRow extends StatelessWidget {
  final CalculatorProvider calc;
  final bool scientific;
  final ThemeData theme;
  const _MemoryRow({
    required this.calc,
    required this.scientific,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final memButtons = ['MC', 'MR', 'M+', 'M-'];
    final hasMemory = calc.memory != 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        children:
            memButtons.map((label) {
              final disabled = (label == 'MC' || label == 'MR') && !hasMemory;
              final isRecallOrClear = label == 'MC' || label == 'MR';
              final highlight = isRecallOrClear && hasMemory;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.all(scientific ? 1.5 : 2),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: scientific ? 6 : 8,
                      ),
                      foregroundColor:
                          disabled
                              ? theme.colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              )
                              : highlight
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                      backgroundColor:
                          highlight
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: disabled ? 0.25 : 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side:
                            highlight
                                ? BorderSide(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  width: 1,
                                )
                                : BorderSide.none,
                      ),
                      minimumSize: const Size(40, 38),
                    ),
                    onPressed:
                        disabled
                            ? null
                            : () {
                              switch (label) {
                                case 'MC':
                                  calc.memoryClear();
                                case 'MR':
                                  calc.memoryRecall();
                                case 'M+':
                                  calc.memoryAdd();
                                case 'M-':
                                  calc.memorySubtract();
                              }
                            },
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            highlight ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _ScientificToggle extends StatelessWidget {
  final CalculatorProvider calc;
  final SettingsProvider settings;
  const _ScientificToggle({required this.calc, required this.settings});

  @override
  Widget build(BuildContext context) {
    final isSci = settings.scientificMode;
    final theme = Theme.of(context);
    final historyCount = calc.history.length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isSci ? 2 : 4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () {
                  HapticFeedback.selectionClick();
                  settings.setScientificMode(!settings.scientificMode);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSci
                            ? theme.colorScheme.surface
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow:
                        isSci
                            ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                            : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSci
                            ? Icons.science_rounded
                            : Icons.science_outlined,
                        size: 15,
                        color:
                            isSci
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isSci ? 'Scientific ON' : 'Scientific OFF',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSci ? FontWeight.w600 : FontWeight.w500,
                          color:
                              isSci
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showHistoryBottomSheet(context, calc);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'History',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (historyCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$historyCount',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

void _showHistoryBottomSheet(BuildContext context, CalculatorProvider calc) {
  final theme = Theme.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Consumer<CalculatorProvider>(
        builder: (context, provider, _) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Calculation History',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (provider.history.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(
                          Icons.delete_sweep_outlined,
                          size: 16,
                        ),
                        label: const Text(
                          'Clear All',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed:
                            () => _confirmClearHistory(context, provider),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (provider.history.isEmpty)
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.calculate_outlined,
                              size: 40,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No calculations yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your completed equations will appear here',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: provider.history.length,
                      separatorBuilder:
                          (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final h = provider.history[index];
                        final rawExpr = h['expression'] ?? '';
                        final rawRes = h['result'] ?? '';
                        final formattedExpr =
                            CalculatorProvider.formatDisplayNumber(rawExpr);
                        final formattedRes =
                            CalculatorProvider.formatDisplayNumber(rawRes);

                        return Dismissible(
                          key: ValueKey('hist_${index}_$rawExpr'),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) {
                            HapticFeedback.mediumImpact();
                            provider.deleteHistoryAt(index);
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.functions_rounded,
                                  size: 18,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              title: Text(
                                formattedExpr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '= $formattedRes',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: theme.colorScheme.outline,
                              ),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                provider.loadExpression(rawExpr);
                                Navigator.pop(context);
                              },
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                Clipboard.setData(
                                  ClipboardData(text: rawRes),
                                );
                                showSuccessSnackBar(
                                  context,
                                  'Result copied to clipboard',
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

void _confirmClearHistory(BuildContext context, CalculatorProvider provider) {
  showDialog(
    context: context,
    builder:
        (ctx) => AlertDialog(
          icon: Icon(
            Icons.delete_sweep_rounded,
            color: Theme.of(ctx).colorScheme.error,
          ),
          title: const Text('Clear History'),
          content: const Text(
            'Are you sure you want to clear all calculation history? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                provider.clearHistory();
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              child: const Text('Clear All'),
            ),
          ],
        ),
  );
}

class _ButtonGrid extends StatelessWidget {
  final CalculatorProvider calc;
  final bool scientific;
  final ThemeData theme;
  const _ButtonGrid({
    required this.calc,
    required this.scientific,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final sciRows = [
      ['sin', 'cos', 'tan', '√'],
      ['log', 'ln', '(', ')'],
      ['π', 'e', 'x²', '^'],
    ];
    const basicRows = [
      ['C', 'CE', '⌫', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '-'],
      ['1', '2', '3', '+'],
      ['±', '0', '.', '='],
    ];

    final allRows = scientific ? [...sciRows, ...basicRows] : basicRows;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children:
            allRows
                .map(
                  (row) => Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: isLandscape ? 1 : (scientific ? 1.5 : 3),
                    ),
                    child: Row(
                      children:
                          row.map((label) {
                            final isNumber = RegExp(r'^[0-9]$').hasMatch(label);
                            final isOp = [
                              '+',
                              '-',
                              '×',
                              '÷',
                              '=',
                              '^',
                            ].contains(label);
                            final isClear =
                                label == 'C' ||
                                label == 'CE' ||
                                label == '⌫';
                            final isEquals = label == '=';
                            final isFn = [
                              'sin',
                              'cos',
                              'tan',
                              'log',
                              'ln',
                              '√',
                              'π',
                              'e',
                              'x²',
                              '%',
                              '(',
                              ')',
                              '±',
                            ].contains(label);
                            final isZero = label == '0';

                            Color? bg;
                            Color? fg;
                            if (isNumber) {
                              bg = theme.colorScheme.surfaceContainerHighest;
                              fg = theme.colorScheme.onSurface;
                            } else if (isEquals) {
                              bg = theme.colorScheme.primary;
                              fg = theme.colorScheme.onPrimary;
                            } else if (isOp) {
                              bg = theme.colorScheme.primaryContainer;
                              fg = theme.colorScheme.onPrimaryContainer;
                            } else if (label == 'C') {
                              bg = theme.colorScheme.errorContainer;
                              fg = theme.colorScheme.onErrorContainer;
                            } else if (isClear || isFn) {
                              bg = theme.colorScheme.secondaryContainer;
                              fg = theme.colorScheme.onSecondaryContainer;
                            }

                            return Expanded(
                              flex: isZero ? 2 : 1,
                              child: Padding(
                                padding: EdgeInsets.all(
                                  isLandscape ? 1 : (scientific ? 1 : 2),
                                ),
                                child: SizedBox(
                                  height:
                                      isLandscape
                                          ? 32
                                          : (scientific ? 48 : 56),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: bg,
                                      foregroundColor: fg,
                                      padding: EdgeInsets.zero,
                                      elevation: isEquals ? 2 : 0,
                                      shadowColor:
                                          isEquals
                                              ? theme.colorScheme.primary
                                                  .withValues(alpha: 0.35)
                                              : null,
                                      shape:
                                          isNumber
                                              ? RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                side: BorderSide(
                                                  color:
                                                      theme
                                                          .colorScheme
                                                          .outlineVariant
                                                          .withValues(
                                                            alpha: 0.4,
                                                          ),
                                                  width: 0.8,
                                                ),
                                              )
                                              : RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                      minimumSize: const Size(44, 44),
                                    ),
                                    onPressed:
                                        () => _handlePress(calc, label),
                                    child: Semantics(
                                      label: _semanticLabel(label),
                                      button: true,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            label,
                                            style: TextStyle(
                                              fontSize:
                                                  isLandscape
                                                      ? 14
                                                      : scientific
                                                      ? (isNumber || isZero
                                                          ? 16
                                                          : (isFn ? 12 : 13))
                                                      : (isNumber || isZero
                                                          ? 22
                                                          : (isFn ? 14 : 15)),
                                              fontWeight:
                                                  isOp || isEquals
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  String _semanticLabel(String label) {
    return switch (label) {
      '×' => 'Multiply',
      '÷' => 'Divide',
      '√' => 'Square root',
      'x²' => 'Square',
      '±' => 'Plus minus',
      '⌫' => 'Backspace',
      'C' => 'Clear all',
      'CE' => 'Clear entry',
      'sin' => 'Sine',
      'cos' => 'Cosine',
      'tan' => 'Tangent',
      'log' => 'Logarithm',
      'ln' => 'Natural logarithm',
      'π' => 'Pi',
      '^' => 'Power',
      '%' => 'Percent',
      '(' => 'Open parenthesis',
      ')' => 'Close parenthesis',
      '=' => 'Equals',
      _ => label,
    };
  }

  void _handlePress(CalculatorProvider calc, String label) {
    if (label == 'x²') {
      calc.square();
    } else {
      calc.input(label);
    }
  }
}
