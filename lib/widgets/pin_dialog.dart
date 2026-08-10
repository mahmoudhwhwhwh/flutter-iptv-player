import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/iptv_provider.dart';

Future<bool> showPinDialog(
  BuildContext context,
  IPTVProvider provider, {
  String? customTitle,
  String? customDesc,
  bool isCreating = false,
}) async {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  String? errorText;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      // Auto-focus after a split second
      WidgetsBinding.instance.addPostFrameCallback((_) {
        focusNode.requestFocus();
      });

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF16161A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12, width: 1),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  customTitle ?? (isCreating ? "تعيين رمز الأمان الجديد" : "تأكيد رمز الأمان (PIN)"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.lock_rounded, color: Color(0xFFE50914)),
              ],
            ),
            content: Container(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    customDesc ??
                        (isCreating
                            ? "يرجى تعيين رمز أمان مكون من 4 أرقام لحماية الأقسام الخاصة بك."
                            : "هذا القسم مقفل. يرجى إدخال رمز الأمان المكون من 4 أرقام للمتابعة."),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      counterText: "",
                      hintText: "••••",
                      hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8, fontSize: 24),
                      errorText: errorText,
                      errorStyle: const TextStyle(fontFamily: 'Cairo', color: Colors.redAccent),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white24, width: 1),
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onSubmitted: (val) {
                      if (val.length < 4) {
                        setDialogState(() {
                          errorText = "يجب إدخال 4 أرقام!";
                        });
                        return;
                      }
                      if (isCreating) {
                        Navigator.pop(dialogContext, true);
                      } else {
                        if (val == provider.parentalPin) {
                          Navigator.pop(dialogContext, true);
                        } else {
                          setDialogState(() {
                            errorText = "رمز الأمان خاطئ، يرجى المحاولة مجدداً";
                            controller.clear();
                            focusNode.requestFocus();
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(
                  "إلغاء",
                  style: TextStyle(
                    color: Colors.white54,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                onPressed: () {
                  final val = controller.text;
                  if (val.length < 4) {
                    setDialogState(() {
                      errorText = "يجب إدخال 4 أرقام!";
                    });
                    return;
                  }
                  if (isCreating) {
                    Navigator.pop(dialogContext, true);
                  } else {
                    if (val == provider.parentalPin) {
                      Navigator.pop(dialogContext, true);
                    } else {
                      setDialogState(() {
                        errorText = "رمز الأمان خاطئ، يرجى المحاولة مجدداً";
                        controller.clear();
                        focusNode.requestFocus();
                      });
                    }
                  }
                },
                child: const Text(
                  "تأكيد",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  if (result == true && isCreating) {
    // If we were creating and clicked confirm, the PIN is the controller's text
    provider.setParentalPin(controller.text);
    return true;
  }

  return result ?? false;
}
