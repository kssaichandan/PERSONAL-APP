import 'dart:math';
import 'package:flutter/material.dart';
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

  String get expression => _expression;
  String get result => _result;
  List<Map<String, String>> get history => _history;
  String? get error => _error;
  double get memory => _memory;

  CalculatorProvider() {
    Future.microtask(() => loadHistory());
  }

  Future<void> loadHistory() async {
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
    notifyListeners();
  }

  void loadExpression(String expr) {
    _expression = expr;
    _result = '';
    notifyListeners();
  }

  void memoryAdd() {
    final parsed = double.tryParse(_result);
    if (parsed != null) _memory += parsed;
    notifyListeners();
  }

  void memorySubtract() {
    final parsed = double.tryParse(_result);
    if (parsed != null) _memory -= parsed;
    notifyListeners();
  }

  void memoryRecall() {
    _expression = _memory.toString();
    _result = '';
    notifyListeners();
  }

  void memoryClear() {
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
    if (_result == 'Error') {
      _expression = '';
      _result = '';
    }
    if (value == 'C') {
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
      if (_expression.length >= 50) return;
      _expression += value;
    }
    notifyListeners();
  }

  void _evaluate() {
    try {
      final parsed = _parse(_expression);
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
    if (_expression.isNotEmpty) {
      _expression = '($_expression)^2';
      notifyListeners();
    }
  }

  // ponytail: recursive descent parser, no external dep
  int _pos = 0;
  String _input = '';

  num _parse(String input) {
    _pos = 0;
    _input = input.replaceAll(' ', '');
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
    if (_pos < _input.length && _input[_pos] == '%') {
      _pos++;
      result /= 100;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Calculator'), centerTitle: true),
      body: Consumer2<CalculatorProvider, SettingsProvider>(
        builder: (context, calc, settings, _) {
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
    return Container(
      padding: EdgeInsets.fromLTRB(20, isSci ? 4 : 8, 20, isSci ? 4 : 12),
      alignment: Alignment.bottomRight,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
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
                  const Chip(
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Text(
                calc.result.isEmpty ? '' : calc.result,
                style: (isSci
                        ? theme.textTheme.headlineMedium
                        : theme.textTheme.headlineLarge)
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
              ),
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
                        vertical: scientific ? 3 : 6,
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
                          onPressed: () {
                            provider.clearHistory();
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (provider.history.isEmpty)
                    const SizedBox(
                      height: 150,
                      child: Center(
                        child: Text(
                          'No history yet',
                          style: TextStyle(color: Colors.grey),
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
                            leading: const Icon(Icons.history_rounded),
                            title: Text(h['expression'] ?? ''),
                            subtitle: Text(
                              h['result'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
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
    final sciRows = [
      ['sin', 'cos', 'tan', '√'],
      ['log', 'ln', '(', ')'],
      ['π', 'e', 'x²', '^'],
    ];
    const basicRows = [
      ['C', '⌫', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '-'],
      ['1', '2', '3', '+'],
      ['±', '0', '.', '='],
    ];

    final allRows = scientific ? [...sciRows, ...basicRows] : basicRows;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children:
            allRows
                .map(
                  (row) => Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: scientific ? 1.5 : 3,
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
                            final isClear = label == 'C' || label == '⌫';
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
                                padding: EdgeInsets.all(scientific ? 1 : 2),
                                child: SizedBox(
                                  height: scientific ? 38 : 48,
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
                                    ),
                                    onPressed: () => _handlePress(calc, label),
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
                                                scientific
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
                            );
                          }).toList(),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  void _handlePress(CalculatorProvider calc, String label) {
    if (label == 'x²') {
      calc.square();
    } else {
      calc.input(label);
    }
  }
}
