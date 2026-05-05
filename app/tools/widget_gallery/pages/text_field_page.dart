import 'package:flutter/widgets.dart';
import 'package:termex/design/tokens.dart';
import 'package:termex/widgets/text_field.dart';
import 'package:termex/widgets/form_validators.dart';

class TextFieldPage extends StatefulWidget {
  const TextFieldPage({super.key});

  @override
  State<TextFieldPage> createState() => _TextFieldPageState();
}

class _TextFieldPageState extends State<TextFieldPage> {
  final _defaultController = TextEditingController();
  final _labelController = TextEditingController();
  final _validatorController = TextEditingController();

  @override
  void dispose() {
    _defaultController.dispose();
    _labelController.dispose();
    _validatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TextField',
            style: TermexTypography.heading3.copyWith(
              color: TermexColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Default',
            child: SizedBox(
              width: 320,
              child: TermexTextField(
                controller: _defaultController,
                placeholder: 'Enter text...',
              ),
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'With Label',
            child: SizedBox(
              width: 320,
              child: TermexTextField(
                controller: _labelController,
                label: 'Username',
                placeholder: 'Enter your username',
              ),
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Error State',
            child: SizedBox(
              width: 320,
              child: TermexTextField(
                label: 'Email',
                placeholder: 'Enter email',
                errorText: 'Invalid email address',
              ),
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'Disabled',
            child: SizedBox(
              width: 320,
              child: TermexTextField(
                label: 'Disabled field',
                placeholder: 'Cannot edit this',
                disabled: true,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _Section(
            title: 'With Validator (Required)',
            child: SizedBox(
              width: 320,
              child: TermexTextField(
                controller: _validatorController,
                label: 'Required field',
                placeholder: 'This field is required',
                validators: [Validators.required()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TermexTypography.heading4.copyWith(
            color: TermexColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
