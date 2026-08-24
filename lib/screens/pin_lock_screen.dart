import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../services/prefs_service.dart';
import '../theme/app_theme.dart';

/// mode == null  → разблокировка (проверка текущего пин-кода)
/// mode == 'set' → установка нового пин-кода (два шага внутри одного экрана)
/// onUnlocked    → если задан, вызывается вместо Navigator.pop (режим оверлея)
class PinLockScreen extends StatefulWidget {
  final String? mode;
  final VoidCallback? onUnlocked;

  const PinLockScreen({super.key, this.mode, this.onUnlocked});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  String _input = '';
  String? _firstPin;   // для режима 'set': сюда кладём первый введённый пин
  String? _error;

  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;
  final _auth = LocalAuthentication();

  bool get _isUnlock => widget.mode == null;
  bool get _isSetup  => widget.mode == 'set';
  bool get _isConfirmStep => _isSetup && _firstPin != null;

  String get _title {
    if (_isUnlock)       return 'Введите пин-код';
    if (_isConfirmStep)  return 'Повторите пин-код';
    return 'Создайте пин-код';
  }

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut),
    );
    if (_isUnlock) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final prefs = context.read<PrefsService>();
    if (!prefs.biometricEnabled) return;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Войдите в EOS',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (ok && mounted) {
        if (widget.onUnlocked != null) {
          widget.onUnlocked!();
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (_) {}
  }

  void _onKey(String key) {
    if (_input.length >= 4) return;
    setState(() {
      _input += key;
      _error = null;
    });
    if (_input.length == 4) {
      // небольшая задержка чтобы пользователь увидел 4-ю точку
      Future.delayed(const Duration(milliseconds: 120), _onComplete);
    }
  }

  void _onDelete() {
    if (_input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _error = null;
    });
  }

  void _onComplete() {
    if (!mounted) return;

    if (_isUnlock) {
      final prefs = context.read<PrefsService>();
      if (_input == prefs.pinCode) {
        if (widget.onUnlocked != null) {
          widget.onUnlocked!();
        } else {
          Navigator.of(context).pop(true);
        }
      } else {
        _shake('Неверный пин-код');
      }
      return;
    }

    // Режим установки
    if (_firstPin == null) {
      // Шаг 1: запоминаем первый пин, переходим к подтверждению
      setState(() {
        _firstPin = _input;
        _input = '';
      });
    } else {
      // Шаг 2: проверяем совпадение
      if (_input == _firstPin) {
        Navigator.of(context).pop(_input);
      } else {
        setState(() => _firstPin = null);
        _shake('Пин-коды не совпадают, начните заново');
      }
    }
  }

  void _shake(String message) {
    setState(() {
      _input = '';
      _error = message;
    });
    _shakeCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppThemeNotifier>();
    final t = notifier.current;
    final a = notifier.accent;
    final prefs = context.read<PrefsService>();

    return PopScope(
      canPop: !_isUnlock,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),
              Icon(Icons.lock_outline_rounded, size: 48, color: a),
              const SizedBox(height: 16),
              Text('EOS',
                style: TextStyle(
                  color: t.textPrimary, fontSize: 22,
                  fontWeight: FontWeight.bold, letterSpacing: 2,
                )),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(_title,
                  key: ValueKey(_title),
                  style: TextStyle(color: t.textSecondary, fontSize: 15)),
              ),
              const SizedBox(height: 40),

              // Четыре точки
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) {
                  final dx = _shakeCtrl.isAnimating
                      ? 10 * (1 - _shakeAnim.value) * (_shakeAnim.value * 10 % 2 < 1 ? 1 : -1)
                      : 0.0;
                  return Transform.translate(offset: Offset(dx, 0), child: child);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _input.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? a : Colors.transparent,
                        border: Border.all(
                          color: filled ? a : t.textSecondary.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 16),
              AnimatedOpacity(
                opacity: _error != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _error ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ),

              const Spacer(),

              // Цифровая клавиатура
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    for (final row in [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                    ])
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((d) => _KeyButton(
                          label: d, onTap: () => _onKey(d), accent: a, t: t,
                        )).toList(),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (_isUnlock && prefs.biometricEnabled)
                          _KeyButton(icon: Icons.fingerprint, onTap: _tryBiometric, accent: a, t: t)
                        else
                          const SizedBox(width: 72, height: 72),
                        _KeyButton(label: '0', onTap: () => _onKey('0'), accent: a, t: t),
                        _KeyButton(icon: Icons.backspace_outlined, onTap: _onDelete, accent: a, t: t),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (!_isUnlock)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text('Отмена', style: TextStyle(color: t.textSecondary)),
                )
              else
                const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color accent;
  final ThemeDef t;

  const _KeyButton({
    this.label, this.icon,
    required this.onTap, required this.accent, required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72, height: 72,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.surface.withValues(alpha: 0.6),
        ),
        child: Center(
          child: label != null
              ? Text(label!,
                  style: TextStyle(
                    color: t.textPrimary, fontSize: 24, fontWeight: FontWeight.w400))
              : Icon(icon, color: accent, size: 26),
        ),
      ),
    );
  }
}
