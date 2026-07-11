import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../database.dart';
import '../utils/snackbar_utils.dart';

class CalculatorProvider extends ChangeNotifier {
  String _expression = '';
  String _result = '';
  double _memory = 0.0;
  List<Map<String, String>> _history = [];
  String? _error;
  bool _scientificMode = false;

  String get expression => _expression;
  String get result => _result;
  double get memory => _memory;
  List<Map<String, String>> get history => _history;
  String? get error => _error;
  bool get scientificMode => _scientificMode;

  CalculatorProvider() { 
    loadHistory();
    _loadScientificMode();
  }

  Future<void> _loadScientificMode() async {
    try {
      final db = await AppDatabase.instance.database;
      final maps = await db.query('settings', where: 'key = ?', whereArgs: ['calculator_scientific_mode']);
      if (maps.isNotEmpty) {
        _scientificMode = maps.first['value'] == 'true';
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> toggleScientificMode([BuildContext? context]) async {
    _scientificMode = !_scientificMode;
    try {
      final db = await AppDatabase.instance.database;
      final maps = await db.query('settings', where: 'key = ?', whereArgs: ['calculator_scientific_mode']);
      if (maps.isEmpty) {
        await db.insert('settings', {'key': 'calculator_scientific_mode', 'value': _scientificMode.toString()});
      } else {
        await db.update('settings', {'value': _scientificMode.toString()}, where: 'key = ?', whereArgs: ['calculator_scientific_mode']);
      }
    } catch (_) {}
    notifyListeners();
    if (context != null && context.mounted) {
      showSuccessSnackBar(context, _scientificMode ? 'Scientific mode enabled' : 'Scientific mode disabled');
    }
  }

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

  Future<void> clearHistory([BuildContext? context]) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('calculator_history');
      if (context != null && context.mounted) {
        showSuccessSnackBar(context, 'History cleared');
      }
    } catch (e) {
      debugLog('Failed to clear history: $e');
      if (context != null && context.mounted) {
        showErrorSnackBar(context, 'Failed to clear history');
      }
    }
    await loadHistory();
  }

  Future<void> deleteHistoryEntry(int id, [BuildContext? context]) async {
    try {
      final db = await AppDatabase.instance.database;
      await db.delete('calculator_history', where: 'id = ?', whereArgs: [id]);
      if (context != null && context.mounted) {
        showSuccessSnackBar(context, 'Entry deleted');
      }
    } catch (e) {
      debugLog('Failed to delete history entry: $e');
      if (context != null && context.mounted) {
        showErrorSnackBar(context, 'Failed to delete entry');
      }
    }
    await loadHistory();
  }

  void memoryClear() { _memory = 0.0; notifyListeners(); }

  void memoryRecall() {
    _expression += _formatResult(_memory);
    notifyListeners();
  }

  void memoryAdd() {
    _evaluateSilent();
    if (_result != 'Error' && _result.isNotEmpty) _memory += double.tryParse(_result) ?? 0.0;
    notifyListeners();
  }

  void memorySubtract() {
    _evaluateSilent();
    if (_result != 'Error' && _result.isNotEmpty) _memory -= double.tryParse(_result) ?? 0.0;
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
    } catch (_) {
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
    } catch (_) {}
    await loadHistory();
  }

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
    if (_pos < _input.length && _input[_pos] == '%') {
      _pos++;
      result = result % _factor();
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
      while (_pos < _input.length && RegExp(r'[0-9.]').hasMatch(_input[_pos])) { _pos++; }
      if (_pos == start) throw FormatException('Unexpected: ${_input[_pos]}');
      result = double.parse(_input.substring(start, _pos));
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
        title: Text('Calculator', style: theme.textTheme.titleLarge),
        actions: [
          if (calc.expression.isNotEmpty || calc.result.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.content_copy_rounded),
              tooltip: 'Copy result',
              onPressed: () {
                final text = calc.result.isNotEmpty ? calc.result : calc.expression;
                _copyToClipboard(context, text, 'Copied to clipboard');
              },
            ),
          IconButton(
            icon: Icon(calc.scientificMode ? Icons.functions_rounded : Icons.functions_outlined),
            tooltip: calc.scientificMode ? 'Disable scientific mode' : 'Enable scientific mode',
            onPressed: () => calc.toggleScientificMode(context),
          ),
          if (calc.history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Show history',
              onPressed: () => _showHistoryDrawer(context, calc),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onLongPress: () => _copyToClipboard(context, calc.expression.isEmpty ? '0' : calc.expression, 'Expression copied'),
                      child: Tooltip(
                        message: calc.expression.isEmpty ? '0' : calc.expression,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Text(
                            calc.expression.isEmpty ? '0' : calc.expression,
                            style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onLongPress: () => _copyToClipboard(context, calc.result.isEmpty ? '0' : calc.result, 'Result copied'),
                      child: Tooltip(
                        message: calc.result.isEmpty ? '0' : calc.result,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Text(
                            calc.result.isEmpty ? '0' : calc.result,
                            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(8),
              child: _ResponsiveButtonGrid(calc: calc),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryDrawer(BuildContext context, CalculatorProvider calc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Consumer<CalculatorProvider>(
        builder: (context, provider, _) {
          final theme = Theme.of(context);
          return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Calculation History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => provider.clearHistory(context), child: const Text('Clear All')),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.history.length,
                  itemBuilder: (context, index) {
                    final item = provider.history[index];
                    return ListTile(
                      title: Text(item['expression']!, style: theme.textTheme.bodyMedium),
                      subtitle: Text('= ${item['result']!}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Delete entry',
                        onPressed: () => provider.deleteHistoryEntry(int.parse(item['id']!), context),
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
          ));
        },
      ),
    );
  }
}

void _copyToClipboard(BuildContext context, String text, String message) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class _MemoryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MemoryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String semanticLabel;
    switch (label) {
      case 'MC': return 'Memory Clear';
      case 'MR': return 'Memory Recall';
      case 'M+': return 'Memory Add';
      case 'M-': return 'Memory Subtract';
      default: return label;
    }

    return Semantics(
      label: semanticLabel,
      button: true,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(minimumSize: const Size(48, 36), padding: EdgeInsets.zero),
        child: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class _ResponsiveButtonGrid extends StatelessWidget {
  final CalculatorProvider calc;
  const _ResponsiveButtonGrid({required this.calc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isScientific = calc.scientificMode;

    final standardRows = [
      ['C', '⌫', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '-'],
      ['1', '2', '3', '+'],
      ['0', '.', '=', ''],
    ];

    final scientificRows = [
      ['C', '⌫', '%', '÷', '(', ')'],
      ['sin', 'cos', 'tan', '×', '^', '√'],
      ['7', '8', '9', '-', 'π', 'e'],
      ['4', '5', '6', '+', 'log', 'ln'],
      ['1', '2', '3', '=', '(', ')'],
      ['0', '.', '', '', '', ''],
    ];

    final rows = isScientific ? scientificRows : standardRows;
    final crossAxisCount = isScientific ? 6 : 4;

    return Column(
      children: rows.map((row) => Row(
        children: row.map((label) {
          if (label.isEmpty) return Expanded(child: const SizedBox());
          return Expanded(
            child: _CalcButton(
              label: label,
              onTap: () => calc.input(label),
              isOperator: ['÷', '×', '-', '+', '=', '^'].contains(label),
              isAction: ['C', '⌫', '%'].contains(label),
              isScientific: ['sin', 'cos', 'tan', 'log', 'ln', '√', 'π', 'e', '^'].contains(label),
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
  final bool isScientific;
  const _CalcButton({required this.label, required this.onTap, this.isOperator = false, this.isAction = false, this.isScientific = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color getBgColor() {
      if (isOperator) return label == '=' ? theme.colorScheme.primary : theme.colorScheme.primaryContainer;
      if (isAction) return theme.colorScheme.errorContainer.withValues(alpha: 0.4);
      if (isScientific) return theme.colorScheme.secondaryContainer;
      return theme.colorScheme.surfaceContainer;
    }

    Color getTextColor() {
      if (isOperator) return label == '=' ? theme.colorScheme.onPrimary : theme.colorScheme.onPrimaryContainer;
      if (isAction) return theme.colorScheme.onErrorContainer;
      if (isScientific) return theme.colorScheme.onSecondaryContainer;
      return theme.colorScheme.onSurface;
    }

    String getSemanticLabel() {
      switch (label) {
        case 'C': return 'Clear';
        case '⌫': return 'Backspace';
        case '%': return 'Percent';
        case '÷': return 'Divide';
        case '×': return 'Multiply';
        case '-': return 'Subtract';
        case '+': return 'Add';
        case '=': return 'Equals';
        case '^': return 'Power';
        case '√': return 'Square root';
        case 'sqrt': return 'Square root';
        case 'π': return 'Pi';
        case 'e': return 'Euler\'s number';
        case 'sin': return 'Sine';
        case 'cos': return 'Cosine';
        case 'tan': return 'Tangent';
        case 'log': return 'Logarithm base 10';
        case 'ln': return 'Natural logarithm';
        case 'sqrt': return 'Square root';
        default: return label;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: getBgColor(),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Semantics(
            label: getSemanticLabel(),
            button: true,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              child: Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: getTextColor())),
            ),
          ),
        ),
      ),
    );
  }
}
