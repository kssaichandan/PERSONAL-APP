import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database.dart';
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

  CalculatorProvider() { loadHistory(); }

  Future<void> loadHistory() async {
    try {
      final db = await AppDatabase.instance.database;
      final maps = await db.query('calculator_history', orderBy: 'created_at DESC', limit: 50);
      _history = maps.map((m) => {'expression': m['expression'] as String, 'result': m['result'] as String}).toList();
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
    } catch (_) {}
    await loadHistory();
  }

  void input(String value) {
    if (value == 'C') {
      _expression = '';
      _result = '';
    } else if (value == '⌫') {
      if (_expression.isNotEmpty) _expression = _expression.substring(0, _expression.length - 1);
    } else if (value == '=') {
      _evaluate();
      return;
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
    return value.toStringAsFixed(10).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  Future<void> _saveToHistory(String expr, String res) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.insert('calculator_history', {
        'expression': expr, 'result': res,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
    await loadHistory();
  }

  // ponytail: recursive descent parser, no external dep
  int _pos = 0;
  String _input = '';

  num _parse(String input) {
    _pos = 0;
    _input = input.replaceAll(' ', '');
    final result = _expr();
    if (_pos < _input.length) throw FormatException('Unexpected: ${_input[_pos]}');
    return result;
  }

  num _expr() {
    num result = _term();
    while (_pos < _input.length && (_input[_pos] == '+' || _input[_pos] == '-')) {
      final op = _input[_pos++];
      final right = _term();
      result = op == '+' ? result + right : result - right;
    }
    return result;
  }

  num _term() {
    num result = _factor();
    while (_pos < _input.length && (_input[_pos] == '×' || _input[_pos] == '÷')) {
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
    return result;
  }

  num _unary() {
    if (_pos >= _input.length) throw FormatException('Unexpected end');
    if (_input[_pos] == '-') { _pos++; return -_unary(); }
    if (_input[_pos] == '+') { _pos++; return _unary(); }
    return _primary();
  }

  num _primary() {
    if (_pos >= _input.length) throw FormatException('Unexpected end');

    if (_input[_pos] == '(') {
      _pos++;
      final result = _expr();
      if (_pos >= _input.length || _input[_pos] != ')') throw FormatException('Missing )');
      _pos++;
      return result;
    }

    if (_input.substring(_pos).startsWith('sin(')) { _pos += 3; return sin(_primary().toDouble()); }
    if (_input.substring(_pos).startsWith('cos(')) { _pos += 3; return cos(_primary().toDouble()); }
    if (_input.substring(_pos).startsWith('tan(')) { _pos += 3; return tan(_primary().toDouble()); }
    if (_input.substring(_pos).startsWith('log(')) { _pos += 3; return log(_primary().toDouble()) / ln10; }
    if (_input.substring(_pos).startsWith('ln(')) { _pos += 2; return log(_primary().toDouble()); }
    if (_input.substring(_pos).startsWith('sqrt(')) { _pos += 4; return sqrt(_primary().toDouble()); }

    if (_input.substring(_pos).startsWith('π')) { _pos++; return pi; }
    if (_input.substring(_pos).startsWith('e') && (_pos + 1 >= _input.length || !RegExp(r'[a-zA-Z0-9]').hasMatch(_input[_pos + 1]))) { _pos++; return e; }

    final start = _pos;
    while (_pos < _input.length && (RegExp(r'[0-9.]').hasMatch(_input[_pos]))) { _pos++; }
    if (_pos == start) throw FormatException('Unexpected: ${_input[_pos]}');
    var result = double.parse(_input.substring(start, _pos));
    if (_pos < _input.length && _input[_pos] == '%') { _pos++; result /= 100; }
    return result;
  }
}

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Calculator')),
      body: Consumer2<CalculatorProvider, SettingsProvider>(
        builder: (context, calc, settings, _) {
          return Column(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.bottomRight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(calc.expression, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Text(calc.result, style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              if (calc.history.isNotEmpty)
                SizedBox(
                  height: 80,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: calc.history.take(10).map((h) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h['expression']!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            Text(h['result']!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              _MemoryButtonRow(calc: calc, theme: theme),
              _ButtonGrid(calc: calc, scientific: settings.scientificMode, theme: theme),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

class _MemoryButtonRow extends StatelessWidget {
  final CalculatorProvider calc;
  final ThemeData theme;
  const _MemoryButtonRow({required this.calc, required this.theme});

  @override
  Widget build(BuildContext context) {
    final hasMemory = calc.memory != 0.0;
    final memButtons = ['MC', 'MR', 'M+', 'M-'];
    return Row(
      children: [
        if (hasMemory)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('M', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
            ),
          ),
        ...memButtons.map((label) {
          final isDisabled = (label == 'MC' || label == 'MR') && !hasMemory;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  foregroundColor: isDisabled ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: isDisabled ? null : () {
                  switch (label) {
                    case 'MC': calc.memoryClear();
                    case 'MR': calc.memoryRecall();
                    case 'M+': calc.memoryAdd();
                    case 'M-': calc.memorySubtract();
                  }
                },
                child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ButtonGrid extends StatelessWidget {
  final CalculatorProvider calc;
  final bool scientific;
  final ThemeData theme;
  const _ButtonGrid({required this.calc, required this.scientific, required this.theme});

  @override
  Widget build(BuildContext context) {
    const sciRows = [
      ['sin(', 'cos(', 'tan(', 'log(', 'C'],
      ['√(', 'ln(', 'π', 'e', '⌫'],
    ];
    const basicRows = [
      ['7', '8', '9', '÷', '^'],
      ['4', '5', '6', '×', '('],
      ['1', '2', '3', '-', ')'],
      ['0', '.', '=', '+', '%'],
    ];

    final allRows = scientific ? [...sciRows, ...basicRows] : basicRows;
    final opLabels = ['+', '-', '×', '÷', '=', '^', 'C', '⌫'];
    final fnLabels = ['sin(', 'cos(', 'tan(', 'log(', '√(', 'ln(', 'π', 'e', '(', ')', '%'];

    return Column(
      children: allRows.map((row) => Row(
        children: row.map((label) {
          final isOp = opLabels.contains(label);
          final isFn = fnLabels.contains(label);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: isOp ? theme.colorScheme.primaryContainer : (isFn ? theme.colorScheme.surfaceContainerHighest : null),
                ),
                onPressed: () => calc.input(label),
                child: Text(label, style: TextStyle(fontSize: isOp || isFn ? 14 : 18)),
              ),
            ),
          );
        }).toList(),
      )).toList(),
    );
  }
}
