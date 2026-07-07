import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database.dart';

class CalculatorProvider extends ChangeNotifier {
  String _expression = '';
  String _result = '';
  List<Map<String, String>> _history = [];
  String? _error;

  String get expression => _expression;
  String get result => _result;
  List<Map<String, String>> get history => _history;
  String? get error => _error;

  CalculatorProvider() { loadHistory(); }

  Future<void> loadHistory() async {
    try {
      final db = await AppDatabase.instance.database;
      final maps = await db.query('calculator_history', orderBy: 'created_at DESC', limit: 50);
      _history = maps.map((m) => {
        'id': m['id'].toString(), 'expression': m['expression'] as String, 'result': m['result'] as String,
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
    } catch (_) {}
    await loadHistory();
  }

  Future<void> deleteHistoryEntry(int id) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('calculator_history', where: 'id = ?', whereArgs: [id]);
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
    if (_pos >= _input.length) throw const FormatException('Unexpected end');
    if (_input[_pos] == '-') { _pos++; return -_unary(); }
    if (_input[_pos] == '+') { _pos++; return _unary(); }
    return _primary();
  }

  num _primary() {
    if (_pos >= _input.length) throw const FormatException('Unexpected end');

    if (_input[_pos] == '(') {
      _pos++;
      final result = _expr();
      if (_pos >= _input.length || _input[_pos] != ')') throw const FormatException('Missing )');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Calculator'), actions: [
        if (calc.history.isNotEmpty)
          IconButton(icon: const Icon(Icons.delete_sweep), onPressed: calc.clearHistory),
      ]),
      body: Consumer<CalculatorProvider>(
        builder: (context, calc, _) {
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
                      Text(calc.expression, style: const TextStyle(fontSize: 24, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(calc.result, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              if (calc.history.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: calc.history.take(10).map((h) => ListTile(
                      dense: true,
                      title: Text(h['expression']!, style: const TextStyle(fontSize: 12), maxLines: 1),
                      subtitle: Text('= ${h['result']}', style: const TextStyle(fontSize: 13)),
                      trailing: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => calc.deleteHistoryEntry(int.parse(h['id']!))),
                    )).toList(),
                  ),
                ),
              _ButtonGrid(calc: calc),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

class _ButtonGrid extends StatelessWidget {
  final CalculatorProvider calc;
  const _ButtonGrid({required this.calc});

  @override
  Widget build(BuildContext context) {
    final buttons = [
      ['sin(', 'cos(', 'tan(', 'log(', 'C'],
      ['√(', 'ln(', 'π', 'e', '⌫'],
      ['7', '8', '9', '÷', '^'],
      ['4', '5', '6', '×', '('],
      ['1', '2', '3', '-', ')'],
      ['0', '.', '=', '+', '%'],
    ];

    return Column(
      children: buttons.map((row) => Row(
        children: row.map((label) {
          final isOp = ['+', '-', '×', '÷', '=', '^', 'C', '⌫'].contains(label);
          final isFn = ['sin(', 'cos(', 'tan(', 'log(', '√(', 'ln(', 'π', 'e', '(', ')', '%'].contains(label);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  backgroundColor: isOp ? Theme.of(context).colorScheme.primaryContainer : (isFn ? Colors.grey.shade200 : null),
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
