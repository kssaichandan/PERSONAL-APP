import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database.dart';

class CalculatorProvider extends ChangeNotifier {
  String _expression = '';
  String _result = '';
  double _memory = 0.0;
  List<Map<String, String>> _history = [];
  String? _error;

  String get expression => _expression;
  String get result => _result;
  double get memory => _memory;
  List<Map<String, String>> get history => _history;
  String? get error => _error;

  CalculatorProvider() { loadHistory(); }

  Future<void> loadHistory() async {
    try {
      final db = await AppDatabase.instance.database;
      final maps = await db.query('calculator_history', orderBy: 'created_at DESC', limit: 50);
      _history = maps.map((m) => {
        'id': m['id'].toString(),
        'expression': m['expression'] as String,
        'result': m['result'] as String,
      }).toList();
    } catch (e) {
      _error = 'Failed to load history';
    }
    notifyListeners();
  }

  Future<void> clearHistory() async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('calculator_history');
    } catch (e) {
      debugPrint('clearHistory failed: $e');
    }
    await loadHistory();
  }

  Future<void> deleteHistoryEntry(int id) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('calculator_history', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('deleteHistoryEntry failed: $e');
    }
    await loadHistory();
  }

  void memoryClear() {
    _memory = 0.0;
    notifyListeners();
  }

  void memoryRecall() {
    _expression += _formatResult(_memory);
    notifyListeners();
  }

  void memoryAdd() {
    _evaluateSilent();
    if (_result != 'Error' && _result.isNotEmpty) {
      _memory += double.tryParse(_result) ?? 0.0;
    }
    notifyListeners();
  }

  void memorySubtract() {
    _evaluateSilent();
    if (_result != 'Error' && _result.isNotEmpty) {
      _memory -= double.tryParse(_result) ?? 0.0;
    }
    notifyListeners();
  }

  void input(String value) {
    if (_result == 'Error' && value != 'C' && value != '⌫') {
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
    } else {
      if (_expression.length >= 50) return;
      _expression += value;
    }
    notifyListeners();
  }

  void loadExpression(String expr) {
    _expression = expr;
    _result = '';
    notifyListeners();
  }

  void _evaluateSilent() {
    try {
      final parsed = _parse(_expression);
      _result = _formatResult(parsed);
    } catch (_) {
      _result = 'Error';
    }
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
    return value.toStringAsFixed(8).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
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
      debugPrint('saveToHistory failed: $e');
    }
    await loadHistory();
  }

  // upgraded ponytail recursive descent parser supporting generalized % operator
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
    if (_pos >= _input.length) throw const FormatException('Unexpected end');
    if (_input[_pos] == '-') { _pos++; return -_unary(); }
    if (_input[_pos] == '+') { _pos++; return _unary(); }
    return _primary();
  }

  num _primary() {
    num result;
    if (_pos >= _input.length) throw const FormatException('Unexpected end');

    if (_input[_pos] == '(') {
      _pos++;
      result = _expr();
      if (_pos >= _input.length || _input[_pos] != ')') throw const FormatException('Missing )');
      _pos++;
    } else if (_input.substring(_pos).startsWith('sin(')) {
      _pos += 4;
      result = sin(_expr().toDouble());
      if (_pos < _input.length && _input[_pos] == ')') _pos++;
    } else if (_input.substring(_pos).startsWith('cos(')) {
      _pos += 4;
      result = cos(_expr().toDouble());
      if (_pos < _input.length && _input[_pos] == ')') _pos++;
    } else if (_input.substring(_pos).startsWith('tan(')) {
      _pos += 4;
      result = tan(_expr().toDouble());
      if (_pos < _input.length && _input[_pos] == ')') _pos++;
    } else if (_input.substring(_pos).startsWith('log(')) {
      _pos += 4;
      result = log(_expr().toDouble()) / ln10;
      if (_pos < _input.length && _input[_pos] == ')') _pos++;
    } else if (_input.substring(_pos).startsWith('ln(')) {
      _pos += 3;
      result = log(_expr().toDouble());
      if (_pos < _input.length && _input[_pos] == ')') _pos++;
    } else if (_input.substring(_pos).startsWith('sqrt(')) {
      _pos += 5;
      result = sqrt(_expr().toDouble());
      if (_pos < _input.length && _input[_pos] == ')') _pos++;
    } else if (_input.substring(_pos).startsWith('π')) {
      _pos++;
      result = pi;
    } else if (_input.substring(_pos).startsWith('e') && (_pos + 1 >= _input.length || !RegExp(r'[a-zA-Z0-9]').hasMatch(_input[_pos + 1]))) {
      _pos++;
      result = e;
    } else {
      final start = _pos;
      while (_pos < _input.length && (RegExp(r'[0-9.]').hasMatch(_input[_pos]))) { _pos++; }
      if (_pos == start) throw FormatException('Unexpected: ${_input[_pos]}');
      result = double.parse(_input.substring(start, _pos));
    }

    // Generalized % postfix operator support (e.g. (2+3)% -> 0.05)
    while (_pos < _input.length && _input[_pos] == '%') {
      _pos++;
      result /= 100;
    }

    return result;
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calc = context.watch<CalculatorProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (calc.history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: () => _showHistoryDrawer(context, calc),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Displays Area
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        calc.expression.isEmpty ? '0' : calc.expression,
                        style: const TextStyle(fontSize: 28, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        calc.result.isEmpty ? '0' : calc.result,
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Memory Buttons Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MemoryButton(label: 'MC', onTap: calc.memoryClear),
                  _MemoryButton(label: 'MR', onTap: calc.memoryRecall),
                  _MemoryButton(label: 'M+', onTap: calc.memoryAdd),
                  _MemoryButton(label: 'M-', onTap: calc.memorySubtract),
                  if (calc.memory != 0.0)
                    Text(
                      'M = ${calc.memory.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Button Grids
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(8),
              child: _buildButtons(calc),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons(CalculatorProvider calc) {
    return _StandardButtonGrid(calc: calc);
  }

  void _showHistoryDrawer(BuildContext context, CalculatorProvider calc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer<CalculatorProvider>(
        builder: (context, provider, _) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Calculation History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: provider.clearHistory, child: const Text('Clear All')),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.history.length,
                  itemBuilder: (context, index) {
                    final item = provider.history[index];
                    return ListTile(
                      title: Text(item['expression']!, style: const TextStyle(fontSize: 14)),
                      subtitle: Text('= ${item['result']!}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => provider.deleteHistoryEntry(int.parse(item['id']!)),
                      ),
                      onTap: () {
                        provider.loadExpression(item['expression']!);
                        Navigator.pop(ctx);
                      },
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

class _MemoryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MemoryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(minimumSize: const Size(48, 36), padding: EdgeInsets.zero),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }
}

class _StandardButtonGrid extends StatelessWidget {
  final CalculatorProvider calc;
  const _StandardButtonGrid({required this.calc});

  @override
  Widget build(BuildContext context) {
    final buttons = [
      ['C', '⌫', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '-'],
      ['1', '2', '3', '+'],
      ['0', '.', '=', ''],
    ];

    return Column(
      children: buttons.map((row) => Row(
        children: row.map((label) {
          if (label.isEmpty) return const Expanded(child: SizedBox());
          return Expanded(
            child: _CalcButton(
              label: label,
              onTap: () => calc.input(label),
              isOperator: ['÷', '×', '-', '+', '='].contains(label),
              isAction: ['C', '⌫', '%'].contains(label),
            ),
          );
        }).toList(),
      )).toList(),
    );
  }
}

class _CalcButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isOperator;
  final bool isAction;

  const _CalcButton({
    required this.label,
    required this.onTap,
    this.isOperator = false,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color getBgColor() {
      if (isOperator) {
        return label == '=' ? theme.colorScheme.primary : theme.colorScheme.primaryContainer;
      }
      if (isAction) {
        return theme.colorScheme.errorContainer.withValues(alpha: 0.4);
      }
      return theme.colorScheme.surfaceContainer;
    }

    Color getTextColor() {
      if (isOperator) {
        return label == '=' ? theme.colorScheme.onPrimary : theme.colorScheme.onPrimaryContainer;
      }
      if (isAction) {
        return theme.colorScheme.onErrorContainer;
      }
      return theme.colorScheme.onSurface;
    }

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Material(
        color: getBgColor(),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: getTextColor(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
