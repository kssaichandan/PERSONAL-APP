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
    final parsed = double.tryParse(_result);
    if (parsed != null) _memory += parsed;
    notifyListeners();
  }

  void memorySubtract() {
    HapticFeedback.lightImpact();
    final parsed = double.tryParse(_result);
    if (parsed != null) _memory -= parsed;
    notifyListeners();
  }

  void memoryRecall() {
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
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

  void input(String value) {
    HapticFeedback.lightImpact();
    if (_result == 'Error') {
      _expression = '';
      _result = '';
    }
    if (value == 'C') {
      _expression = '';
      _result = '';
    } else if (value == 'CE') {
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
    if (_expression.isNotEmpty) {
      _expression = '($_expression)^2';
      notifyListeners();
    }
  }

  int _pos = 0;
  String _input = '';

  String _preprocess(String input) {
    var s = input.replaceAll(' ', '');
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
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(title: const Text('Calculator'), centerTitle: true),
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
    final hasError = calc.result == 'Error' || calc.result == 'Cannot divide by zero';
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    return Container(
      padding: EdgeInsets.fromLTRB(
        isLandscape ? 12 : 20,
        isSci ? 4 : 8,
        isLandscape ? 12 : 20,
        isSci ? 4 : 12,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'M',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                const Spacer(),
                if (isSci)
                  Chip(
                    avatar: Icon(Icons.science_outlined, size: 14),
                    label: Text('SCI', style: TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    labelPadding: EdgeInsets.only(right: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            SizedBox(height: isSci ? 4 : 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Text(
                calc.expression.isEmpty ? '0' : calc.expression,
                style: (isSci
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                maxLines: 1,
              ),
            ),
            SizedBox(height: isSci ? 2 : 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                  ),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: GestureDetector(
                      onTap: settings.copyOnTap && calc.result.isNotEmpty && !hasError
                          ? () {
                              Clipboard.setData(ClipboardData(text: calc.result));
                              showSuccessSnackBar(context, 'Result copied');
                            }
                          : null,
                      child: Text(
                        calc.result.isEmpty ? '' : calc.result,
                        style: (isSci
                                ? theme.textTheme.headlineMedium
                                : theme.textTheme.headlineLarge)
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  hasError ? theme.colorScheme.error : null,
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
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children:
            memButtons.map((label) {
              final disabled = (label == 'MC' || label == 'MR') && !hasMemory;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.all(scientific ? 1 : 2),
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
                              : theme.colorScheme.onSurfaceVariant,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(44, 44),
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
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isSci ? 2 : 4),
      child: Row(
        children: [
          TextButton.icon(
            icon: Icon(
              isSci ? Icons.science : Icons.science_outlined,
              size: 16,
            ),
            label: Text(
              isSci ? 'Scientific ON' : 'Scientific OFF',
              style: const TextStyle(fontSize: 11),
            ),
            onPressed:
                () => settings.setScientificMode(!settings.scientificMode),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              backgroundColor:
                  isSci ? Theme.of(context).colorScheme.primaryContainer : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size(44, 36),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text('History', style: TextStyle(fontSize: 11)),
            onPressed: () => _showHistoryBottomSheet(context, calc),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: const Size(44, 36),
            ),
          ),
        ],
      ),
    );
  }
}

void _showHistoryBottomSheet(BuildContext context, CalculatorProvider calc) {
  final theme = Theme.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Consumer<CalculatorProvider>(
        builder: (context, provider, _) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Calculation History',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                          onPressed: () => _confirmClearHistory(context, provider),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (provider.history.isEmpty)
                    SizedBox(
                      height: 180,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calculate_outlined,
                              size: 48,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No calculations yet',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your calculation history will appear here',
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
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: provider.history.length,
                        itemBuilder: (context, index) {
                          final h = provider.history[index];
                          return ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.functions,
                                size: 18,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            title: Text(
                              h['expression'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '= ${h['result'] ?? ''}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.keyboard_arrow_right),
                            onTap: () {
                              provider.loadExpression(h['expression'] ?? '');
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
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
          title: const Text('Clear History'),
          content: const Text(
            'Are you sure you want to clear all calculation history? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                provider.clearHistory();
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Clear'),
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
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
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
                            } else if (isOp) {
                              bg = theme.colorScheme.primaryContainer;
                              fg = theme.colorScheme.onPrimaryContainer;
                            } else if (isEquals) {
                              bg = theme.colorScheme.primary;
                              fg = theme.colorScheme.onPrimary;
                            } else if (isClear) {
                              bg = theme.colorScheme.errorContainer;
                              fg = theme.colorScheme.onErrorContainer;
                            } else if (isFn) {
                              bg = theme.colorScheme.secondaryContainer;
                              fg = theme.colorScheme.onSecondaryContainer;
                            }

                            return Expanded(
                              flex: isZero ? 2 : 1,
                              child: Padding(
                                padding: EdgeInsets.all(isLandscape ? 1 : (scientific ? 1 : 2)),
                                child: SizedBox(
                                  height: isLandscape ? 32 : (scientific ? 48 : 56),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: bg,
                                      foregroundColor: fg,
                                      padding: EdgeInsets.zero,
                                      shape:
                                          isNumber
                                              ? RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                side: BorderSide(
                                                  color:
                                                      theme
                                                          .colorScheme
                                                          .outlineVariant,
                                                  width: 0.5,
                                                ),
                                              )
                                              : RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                      elevation: 0,
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
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
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
    HapticFeedback.lightImpact();
    if (label == 'x²') {
      calc.square();
    } else {
      calc.input(label);
    }
  }
}
